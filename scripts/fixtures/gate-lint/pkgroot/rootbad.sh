#!/usr/bin/env bash
# 样本：仓根的脚本也要扫。install.sh 就在仓根，是使用者跑的第一个脚本。
[[ -f Cargo.toml ]] || die "单测失败"
