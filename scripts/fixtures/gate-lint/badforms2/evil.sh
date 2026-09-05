#!/usr/bin/env bash
# 样本：命令位置的另外几种形态。CMD_POS 漏了括号时，前两条整体漏检。
check_a() { ( bad "甲不合格" ); }
check_b() { eval bad "乙不合格"; }
check_c() { command bad "丙不合格"; }
naked() { die "丁不合格" ""; }
