#!/usr/bin/env bash
# 样本：只有 pkill -f。
stop_vm() {
  pkill -f qemu-system-x86_64
}
stop_vm
