#!/usr/bin/env bash
# 用 LKMM 判内存序结论：herd7 给模型判定。
#
#   lkmm.sh [项目根]        跑 <项目根>/litmus/*.litmus
#
# 每个 .litmus 必须在文件里声明期望判定：
#
#   (* singlefs-expect: Never *)      坏结果必须不可能发生
#   (* singlefs-expect: Sometimes *)  坏结果可能发生（对照组用）
#
# 判定与声明不符 → 失败。没有声明 → 失败（不许「跑了但没人看结果」）。
#
# 会失败的检查（都是踩过的坑，做成拒绝执行而不是提醒句）：
#   1. 用了 rN 却没有 `int rN;` 声明 —— herd7 不管，klitmus7 会在生成 C 之后
#      才报 undeclared，那时已经很难定位。这里提前拦。
#   2. init 块里给 atomic_t 形参赋初值不带类型 —— herd7 照跑且判定正确，
#      只有 klitmus7 会炸。也就是说这个错能一路混过模型判定，必须在这里拦。
#   3. 必须有 Never 和 Sometimes 两侧。全是 Never 说明没有对照组，
#      分不清「屏障挡住了」还是「这个模式本来就撞不上」。
#   4. 没有 herd7 直接失败，不静默跳过。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
LITMUS_DIR="$ROOT/litmus"
KTREE="${SINGLEFS_KERNEL_TREE:-}"

head1 "LKMM（herd7）"

# ── herd7 ──
if ! command -v herd7 >/dev/null 2>&1 && command -v opam >/dev/null 2>&1; then
  export OPAMROOT="${OPAMROOT:-$HOME/.opam}"
  eval "$(opam env --root="$OPAMROOT" --set-root 2>/dev/null)" || true
fi
command -v herd7 >/dev/null 2>&1 || {
  bad "herd7 缺失"
  howto "opam install herdtools7" \
        "（装完若命令仍找不到，先 eval \"\$(opam env)\"）"
  exit 1
}

# ── 内核树（herd7 要在 tools/memory-model 里跑，模型文件是相对路径引的）──
if [[ -z "$KTREE" ]]; then
  for c in "$ROOT/../linux" "$HOME/linux" "$HOME/linux-bug-fix/linux"; do
    [[ -d "$c/tools/memory-model" ]] && { KTREE="$c"; break; }
  done
fi
# 按需取：委托给 fetch-deps.sh，取树的逻辑只有那一份实现
if [[ -z "$KTREE" || ! -d "$KTREE/tools/memory-model" ]]; then
  CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/singlefs/linux-memory-model"
  if [[ -d "$CACHE/tools/memory-model" ]]; then
    KTREE="$CACHE"
  elif [[ -z "${SINGLEFS_NO_FETCH:-}" ]]; then
    bash "$(dirname "${BASH_SOURCE[0]}")/fetch-deps.sh" --kernel || exit 1
    [[ -d "$CACHE/tools/memory-model" ]] && KTREE="$CACHE"
  fi
fi

[[ -n "$KTREE" && -d "$KTREE/tools/memory-model" ]] || {
  bad "找不到带 tools/memory-model 的内核树"
  howto "herd7 要在内核树的 tools/memory-model 里跑（模型文件是相对路径引的）。" \
        "指一棵 Linux 源码树：" \
        "SINGLEFS_KERNEL_TREE=/path/to/linux bash .claude/scripts/lkmm.sh"
  exit 1
}
KTREE="$(readlink -f "$KTREE")"
ok "内核树 $KTREE"
ok "herd7  $(herd7 -version 2>&1 | head -1)"

