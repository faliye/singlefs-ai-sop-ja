#!/usr/bin/env bash
# 门禁自己的测试：拿一组「本该红」和「本该绿」的样本喂给各个门禁脚本，看它判得对不对。
#
# 为什么必须有（rules/sop-first.md）：
#   改了 scripts/ 就得造一个应该被拦的输入，确认它真的会红。
#   没有自检能力的门禁是摆设——一条永远不红的检查与没有这条检查，
#   在门禁输出里长得一模一样。
#
# 以前只有 doc-lint 有样本，其余脚本全在盲区——一次对抗测试在盲区里挖出了
# gate-lint 四种漏检、Show me test 三种绕过、i18n-sync 在失败分支里的静默崩溃。
# 所以现在每个能独立跑的门禁脚本都有自己的样本或脚本化用例。
#
# 两类用例：
#   1. 样本目录  scripts/fixtures/<脚本名>/<样本名>/：
#      喂进去的内容 + expect（exit=0|1，红样本再加至少一条 want=<输出里必须出现的片段>）
#   2. 脚本化用例（要临时 git 仓才能摆出来的场景）：在本文件里现搭现跑
#
# want 存在的理由：只比对退出码的话，一个「因为别的原因红了」的样本也算过，
# 于是被测的那条检查悄悄失效也看不出来。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FX="$SCRIPTS/fixtures"
tmpd="$(mktemp -d)"; trap 'rm -rf "$tmpd"' EXIT

pass=0; fails=0; cases=0

# ── 断言器：退出码 + 输出片段 ───────────────────────────
judge() { # judge <名> <期望exit> <实际exit> <输出文件> [want片段...]
  cases=$((cases+1))
  local name="$1" wexit="$2" gexit="$3" out="$4"; shift 4
  local ok_this=1
  if [[ "$gexit" != "$wexit" ]]; then
    bad "$name  退出码 $gexit，应为 $wexit"
    howto "看这个用例的完整输出： cat $out" \
          "样本本身该改就改预期，检查坏了就改检查——别两边一起改到自洽为止。"
    ok_this=0
  else
    local w
    for w in "$@"; do
      [[ -z "$w" ]] && continue
      grep -qF -- "$w" "$out" || {
        bad "$name  退出码对，但输出里没有「$w」"
        howto "退出码对不等于拦对了原因——可能是因为别的检查红的。" \
              "看输出： cat $out"
        ok_this=0; }
    done
  fi
  if [[ $ok_this -eq 1 ]]; then
    pass=$((pass+1)); [[ -n "${SELFTEST_VERBOSE:-}" ]] && ok "$name"
  else
    fails=$((fails+1))
  fi
  return 0
}

# ── 样本目录跑法：expect 文件驱动 ───────────────────────
run_fixture() { # run_fixture <标签> <样本目录> <命令...>（命令自行引用样本目录）
  local label="$1" d="$2"; shift 2
  [[ -f "$d/expect" ]] || { cases=$((cases+1)); fails=$((fails+1))
    bad "$label 缺 expect 文件"
    howto "写一行 exit=0 或 exit=1，红的样本再加至少一条 want=<输出片段>。"
    return 0; }
  local wexit; wexit="$(sed -n 's/^exit=//p' "$d/expect")"
  local wants=(); local w
  while IFS= read -r w; do wants+=("$w"); done < <(sed -n 's/^want=//p' "$d/expect")
  local out="$tmpd/$(printf '%s' "$label" | tr '/ ' '__').out"
  local rc=0
  set +e; "$@" > "$out" 2>&1; rc=$?; set -e
  judge "$label" "$wexit" "$rc" "$out" ${wants[@]+"${wants[@]}"}
}

# ── 脚本化用例跑法 ──────────────────────────────────────
run_scripted() { # run_scripted <名> <期望exit> <want...> -- <命令...>
  local name="$1" wexit="$2"; shift 2
  local wants=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do wants+=("$1"); shift; done
  shift
  local out="$tmpd/$(printf '%s' "$name" | tr '/ ' '__').out"
  local rc=0
  set +e; "$@" > "$out" 2>&1; rc=$?; set -e
  judge "$name" "$wexit" "$rc" "$out" ${wants[@]+"${wants[@]}"}
}

