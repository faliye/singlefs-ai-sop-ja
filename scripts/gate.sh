#!/usr/bin/env bash
# 准入门禁。rules/show-me-test.md的可执行形式。
#
# 设计原则：
#   1. 未实现的阶段**显式报告为未实现**，绝不静默跳过（第一节第 5 条）
#   2. 任何阶段都能失败——不存在只会成功的检查
#   3. 退出码：0 = 全部已实现阶段通过；非 0 = 有阶段失败
#
# 注意：本门禁当前**尚未覆盖崩溃一致性**。绿色不等于验证充分，见文末未实现清单。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(project_root)}"
[[ -d "$ROOT" ]] || die "找不到项目根"
cd "$ROOT"

STAGES=(); RESULTS=(); NOT_RUN=()
record() { STAGES+=("$1"); RESULTS+=("$2"); }

run_stage() { # run_stage <名称> <命令...>
  local name="$1"; shift
  head1 "$name"
  if "$@"; then record "$name" PASS; else record "$name" FAIL; fi
}

# ── 阶段 0：规范版本一致性 ───────────────────────────────
head1 "规范版本"
# 版本戳是给消费项目用的；SOP 仓自身没有也不该有。判据同「三语同步」：
# 被门禁的 ROOT 是不是 SOP 仓本身。
if [[ "$(cd "$ROOT" && pwd)" == "$(cd "$SCRIPTS/.." && pwd)" ]]; then
  ok "本仓即 SOP 本身，无需版本戳"
  record "规范版本" PASS
else
pkg_ver="$(cat "$SCRIPTS/../VERSION" 2>/dev/null || echo "?")"
proj_ver="$(cat "$ROOT/.singlefs-ai-sop-version" 2>/dev/null || echo "")"
if [[ -z "$proj_ver" ]]; then
  warn "项目未声明规范版本（缺 .singlefs-ai-sop-version）"
  record "规范版本" FAIL
elif [[ "$proj_ver" != "$pkg_ver" ]]; then
  bad "规范版本不一致：项目声明 $proj_ver，singlefs-ai-sop 是 $pkg_ver"
  howto "先读一遍上游的规范变更（git log .claude/singlefs-ai-sop/），" \
        "确认没有影响你这次改动，再跑 bash .claude/singlefs-ai-sop/install.sh 更新版本戳。"
  record "规范版本" FAIL
else
  ok "规范版本 $pkg_ver"
  record "规范版本" PASS
fi
fi

# ── 阶段 0b：门禁自身（每条拒绝都要给出路）──────────────
run_stage "门禁自检" bash "$SCRIPTS/gate-lint.sh"

# ── 阶段 1：文档铁律 ────────────────────────────────────
run_stage "文档铁律" bash "$SCRIPTS/doc-lint.sh" "$ROOT"

# ── 阶段 2：Show me test ────────────────────────────────
head1 "Show me test"
BASE="$(diff_base "$ROOT")"
say "  diff 基准：$BASE"
files="$(changed_files "$ROOT" "$BASE")"

if [[ -z "$files" ]]; then
  # 无变更既不是通过也不是失败——没有可判的对象。判成失败会让「刚装完就有一格红」
  # 成为常态，而红色一旦成为常态就不再是信号，人会开始习惯性忽略它。
  warn "工作区与基准无差异 —— 本阶段无对象可判（这不是通过）"
  NOT_RUN+=("Show me test        本次无对象可判：工作区与 $BASE 无差异。改动之后再跑，或指定基准： GATE_BASE=<ref> bash .claude/scripts/gate.sh")
else
  code_changed="$(printf '%s\n' "$files" | grep -E '^crates/.*/src/.*\.rs$' || true)"
  test_files="$(printf '%s\n' "$files" | grep -E '(^|/)(tests|benches|fuzz)/' || true)"
  TEST_RE='#\[test\]|#\[cfg\(test\)\]|proptest!|#\[kani|#\[tokio::test\]'
  test_lines="$(added_lines "$ROOT" "$BASE" | grep -E "$TEST_RE" || true)"
  # 新建的未跟踪文件在 diff 里看不见，内联测试会被漏掉——直接扫文件内容。
  # 对刚起步的项目，新文件是常态，漏掉等于这条门禁形同虚设。
  untracked_tests=""
  while IFS= read -r uf; do
    [[ -f "$ROOT/$uf" ]] || continue
    if grep -qE "$TEST_RE" "$ROOT/$uf"; then untracked_tests+="$uf"$'\n'; fi
  done < <(git -C "$ROOT" ls-files --others --exclude-standard -- '*.rs' 2>/dev/null || true)
  test_lines="$test_lines$untracked_tests"

  if [[ -z "$code_changed" ]]; then
    ok "无 crates/*/src 改动（仅文档/脚本），本阶段不适用"
    record "Show me test" PASS
  elif [[ -n "$test_files" || -n "$test_lines" ]]; then
    ok "代码改动伴随测试改动"
    [[ -n "$test_files" ]] && printf '%s\n' "$test_files" | sed 's/^/        测试文件: /'
    [[ -n "$test_lines" ]] && say "        新增测试标注 $(printf '%s\n' "$test_lines" | wc -l) 处"
    warn "脚本只能验证「有测试」，验证不了「测试会红」——"
    warn "  按 rules/show-me-test.md，请在 commit message 写明你是怎么确认它会红的"
    record "Show me test" PASS
  else
    bad "改了 crates/*/src 但没有任何测试改动，按 rules/show-me-test.md 拒收："
    printf '%s\n' "$code_changed" | sed 's/^/        /'
    howto "给这次改动补测试。不确定怎么测的话，按改动类型对号入座：" \
      "纯函数 / 数据结构   → 同文件里加 #[cfg(test)] mod tests，最省事" \
      "涉及并发或内存序    → litmus/ 下加一对 .litmus（Never + 去掉屏障的对照组）," \
      "                      照着现有的抄，跑 bash .claude/scripts/lkmm.sh" \
      "涉及磁盘格式        → 先在 kb/invariants.md 加一条不变量，再让 checker 实现它" \
      "涉及崩溃恢复        → 见 crash-test skill；这条还没有 harness，说明情况即可" \
      "" \
      "写完把被测代码改坏一次，确认测试真的变红，再改回来——" \
      "并在 commit message 里写明你是怎么确认的。"
    record "Show me test" FAIL
  fi
