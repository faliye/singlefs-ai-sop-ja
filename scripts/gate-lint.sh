#!/usr/bin/env bash
# 门禁自身的门禁：每一条拒绝，都必须同时给出下一步。
#
# 为什么要有这个脚本（rules/sop-first.md）：
#   默认提交者是想通过的。他们被拦下来，多数时候不是不想测，是不知道怎么测。
#   一条只说「不合格」的失败信息，等于把「怎么做才对」留给人猜——
#   而人只能靠猜的时候，就会去绕过门禁，或者干脆不提交。
#
# 判据：每个非汇总性的 bad "..." 之后 4 行内必须出现 howto。
#   汇总行（"...未通过"/"...失败："）豁免——它们的细节在上面已经打过了。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
head1 "门禁自检（每条拒绝都要给出路）"

fails=0; checked=0
while IFS= read -r f; do
  rel="${f#"$SCRIPTS"/}"
  mapfile -t L < "$f"
  for ((i=0; i<${#L[@]}; i++)); do
    [[ "${L[$i]}" =~ ^[[:space:]]*bad[[:space:]]+\" ]] || continue
    # 汇总行豁免
    [[ "${L[$i]}" =~ (未通过|失败：|检查失败) ]] && continue
    checked=$((checked+1))
    found=0
    for ((j=i+1; j<i+5 && j<${#L[@]}; j++)); do
      [[ "${L[$j]}" =~ howto ]] && { found=1; break; }
    done
    if [[ $found -eq 0 ]]; then
      bad "$rel:$((i+1))  拒绝但没有 howto"
      say "        ${L[$i]}"
      howto "在这条 bad 后面 4 行内加一句 howto \"...\"，写清楚提交者下一步做什么。" \
            "不知道写什么，说明这条检查的判据自己也还没想清楚。"
      fails=$((fails+1))
    fi
  done
done < <(find "$SCRIPTS" -name '*.sh' -not -name 'lib.sh' | sort)

say ""
if [[ $fails -gt 0 ]]; then
  bad "门禁自检失败：$fails 条拒绝没有出路（共检查 $checked 条）"
  exit 1
fi
ok "门禁自检通过：$checked 条拒绝都带了 howto"
