#!/usr/bin/env bash
# 样本：howto 离 bad 太远。窗口是 bad 自己那行 + 后面 4 行（rules/sop-first.md），
# 这里隔了 5 个非注释行——把窗口改大，这个样本就变绿，selftest 当场红。
check_one() {
  bad "这里不合格"
  x=1
  y=2
  z=3
  w=4
  howto "太晚了，提交者已经翻页了"
}
