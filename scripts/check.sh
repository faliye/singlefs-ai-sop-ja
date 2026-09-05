#!/usr/bin/env bash
# 快速本地检查：格式 / lint / 构建 / 单测。
# 这是快速反馈，**不是准入标准**。准入标准见 gate.sh。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
cd "$ROOT"

command -v cargo >/dev/null 2>&1 || die "cargo 缺失" \
  "装 Rust 工具链：" \
  "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
[[ -f Cargo.toml ]] || die "$ROOT 下没有 Cargo.toml" \
  "本脚本只做 Rust 项目的快速反馈。确认你在项目根，或先建 workspace 的 Cargo.toml。"

head1 "cargo fmt --check"
cargo fmt --all -- --check || die "格式不合规" \
  "跑 cargo fmt --all 让它自己改完，再重跑本脚本。"
ok "格式通过"

head1 "cargo clippy"
cargo clippy --all-targets --all-features -- -D warnings || die "clippy 有告警（按 -D warnings 视为错误）" \
  "上面每条告警都指着文件和行号，逐条改。" \
  "确有必要保留的，在那一处写 #[allow(...)] 并在同行注释里写明为什么——" \
  "不要整仓关掉 -D warnings（rules/command-safety.md：警告是最便宜的信号）。"
ok "clippy 通过"

head1 "cargo build"
cargo build --all-targets || die "构建失败" \
  "上面是 rustc 的报错，从第一条改起——后面的多半是它的连锁反应。"
ok "构建通过"

head1 "cargo test"
cargo test --all || die "单测失败" \
  "上面列出了失败的用例名。单跑一个看细节：" \
  "cargo test --all <用例名> -- --nocapture" \
  "改代码还是改断言，先想清楚是哪一种——直接改断言等于把测试关掉。"
ok "单测通过"
