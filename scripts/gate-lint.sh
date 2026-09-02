#!/usr/bin/env bash
# 门禁自身的门禁：每一条拒绝，都必须同时给出下一步。
#
# 为什么要有这个脚本（rules/sop-first.md）：
#   默认提交者是想通过的。他们被拦下来，多数时候不是不想测，是不知道怎么测。
#   一条只说「不合格」的失败信息，等于把「怎么做才对」留给人猜——
#   而人只能靠猜的时候，就会去绕过门禁，或者干脆不提交。
#
# 判据：每条非汇总性的 bad 调用，从它那一行起 5 个非注释行内必须出现 howto **命令**。
#   - bad 认的形态：行首、`;`/`{`/`||`/`&&`/`then`/`else`/`do` 之后、
#     单双引号或变量消息——以前只认「行首 + 双引号」，其余全部漏检（对抗测试实测）。
#   - howto 必须是命令位置（行首或 `;`/`{` 之后），注释里的 howto 字样不算
#     （对抗测试实测：`# TODO: howto` 就能糊弄过去）。
#   - 汇总行豁免收紧为「失败/未通过/未过 + 全角冒号 + 紧跟 $计数变量」——
#     以前消息里随便含「检查失败」四个字就永久免检（对抗测试实测）。
#
# GATE_LINT_DIR 可指定要扫的目录（selftest 拿样本喂它用），默认扫本脚本所在目录。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN="${GATE_LINT_DIR:-$SCRIPTS}"
head1 "门禁自检（每条拒绝都要给出路）"

BAD_RE='(^[[:space:]]*|[;{|&][[:space:]]*|(then|else|do)[[:space:]]+)bad[[:space:]]'
HOWTO_RE='(^[[:space:]]*|[;{|&][[:space:]]*|(then|else|do)[[:space:]]+)howto[[:space:]]'
SUMMARY_RE='(失败|未通过|未过)：\$'

fails=0; checked=0
while IFS= read -r f; do
  rel="${f#"$SCAN"/}"
  mapfile -t L < "$f"
  for ((i=0; i<${#L[@]}; i++)); do
    line="${L[$i]}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue        # 注释里的 bad 不算
    [[ "$line" =~ $BAD_RE ]] || continue
    [[ "$line" =~ $SUMMARY_RE ]] && continue           # 汇总行豁免（带计数变量的那种）
    checked=$((checked+1))
    found=0; seen=0
    for ((j=i; seen<5 && j<${#L[@]}; j++)); do         # 从 bad 自己那行起：bad "x"; howto 合法
      # 注释行不占窗口名额：在 bad 与 howto 之间写注释解释缘由是合法的，
      # 但注释里出现 howto 字样不算出路
      [[ "${L[$j]}" =~ ^[[:space:]]*# ]] && continue
      seen=$((seen+1))
      [[ "${L[$j]}" =~ $HOWTO_RE ]] && { found=1; break; }
    done
    if [[ $found -eq 0 ]]; then
      bad "$rel:$((i+1))  拒绝但没有 howto"
      say "        ${L[$i]}"
      howto "从这条 bad 起 5 行内加一句 howto \"...\"，写清楚提交者下一步做什么。" \
            "不知道写什么，说明这条检查的判据自己也还没想清楚。"
      fails=$((fails+1))
    fi
  done
done < <(find "$SCAN" -name '*.sh' -not -name 'lib.sh' -not -path "$SCAN/fixtures/*" | sort)

say ""
if [[ $fails -gt 0 ]]; then
  bad "门禁自检失败：$fails 条拒绝没有出路（共检查 $checked 条）"
  exit 1
fi
ok "门禁自检通过：$checked 条拒绝都带了 howto"
