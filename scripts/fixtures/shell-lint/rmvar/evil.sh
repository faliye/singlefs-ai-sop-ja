#!/usr/bin/env bash
# 样本：变量为空时 rm -rf 会从根目录往下删。
clean_one() {
  rm -rf "$repo/item"
}
clean_two() {
  rm -r "${dest}/build"
}
