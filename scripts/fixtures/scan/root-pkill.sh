#!/usr/bin/env bash
# 包根的脚本：按模式杀进程，必须被扫到。
stop_vm() {
  pkill -f qemu-system-x86_64
}