# ════ doc-lint ═══════════════════════════════════════════
head1 "门禁自检：doc-lint 的判别力"
[[ -d "$FX/doc-lint" ]] || { bad "缺样本目录 $FX/doc-lint"
  howto "样本要随仓走。没有样本，下一个改 doc-lint.sh 的人无从复跑。"; exit 1; }
for d in "$FX"/doc-lint/*/; do
  run_fixture "doc-lint/$(basename "$d")" "$d" bash "$SCRIPTS/doc-lint.sh" "$d"
done

# ════ gate-lint ══════════════════════════════════════════
head1 "门禁自检：gate-lint 的判别力"
for d in "$FX"/gate-lint/*/; do
  [[ -d "$d" ]] || continue
  run_fixture "gate-lint/$(basename "$d")" "$d" \
    env GATE_LINT_DIR="$d" bash "$SCRIPTS/gate-lint.sh"
done

# ════ lkmm（静态检查与对照组；herd7 不在场也判得了这两层）══
head1 "门禁自检：lkmm 静态检查的判别力"
for d in "$FX"/lkmm/*/; do
  [[ -d "$d" ]] || continue
  run_fixture "lkmm/$(basename "$d")" "$d" bash "$SCRIPTS/lkmm.sh" "$d"
done

# ════ show-me-test（要 git 仓才摆得出场景，现搭现跑）═════
head1 "门禁自检：show-me-test 的判别力"
mk_repo() { # mk_repo <目录> —— 一个已提交基线的最小 crates 仓
  mkdir -p "$1/crates/foo/src"
  git -C "$1" init -qb master
  printf 'pub fn f() -> u32 { 1 }\n' > "$1/crates/foo/src/lib.rs"
  git -C "$1" add -A
  git -C "$1" -c user.email=selftest@local -c user.name=selftest commit -qm init
}
r="$tmpd/smt-naked"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n' >> "$r/crates/foo/src/lib.rs"
run_scripted "show-me-test/改代码无测试拒收" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-comment"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n// 计划稍后 #[test]\n' >> "$r/crates/foo/src/lib.rs"
run_scripted "show-me-test/注释里的test标注不算" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-eolcomment"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 } // 待补 #[test]\n' >> "$r/crates/foo/src/lib.rs"
run_scripted "show-me-test/行尾注释的test标注不算" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-shell"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n' >> "$r/crates/foo/src/lib.rs"
mkdir -p "$r/tests"; printf '// 空壳占位\n' > "$r/tests/t.rs"
git -C "$r" add tests
run_scripted "show-me-test/tests下的空壳rs不算" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-datafile"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n' >> "$r/crates/foo/src/lib.rs"
mkdir -p "$r/tests"; echo x > "$r/tests/note.txt"
run_scripted "show-me-test/tests下非代码文件不算" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-real"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n' >> "$r/crates/foo/src/lib.rs"
mkdir -p "$r/tests"; printf '#[test]\nfn t() { assert_eq!(1, 1); }\n' > "$r/tests/t.rs"
run_scripted "show-me-test/真测试放行" 0 伴随测试 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-committed"; mk_repo "$r"
printf 'pub fn g() -> u32 { 2 }\n' >> "$r/crates/foo/src/lib.rs"
git -C "$r" add -A
git -C "$r" -c user.email=selftest@local -c user.name=selftest commit -qm naked
run_scripted "show-me-test/提交进master也逃不掉" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-buildrs"; mk_repo "$r"
printf 'fn main() {}\n' > "$r/crates/foo/build.rs"
run_scripted "show-me-test/build.rs也是代码" 1 拒收 -- bash "$SCRIPTS/show-me-test.sh" "$r"

r="$tmpd/smt-nothing"; mk_repo "$r"
run_scripted "show-me-test/无对象可判" 3 无对象可判 -- bash "$SCRIPTS/show-me-test.sh" "$r"

# ════ version-discipline ═════════════════════════════════
head1 "门禁自检：version-discipline 的判别力"
mk_sop() { # mk_sop <目录> —— 一个已提交基线的最小规范仓
  mkdir -p "$1/scripts"
  printf '0.0.1\n' > "$1/VERSION"
  printf 'echo hi\n' > "$1/scripts/x.sh"
  git -C "$1" init -qb master
  git -C "$1" add -A
  git -C "$1" -c user.email=selftest@local -c user.name=selftest commit -qm init
}
r="$tmpd/vd-red"; mk_sop "$r"
printf 'echo more\n' >> "$r/scripts/x.sh"
run_scripted "version-discipline/改脚本不抬版本" 1 没抬 -- bash "$SCRIPTS/version-discipline.sh" "$r"

r="$tmpd/vd-green"; mk_sop "$r"
printf 'echo more\n' >> "$r/scripts/x.sh"
printf '0.0.2\n' > "$r/VERSION"
run_scripted "version-discipline/带着版本一起改" 0 也在变更集 -- bash "$SCRIPTS/version-discipline.sh" "$r"

r="$tmpd/vd-na"; mk_sop "$r"
echo note > "$r/README.md"
run_scripted "version-discipline/无关改动不管" 0 不适用 -- bash "$SCRIPTS/version-discipline.sh" "$r"

# ════ manifest 与 i18n-sync（失败分支曾静默崩溃，这两条是回归钉）══
head1 "门禁自检：manifest / i18n-sync 的判别力"
mk_pkg() { # mk_pkg <目录> <族名> —— 一个最小参照仓（脚本用真的，内容是样本）
  mkdir -p "$1/scripts" "$1/rules"
  cp "$SCRIPTS/lib.sh" "$SCRIPTS/manifest.sh" "$SCRIPTS/i18n-sync.sh" "$1/scripts/"
  printf '# 样本规范\n' > "$1/CLAUDE.md"
  printf '# 规则甲\n' > "$1/rules/a.md"
  printf '0.0.1\n' > "$1/VERSION"
  printf 'family=%s\nthis=zh\nreference=zh\ndefault=zh\nlanguages=zh en\n' "$2" > "$1/I18N"
  bash "$1/scripts/manifest.sh" --update >/dev/null
}
p="$tmpd/mani/f-zh"; mk_pkg "$p" f
printf '改了一句\n' >> "$p/rules/a.md"
run_scripted "manifest/清单陈旧要红且给出路" 1 不一致 怎么办 -- bash "$p/scripts/manifest.sh"

p="$tmpd/i18n/f-zh"; mk_pkg "$p" f
sib="$tmpd/i18n/f-en"; mkdir -p "$sib"
cp "$p/MANIFEST.sha256" "$sib/SOURCE-MANIFEST.sha256"
printf '0.0.1\n' > "$sib/VERSION"
printf '改了一句\n' >> "$p/rules/a.md"
bash "$p/scripts/manifest.sh" --update >/dev/null
# 关键 want：待重译（诊断打了）+ 怎么办（howto 打了）+ 失败汇总（脚本活到了最后）。
# 曾经 diff 管道在 set -e + pipefail 下把脚本中途带走，三样全丢（对抗测试实测）。
run_scripted "i18n-sync/落后要红且诊断齐全" 1 待重译 怎么办 三语同步失败 -- \
  bash "$p/scripts/i18n-sync.sh"

# ── 汇总 ────────────────────────────────────────────────
say ""
[[ $cases -gt 0 ]] || { bad "一个用例都没跑"
  howto "样本目录空了。至少要有一个该绿的和一个该红的，否则这个自检本身什么也不证明。"; exit 1; }
[[ $fails -eq 0 ]] || { bad "门禁自检失败：$fails 个用例判错（共 $cases）"; exit 1; }
ok "门禁自检通过：$pass 个用例判定与预期一致（SELFTEST_VERBOSE=1 看逐条）"
