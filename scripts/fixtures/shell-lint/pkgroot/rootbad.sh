#!/usr/bin/env bash
# 样本：仓根的脚本也要扫。
stop_vm() {
  pkill -f qemu-system-x86_64
}
stop_vm
