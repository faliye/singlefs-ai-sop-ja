#!/usr/bin/env bash
# 样本：同一条命令的六种拼法，写死 -f 的时候整体漏检。
a() { pkill --full qemu; }
b() { pkill -af qemu; }
c() { /usr/bin/pkill -f qemu; }
d() { command pkill -f qemu; }
e() { /usr/bin/killall fio; }
f() { pgrep -f qemu | xargs kill; }
