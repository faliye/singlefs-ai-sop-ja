#!/usr/bin/env bash
# 环境自检。缺什么直接报什么，不猜、不降级、不静默跳过。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

head1 "环境自检"
missing=0

req() { # req <命令> <说明> <是否必须:hard|soft>
  local cmd="$1" desc="$2" level="${3:-hard}" ver
  if command -v "$cmd" >/dev/null 2>&1; then
    ver="$("$cmd" --version 2>/dev/null | head -1 || true)"
    ok "$cmd${ver:+  ($ver)}"
  else
    if [[ "$level" == hard ]]; then
      bad "$cmd 缺失"
      howto "$desc"
      missing=$((missing+1))
    else warn "$cmd 缺失 —— $desc（非阻塞）"; fi
  fi
}

req cargo    "Rust 工具链。装：curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" hard
req rustc    "同上" hard
req git      "版本控制" hard
req qemu-system-x86_64 "崩溃注入测试的运行环境" hard
req dmsetup  "块层写记录（崩溃点重放）" hard
req fio      "压测负载生成" soft
req shellcheck "脚本静态检查" soft

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
  ok "/dev/kvm 可读写"
else
  bad "/dev/kvm 不可用 —— QEMU 压测会退化到纯软件模拟，慢到不可用"
  howto "确认 BIOS 里开了虚拟化，并把自己加进 kvm 组：" \
        "sudo usermod -aG kvm \$USER   （重新登录后生效）"
  missing=$((missing+1))
fi

if [[ $missing -gt 0 ]]; then
  bad "环境自检失败：$missing 项缺失"
  exit 1
fi
ok "环境自检通过"
