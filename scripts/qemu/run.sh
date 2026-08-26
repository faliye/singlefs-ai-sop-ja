#!/usr/bin/env bash
# QEMU/KVM 压测 harness —— 准入的最终判据（rules/show-me-test.md）。
#
#   run.sh [项目根] [payload.sh]     在虚机里跑 payload，退出码传回宿主
#   run.sh --selftest                验证 harness 本身能分辨成功与失败
#
# 设计要点：
#   1. 退出码必须真的传回来。虚机里 payload 失败而宿主报成功，是最坏的一种假通过，
#      所以 --selftest 会跑一个**故意失败**的 payload，harness 认不出来就自己报错。
#   2. 镜像与 initramfs 一律放临时目录（rules/command-safety.md），不许落仓库。
#   3. 虚机 pid 写文件，按字面量 pid 清理，不按名字匹配。
#   4. 找不到可读内核直接失败并说清怎么办，不静默降级到软件模拟。
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

SELFTEST=0
[[ "${1:-}" == "--selftest" ]] && { SELFTEST=1; shift; }
ROOT="${1:-$(project_root)}"
PAYLOAD="${2:-}"

find_kernel() {
  [[ -n "${SINGLEFS_KERNEL:-}" ]] && { [[ -r "$SINGLEFS_KERNEL" ]] && { printf '%s' "$SINGLEFS_KERNEL"; return 0; }; return 1; }
  local k
  for k in /boot/vmlinuz-*; do [[ -r "$k" ]] && { printf '%s' "$k"; return 0; }; done
  return 1
}

# 在虚机里跑一个 payload，回显它的退出码；harness 自身出问题回 255
run_one() {
  local payload="$1" kernel="$2" work
  work="$(mktemp -d "${TMPDIR:-/tmp}/singlefs-qemu.XXXXXX")"
  local ird="$work/irfs" pidf="$work/qemu.pid" logf="$work/console.log"
  mkdir -p "$ird"/{bin,proc,sys,dev}
  cp "$(command -v busybox)" "$ird/bin/busybox"
  ( cd "$ird/bin" && ./busybox --list | while read -r a; do ln -sf busybox "$a"; done ) 2>/dev/null || true
  cp "$payload" "$ird/payload.sh"; chmod +x "$ird/payload.sh"
  cat > "$ird/init" <<'INIT'
#!/bin/sh
/bin/busybox mount -t proc proc /proc 2>/dev/null
/bin/busybox mount -t sysfs sysfs /sys 2>/dev/null
/payload.sh; rc=$?
echo "SINGLEFS_EXIT=$rc"
/bin/busybox poweroff -f
INIT
  chmod +x "$ird/init"
  ( cd "$ird" && find . | cpio -o -H newc --quiet | gzip -9 > "$work/initramfs.cpio.gz" )

  timeout 180 qemu-system-x86_64 \
    -enable-kvm -m 512 -smp 2 -no-reboot -nographic -serial mon:stdio -display none \
    -kernel "$kernel" -initrd "$work/initramfs.cpio.gz" \
    -append "console=ttyS0 quiet panic=1" \
    -pidfile "$pidf" >"$logf" 2>&1 || true

  # 清理：按文件里的字面量 pid，不按名字匹配（rules/command-safety.md）
  if [[ -s "$pidf" ]]; then
    local vp; vp="$(cat "$pidf")"
    [[ "$vp" =~ ^[0-9]+$ ]] && kill -0 "$vp" 2>/dev/null && kill -9 "$vp" 2>/dev/null || true
  fi

  local rc; rc="$(sed -n 's/.*SINGLEFS_EXIT=\([0-9]\+\).*/\1/p' "$logf" | tail -1)"
  QEMU_LOG="$logf"; QEMU_WORK="$work"
  [[ -n "$rc" ]] && { printf '%s' "$rc"; return 0; }
  return 1   # 读不到标记 —— 判定不明，绝不当成 0（rules/test-discipline.md）
}

