#!/usr/bin/env bash
# 样本：qemu/run.sh 踩过的那个形态——函数在 $( ) 里跑，却靠全局变量把日志路径带出来。
run_one() {
  local payload="$1"
  LOGF="/tmp/console.log"
  printf '%s' 0
}
rc="$(run_one x)" || {
  tail -20 "$LOGF"
  exit 1
}
