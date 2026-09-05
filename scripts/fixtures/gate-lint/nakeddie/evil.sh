#!/usr/bin/env bash
# 样本：die 是 bad + exit，同样是拒绝，不许只说「不合格」。
[[ -f Cargo.toml ]] || die "单测失败"