head1 "QEMU/KVM"

command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 缺失"
[[ -r /dev/kvm && -w /dev/kvm ]] || die "/dev/kvm 不可读写 —— 不降级到软件模拟，那会慢到不可用"
command -v busybox >/dev/null || die "busybox 缺失（apt install busybox-static）"
command -v cpio >/dev/null || die "cpio 缺失"

KERNEL="$(find_kernel)" || {
  bad "找不到可读的内核镜像"
  howto "Ubuntu 的 /boot/vmlinuz-* 默认 0600，QEMU 读不了。两条路：" \
        "SINGLEFS_KERNEL=/path/to/bzImage bash .claude/scripts/qemu.sh" \
        "或 sudo chmod +r /boot/vmlinuz-\$(uname -r)"
  exit 1
}
ok "内核 $KERNEL"
ok "$(qemu-system-x86_64 --version | head -1)"

if [[ $SELFTEST -eq 1 ]]; then
  say ""
  say "  harness 自检：先跑一个必然成功的 payload，再跑一个必然失败的。"
  say "  两者都要被如实分辨——认不出失败的那个，说明这个 harness 会把失败当成成功。"
  say ""
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/singlefs-selftest.XXXXXX")"
  printf '#!/bin/sh\nexit 0\n' > "$tmp/ok.sh";   chmod +x "$tmp/ok.sh"
  printf '#!/bin/sh\nexit 7\n' > "$tmp/bad.sh";  chmod +x "$tmp/bad.sh"
  fail=0
  got_ok="$(run_one "$tmp/ok.sh" "$KERNEL")"   || { bad "成功用例：读不到退出标记"; fail=1; got_ok=NA; }
  got_bad="$(run_one "$tmp/bad.sh" "$KERNEL")" || { bad "失败用例：读不到退出标记"; fail=1; got_bad=NA; }
  [[ "$got_ok" == 0 ]] && ok "成功用例 → 退出码 0" || { bad "成功用例 → $got_ok，期望 0"; fail=1; }
  [[ "$got_bad" == 7 ]] && ok "失败用例 → 退出码 7（harness 认得出失败）" \
                        || { bad "失败用例 → $got_bad，期望 7 —— harness 会把失败当成成功"; fail=1; }
  rm -rf "$tmp"
  say ""
  [[ $fail -eq 0 ]] || { bad "harness 自检未通过"; exit 1; }
  ok "harness 自检通过：退出码能如实传回宿主"
  exit 0
fi

if [[ -z "$PAYLOAD" ]]; then
  say ""
  warn "没有指定 payload —— 本项目还没有可压测的负载"
  say ""
  say "  harness 已就绪（跑 --selftest 验证），缺的是被测对象。接上真实负载需要："
  say "    1. 磁盘格式第一版        —— kb/decisions.md 中 D4 / D8 待定"
  say "    2. mkfs + checker        —— checker 是 kb/invariants.md 的可执行形式"
  say "    3. 被测系统的提交路径     —— 先跑通提交，再谈功能"
  say "    4. 块层写记录            —— dm-log-writes，用于崩溃点重放"
  say ""
  bad "无负载可跑，按未完成处理"
  howto "只想确认 harness 本身没坏，跑： bash .claude/scripts/qemu.sh --selftest" \
        "要接真实负载，先推进上面列的四项依赖。"
  exit 1
fi

[[ -x "$PAYLOAD" ]] || die "payload 不可执行：$PAYLOAD"
rc="$(run_one "$PAYLOAD" "$KERNEL")" || { bad "读不到退出标记，判定不明，整轮作废"; tail -20 "$QEMU_LOG" | sed 's/^/        /'; exit 1; }
if [[ "$rc" == 0 ]]; then ok "payload 退出码 0"; else bad "payload 退出码 $rc"; tail -20 "$QEMU_LOG" | sed 's/^/        /'; exit 1; fi
