#!/usr/bin/env bash
# 包根的脚本：只带一句话的 die，必须被扫到。
[[ -f Cargo.toml ]] || die "单测失败"
