#!/usr/bin/env bash
# 样本：单引号写法的 die 同样是拒绝，不许因为引号种类不同就免检。
cargo test --all || die '单测失败'
