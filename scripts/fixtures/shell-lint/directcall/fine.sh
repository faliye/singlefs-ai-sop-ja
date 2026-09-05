#!/usr/bin/env bash
# 样本：该绿的。这个函数既被直接调用、也被 $( ) 调用——
# 直接那次的赋值是传得出去的，判红没有依据。
init_paths() {
  LOGDIR="$1/logs"
  printf '%s' "$LOGDIR"
}
init_paths /tmp/run
echo "$(init_paths /tmp/other)"
echo "$LOGDIR"
