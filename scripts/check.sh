#!/usr/bin/env bash
# 快速本地检查：格式 / lint / 构建 / 单测。
# 这是快速反馈，**不是准入标准**。准入标准见 gate.sh。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
cd "$ROOT"

command -v cargo >/dev/null 2>&1 || die "cargo 缺失。装 Rust：curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
[[ -f Cargo.toml ]] || die "$ROOT 下没有 Cargo.toml"

head1 "cargo fmt --check"
cargo fmt --all -- --check || die "格式不合规，跑 cargo fmt --all"
ok "格式通过"

head1 "cargo clippy"
cargo clippy --all-targets --all-features -- -D warnings || die "clippy 有告警（按 -D warnings 视为错误）"
ok "clippy 通过"

head1 "cargo build"
cargo build --all-targets || die "构建失败"
ok "构建通过"

head1 "cargo test"
cargo test --all || die "单测失败"
ok "单测通过"