[[ -d "$LITMUS_DIR" ]] || { bad "没有 $LITMUS_DIR 目录"; exit 1; }
# 路径必须绝对化：下面要 cd 进内核树跑 herd7（模型文件是相对路径引的），
# 相对路径 cd 之后就找不着了
mapfile -t FILES < <(find "$LITMUS_DIR" -name '*.litmus' -exec readlink -f {} \; | sort)
[[ ${#FILES[@]} -gt 0 ]] || { bad "$LITMUS_DIR 下没有 .litmus 文件"; exit 1; }

# ── 静态检查：寄存器声明 / atomic_t 初值类型 / 期望声明 ──
fails=0
declare -A EXPECT
for f in "${FILES[@]}"; do
  rel="${f#"$ROOT"/}"
  exp="$(sed -n 's/.*singlefs-expect:[[:space:]]*\([A-Za-z]*\).*/\1/p' "$f" | head -1)"
  case "$exp" in
    Never|Sometimes|Always) EXPECT["$f"]="$exp" ;;
    *) bad "$rel 缺 (* singlefs-expect: Never|Sometimes *) 声明"; fails=$((fails+1)); continue ;;
  esac
  for r in $(grep -oE '\br[0-9]+\b' "$f" | sort -u); do
    grep -qE "^[[:space:]]*int[[:space:]]+$r[[:space:]]*;" "$f" \
      || { bad "$rel 用了 $r 但没有 'int $r;'（klitmus7 会在生成 C 之后才报）"; fails=$((fails+1)); }
  done
  init="$(awk '/^\{/{f=1} f{print} f&&/\}/{exit}' "$f")"
  for v in $(grep -oE 'atomic_t[[:space:]]*\*[[:space:]]*[A-Za-z_][A-Za-z0-9_]*' "$f" \
             | sed -E 's/.*\*[[:space:]]*//' | sort -u); do
    printf '%s\n' "$init" | grep -qE "(^|[^[:alnum:]_])$v[[:space:]]*=" || continue
    printf '%s\n' "$init" | grep -qE "atomic_t[[:space:]]+$v[[:space:]]*=" \
      || { bad "$rel init 里 '$v = ...' 要写成 'atomic_t $v = ...'（只有 klitmus7 会炸）"; fails=$((fails+1)); }
  done
done
[[ $fails -eq 0 ]] || { bad "静态检查未过：$fails 项"; exit 1; }

# ── 必须有对照组 ──
n_never=0; n_some=0
for f in "${FILES[@]}"; do
  [[ "${EXPECT[$f]}" == Never ]] && n_never=$((n_never+1))
  [[ "${EXPECT[$f]}" == Sometimes ]] && n_some=$((n_some+1))
done
if [[ $n_never -gt 0 && $n_some -eq 0 ]]; then
  bad "只有 Never 没有 Sometimes —— 缺对照组"
  say "        没有对照组就分不清「屏障挡住了」还是「这个模式本来就撞不上」"
  howto "复制那份 Never 的 litmus，删掉里面的屏障（smp_wmb / smp_rmb 等），" \
        "把声明改成 Sometimes。它判 Sometimes 才说明原来那条有判别力。"
  exit 1
fi

# ── 跑 ──
say ""
cd "$KTREE/tools/memory-model"
for f in "${FILES[@]}"; do
  rel="litmus/$(basename "$f")"   # 此时已 cd 进内核树，不能再算相对路径
  want="${EXPECT[$f]}"
  out="$(timeout 300 herd7 -conf linux-kernel.cfg "$f" 2>&1)" || {
    bad "$rel  herd7 执行失败"; printf '%s\n' "$out" | tail -5 | sed 's/^/        /'
    howto "看上面的报错。多半是 litmus 语法问题，照 litmus/ 现有文件的格式改；" \
          "超时（300s）则是状态空间太大，把进程数或变量数减下来。"
    fails=$((fails+1)); continue
  }
  got="$(printf '%s\n' "$out" | sed -n 's/^Observation[[:space:]]\+[^[:space:]]\+[[:space:]]\+\([A-Za-z]*\).*/\1/p' | head -1)"
  if [[ -z "$got" ]]; then
    bad "$rel  读不到 Observation 行 —— 判定不明，整条作废"
    printf '%s\n' "$out" | tail -5 | sed 's/^/        /'; fails=$((fails+1))
    howto "多半是 litmus 语法错。最常见的一处：进程签名后面不能跟行内注释，" \
          "注释只能写在文件头的 (* ... *) 块里。照 litmus/ 现有文件的格式改。"
  elif [[ "$got" == "$want" ]]; then
    ok "$rel  $got（符合声明）"
  else
    bad "$rel  期望 $want，实际 $got"
    printf '%s\n' "$out" | grep -E '^(States|Condition|Observation)' | sed 's/^/        /'
    howto "两种可能，别急着改声明：" \
      "① 代码或模型真的少了屏障 → 这正是这条测试要抓的东西，去补屏障" \
      "② 这条声明本来就写错了   → 改 (* singlefs-expect: ... *)" \
      "先想清楚是哪一种。直接把声明改成实际值，等于把测试关掉。"
    fails=$((fails+1))
  fi
done

say ""
[[ $fails -eq 0 ]] || { bad "LKMM 未通过：$fails 项"; exit 1; }
ok "LKMM 通过（$n_never 条 Never + $n_some 条对照 Sometimes）"
