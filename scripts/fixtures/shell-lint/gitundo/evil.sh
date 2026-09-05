#!/usr/bin/env bash
# 样本：脚本里用会丢掉未提交改动的 git 命令。跑的时候没人看 git status。
revert_one() {
  git checkout -- src/lib.rs
}
revert_all() {
  git -C "$root" restore .
}
nuke() {
  git reset --hard HEAD~1
}
wipe() {
  git clean -fdx
}
