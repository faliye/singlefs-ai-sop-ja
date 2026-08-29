#!/usr/bin/env bash
# 门禁自己的测试：拿一组「本该红」和「本该绿」的样本喂给 doc-lint.sh，看它判得对不对。
#
# 为什么必须有（rules/sop-first.md）：
#   改了 scripts/ 就得造一个应该被拦的输入，确认它真的会红。
#   没有自检能力的门禁是摆设——一条永远不红的检查与没有这条检查，
#   在门禁输出里长得一模一样。
#
# 每个样本是 scripts/fixtures/doc-lint/<名>/，里面：
#   kb/*.md   —— 喂进去的内容
#   expect    —— exit=0|1，以及零到多条 want=<失败信息里必须出现的片段>
#
# want 存在的理由：只比对退出码的话，一个「因为别的原因红了」的样本也算过，
# 于是被测的那条检查悄悄失效也看不出来。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FX="$SCRIPTS/fixtures/doc-lint"
tmpd="$(mktemp -d)"; trap 'rm -rf "$tmpd"' EXIT

head1 "门禁自检：doc-lint 的判别力"

[[ -d "$FX" ]] || { bad "缺样本目录 $FX"
  howto "样本要随仓走。没有样本，下一个改 doc-lint.sh 的人无从复跑。"; exit 1; }

pass=0; fails=0; cases=0
for d in "$FX"/*/; do
  name="$(basename "$d")"
  [[ -f "$d/expect" ]] || { bad "$name 缺 expect 文件"
    howto "写一行 exit=0 或 exit=1，红的样本再加至少一条 want=<失败信息片段>。"
    fails=$((fails+1)); continue; }
  cases=$((cases+1))
  want_exit="$(sed -n 's/^exit=//p' "$d/expect")"
  out="$tmpd/$name.out"
  set +e
  bash "$SCRIPTS/doc-lint.sh" "$d" > "$out" 2>&1
  got_exit=$?
  set -e
  ok_this=1
  if [[ "$got_exit" != "$want_exit" ]]; then
    bad "$name  退出码 $got_exit，应为 $want_exit"
    howto "看 doc-lint.sh 对这个样本的输出： bash scripts/doc-lint.sh $FX/$name" \
          "样本本身该改就改 expect，检查坏了就改 doc-lint.sh——别两边一起改到自洽为止。"
    ok_this=0
  else
    while IFS= read -r w; do
      [[ -z "$w" ]] && continue
      grep -q -- "$w" "$out" || {
        bad "$name  退出码对，但失败信息里没有「$w」"
        howto "退出码对不等于拦对了原因——这个样本可能是因为别的检查红的。" \
              "跑： bash scripts/doc-lint.sh $FX/$name  看它到底报了什么。"
        ok_this=0; }
    done < <(sed -n 's/^want=//p' "$d/expect")
  fi
  if [[ $ok_this -eq 1 ]]; then
    pass=$((pass+1))
    [[ -n "${SELFTEST_VERBOSE:-}" ]] && ok "$name"
  else
    fails=$((fails+1))
  fi
done

say ""
[[ $cases -gt 0 ]] || { bad "一个样本都没跑"
  howto "样本目录空了。至少要有一个该绿的和一个该红的，否则这个自检本身什么也不证明。"; exit 1; }
[[ $fails -eq 0 ]] || { bad "门禁自检失败：$fails 个样本判错（共 $cases）"; exit 1; }
ok "门禁自检通过：$pass 个样本判定与预期一致（SELFTEST_VERBOSE=1 看逐条）"
