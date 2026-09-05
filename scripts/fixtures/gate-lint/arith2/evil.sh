#!/usr/bin/env bash
# 样本：`))` 出现在 `$((` 前面的那种行。挖算术展开时若在整行里找第一个 `))`，
# 切完的串仍含 `$((` 且不变短——无限循环。这个样本必须**跑得完**且是绿的。
okc=1; pass=0; fail=0
for f in "$1"/*.md; do
  if ((okc)); then pass=$((pass + 1)); else fail=$((fail + 1)); fi
done
ok "样本跑完（$pass 项）"