fi

# ── 阶段 3：构建与单测 ──────────────────────────────────
if [[ ! -f "$ROOT/Cargo.toml" ]]; then
  head1 "构建与单测"
  if [[ -n "$(find "$ROOT/crates" -name '*.rs' 2>/dev/null | head -1)" ]]; then
    bad "有 .rs 文件却没有 Cargo.toml —— 这些代码根本没被构建过"
    howto "在仓库根建 Cargo.toml（workspace），把 crates/* 列进 members。"
    record "构建与单测" FAIL
  else
    ok "项目尚无 Rust 代码，本阶段不适用"
    record "构建与单测" PASS
  fi
elif ! command -v cargo >/dev/null 2>&1; then
  head1 "构建与单测"
  bad "有 Cargo.toml 但 cargo 缺失 —— 无法验证，按失败处理（不降级、不跳过）"
  howto "装 Rust 工具链：" \
        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  record "构建与单测" FAIL
else
  run_stage "构建与单测" bash "$SCRIPTS/check.sh" "$ROOT"
fi

# ── 阶段 3b：规则清单（译文仓的对账依据）─────────────────
if [[ -d "$SCRIPTS/../rules" && -f "$SCRIPTS/manifest.sh" ]]; then
  run_stage "规则清单" bash "$SCRIPTS/manifest.sh"
  # 译文同步是 SOP 仓自己的事，消费项目那边没有兄弟语言仓，不该判它。
  # 判据：被门禁的这个 ROOT 是不是 SOP 仓本身。
  if [[ -f "$SCRIPTS/../I18N" && "$(cd "$ROOT" && pwd)" == "$(cd "$SCRIPTS/.." && pwd)" ]]; then
    run_stage "三语同步" bash "$SCRIPTS/i18n-sync.sh"
  fi
fi

# ── 阶段 4：LKMM（内存序）───────────────────────────────
if [[ -d "$ROOT/litmus" ]]; then
  run_stage "LKMM" bash "$SCRIPTS/lkmm.sh" "$ROOT"
else
  head1 "LKMM"
  ok "项目没有 litmus/ 目录，本阶段不适用"
  record "LKMM" PASS
fi

# ── 阶段 5：QEMU harness 自检（默认不跑，太慢）──────────
if [[ -n "${GATE_QEMU:-}" ]]; then
  run_stage "QEMU harness" bash "$SCRIPTS/qemu/run.sh" --selftest "$ROOT"
else
  NOT_RUN+=("QEMU harness 自检   本次未跑（要两次虚机启动）。跑： GATE_QEMU=1 bash .claude/scripts/gate.sh")
fi

# ── 未实现的阶段（必须显式列出）────────────────────────
NOT_IMPL=(
  "模型对拍          需要 checker 与实现存在（rules/test-discipline.md）"
  "崩溃点重放        需要块层写记录 + checker（rules/test-discipline.md）"
  "QEMU 真实负载     harness 已就绪并自检通过，缺被测对象（kb/decisions.md D4/D8）"
)

# ── 汇总 ────────────────────────────────────────────────
head1 "门禁结果"
failed=0
for i in "${!STAGES[@]}"; do
  if [[ "${RESULTS[$i]}" == PASS ]]; then ok "${STAGES[$i]}"
  else bad "${STAGES[$i]}"; failed=$((failed+1)); fi
done

if [[ ${#NOT_RUN[@]} -gt 0 ]]; then
  printf '\n%s本次未跑的阶段：%s\n' "$C_YEL" "$C_RST"
  for s in "${NOT_RUN[@]}"; do warn "$s"; done
fi

printf '\n%s未实现的门禁阶段（绿色不代表验证充分）：%s\n' "$C_YEL" "$C_RST"
for s in "${NOT_IMPL[@]}"; do warn "$s"; done

say ""
if [[ $failed -gt 0 ]]; then
  bad "门禁未通过：$failed 个阶段失败"
  exit 1
fi
ok "已实现的门禁阶段全部通过（共 ${#STAGES[@]} 个）"
warn "Gate proves evidence requirements, not semantic correctness."
warn "门禁证明的是证据要求被满足，不是代码语义正确——绿灯之后仍要看「测的是不是对的东西」。"
warn "另：崩溃一致性尚未纳入门禁，此结果不足以证明写路径正确。"
