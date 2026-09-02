#!/usr/bin/env bash
# 版本纪律：改了规范本体（rules/ scripts/ skills/ templates/ CLAUDE.md
# install.sh GLOSSARY.md）就必须同时抬 VERSION。
#
# CLAUDE.md 首屏写着这条规矩，但它以前只是提醒句——scripts/ 改了、VERSION 不动、
# 全部门禁照绿（对抗测试实测）。按 rules/show-me-test.md：踩过的坑要做成
# 会失败的检查，不要做成提醒句。所以有了这个脚本。
#
#   version-discipline.sh <SOP 仓根>
#
# 只对 SOP 仓本身有意义（gate.sh 在 ROOT 是 SOP 仓时才调它）；
# 消费项目改的是自己的代码，不受这条管。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
[[ -d "$ROOT" ]] || die "找不到仓根：$ROOT"

BASE="$(diff_base "$ROOT")"
say "  diff 基准：$BASE"
files="$(changed_files "$ROOT" "$BASE")"

governed="$(printf '%s\n' "$files" \
  | grep -E '^(rules/|scripts/|skills/|templates/|CLAUDE\.md$|install\.sh$|GLOSSARY\.md$)' || true)"

if [[ -z "$governed" ]]; then
  ok "本次没改规范本体，版本纪律不适用"
  exit 0
fi
if printf '%s\n' "$files" | grep -qx 'VERSION'; then
  ok "规范本体有改动，VERSION 也在变更集里"
  exit 0
fi
bad "改了规范本体却没抬 VERSION："
printf '%s\n' "$governed" | head -10 | sed 's/^/        /'
howto "用 bump.sh 一次抬齐三个语言仓（不要手改单个 VERSION）：" \
      "bash scripts/bump.sh <x.y.z>" \
      "项目侧靠版本戳发现规矩变了；VERSION 不动，改动就静默生效（CLAUDE.md 首屏）。"
exit 1
