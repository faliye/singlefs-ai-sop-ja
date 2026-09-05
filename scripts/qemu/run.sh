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
#   3b. 工作目录与日志路径由**调用方**持有：run_one 在 `$(...)` 里跑，
#      它内部的赋值传不回父进程（rules/command-safety.md）。
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

# 在虚机里跑一个 payload，回显它的退出码。
#
# ⚠️ **工作目录由调用方建好传进来，不在函数里建。**
# run_one 每次都在 `$(...)` 里调，而子 shell 里的赋值传不回父进程
# （rules/command-safety.md）。以前日志路径靠函数内赋一个全局变量往外带，
# 父进程拿到的是**未定义**——set -u 下每一处失败分支都在打印诊断之前就被带走，
# 五处 howto 一句都没能打出来（本轮审计实测）。要传值就落文件/靠参数，不靠变量。
run_one() { # run_one <payload> <kernel> <工作目录>
  local payload="$1" kernel="$2" work="$3"
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
  [[ -n "$rc" ]] && { printf '%s' "$rc"; return 0; }
  return 1   # 读不到标记 —— 判定不明，绝不当成 0（rules/test-discipline.md）
}

head1 "QEMU/KVM"

command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 缺失" \
  "sudo apt install qemu-system-x86   （或跑 bash scripts/fetch-deps.sh --check 看全貌）"
[[ -r /dev/kvm && -w /dev/kvm ]] || die "/dev/kvm 不可读写 —— 不降级到软件模拟，那会慢到不可用" \
  "确认 BIOS 里开了虚拟化，并把自己加进 kvm 组：" \
  "sudo usermod -aG kvm \$USER   （重新登录后生效）"
command -v busybox >/dev/null || die "busybox 缺失" \
  "sudo apt install busybox-static   （initramfs 里的 /bin 全靠它）"
command -v cpio >/dev/null || die "cpio 缺失" \
  "sudo apt install cpio   （用来打 initramfs）"

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
  # 两个工作目录在父进程里建，日志路径父进程自己知道——不靠函数往外带变量
  work_ok="$tmp/run-ok"; work_bad="$tmp/run-bad"; mkdir -p "$work_ok" "$work_bad"
  log_ok="$work_ok/console.log"; log_bad="$work_bad/console.log"
  fail=0
  got_ok="$(run_one "$tmp/ok.sh" "$KERNEL" "$work_ok")"   || { bad "成功用例：读不到退出标记"
    howto "看串口日志找原因： tail -50 $log_ok（常见：内核路径不对、/dev/kvm 不可用）"
    fail=$((fail+1)); got_ok=NA; }
  got_bad="$(run_one "$tmp/bad.sh" "$KERNEL" "$work_bad")" || { bad "失败用例：读不到退出标记"
    howto "看串口日志找原因： tail -50 $log_bad（常见：内核路径不对、/dev/kvm 不可用）"
    fail=$((fail+1)); got_bad=NA; }
  [[ "$got_ok" == 0 ]] && ok "成功用例 → 退出码 0" || { bad "成功用例 → $got_ok，期望 0"
    howto "退出码没如实传回宿主。看 $log_ok 尾部，多半是 init 脚本或串口配置的问题。"
    fail=$((fail+1)); }
  [[ "$got_bad" == 7 ]] && ok "失败用例 → 退出码 7（harness 认得出失败）" \
                        || { bad "失败用例 → $got_bad，期望 7 —— harness 会把失败当成成功"
    howto "这个 harness 现在不可信，先别拿它跑任何压测。看 $log_bad 排查退出码传递，" \
          "修好后重跑 --selftest，两个用例都如实分辨了才算好。"
    fail=$((fail+1)); }
  # 失败时保留日志：诊断信息比磁盘空间值钱，上面的 howto 正指着这两个文件
  [[ $fail -eq 0 ]] && rm -rf "$tmp" || warn "日志留在 $tmp"
  say ""
  [[ $fail -eq 0 ]] || { bad "harness 自检未通过：$fail 项"; exit 1; }   # gate-lint:summary
  ok "harness 自检通过：退出码能如实传回宿主"
  exit 0
fi

if [[ -z "$PAYLOAD" ]]; then
  say ""
  warn "没有指定 payload —— 本项目还没有可压测的负载"
  say ""
  say "  harness 已就绪（跑 --selftest 验证），缺的是被测对象。接上真实负载需要："
  say "    1. 磁盘格式第一版        —— 看项目 kb/decisions.md 里盘上格式那几条的状态"
  say "    2. mkfs + checker        —— checker 是 kb/invariants.md 的可执行形式"
  say "    3. 被测系统的提交路径     —— 先跑通提交，再谈功能"
  say "    4. 块层写记录            —— dm-log-writes，用于崩溃点重放"
  say ""
  bad "无负载可跑，按未完成处理"
  howto "只想确认 harness 本身没坏，跑： bash .claude/scripts/qemu.sh --selftest" \
        "要接真实负载，先推进上面列的四项依赖。"
  exit 1
fi

[[ -x "$PAYLOAD" ]] || die "payload 不可执行：$PAYLOAD" \
  "chmod +x \"$PAYLOAD\"，并确认它第一行有 #!/bin/sh——虚机里只有 busybox sh。"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/singlefs-qemu.XXXXXX")"
LOGF="$WORK/console.log"
rc="$(run_one "$PAYLOAD" "$KERNEL" "$WORK")" || { bad "读不到退出标记，判定不明，整轮作废"
  tail -20 "$LOGF" 2>/dev/null | sed 's/^/        /' || true
  howto "上面是串口日志尾部（完整日志 $LOGF）。判定不明不能当成失败也不能当成成功，" \
        "先跑 --selftest 确认 harness 本身没坏，再重跑这轮。"; exit 1; }
if [[ "$rc" == 0 ]]; then ok "payload 退出码 0"; rm -rf "$WORK"; else
  bad "payload 退出码 $rc"
  tail -20 "$LOGF" 2>/dev/null | sed 's/^/        /' || true
  howto "payload 在虚机里失败了。上面是串口日志尾部（完整日志 $LOGF），" \
        "按 payload 自己的输出排查。"
  exit 1
fi
