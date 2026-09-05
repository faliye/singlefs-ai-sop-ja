#!/usr/bin/env bash
# 样本：同样扫一批对象，但成功摘要带着计数——0 项时它自己会露出来。
n=0
for f in "$1"/*.md; do
  n=$((n + 1))
done
ok "检查通过（共 $n 项）"
