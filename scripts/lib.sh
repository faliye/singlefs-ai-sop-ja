#!/usr/bin/env bash
# 公共函数。所有门禁脚本 source 它。
# 约定：任何"验证"函数都必须能返回非零。不许有只会成功的检查。

set -euo pipefail

if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_BLD=''; C_RST=''
fi

say()   { printf '%s\n' "$*"; }
head1() { printf '\n%s══ %s ══%s\n' "$C_BLD" "$*" "$C_RST"; }
ok()    { printf '%s  ✓%s %s\n' "$C_GRN" "$C_RST" "$*"; }
bad()   { printf '%s  ✗%s %s\n' "$C_RED" "$C_RST" "$*"; }
warn()  { printf '%s  !%s %s\n' "$C_YEL" "$C_RST" "$*"; }
die()   { bad "$*"; exit 1; }

# 拒绝一个提交时，必须同时说清下一步做什么。
# 默认提交者是想通过的——拒绝而不给出路，等于让人靠猜，而靠猜的人会去绕过门禁。
# scripts/gate-lint.sh 强制：每个非汇总性的 bad 后面 4 行内必须有 howto。
howto() { printf '%s     → 怎么办：%s %s\n' "$C_YEL" "$C_RST" "$1"; shift
          for l in "$@"; do printf '                %s\n' "$l"; done; }

# 找到项目根：向上找到含 .singlefs-ai-sop-version 或 .git 的目录
project_root() {
  local d="${1:-$PWD}"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/.singlefs-ai-sop-version" || -d "$d/.git" ]] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

# 本包自身的根
pkg_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

# 确定 diff 基准。优先 $GATE_BASE，否则与默认分支的 merge-base，
# 都没有就用 HEAD（即只看工作区改动）。
diff_base() {
  local root="$1"
  if [[ -n "${GATE_BASE:-}" ]]; then printf '%s' "$GATE_BASE"; return 0; fi
  local def
  for def in master main; do
    if git -C "$root" rev-parse --verify -q "$def" >/dev/null; then
      local mb
      if mb="$(git -C "$root" merge-base HEAD "$def" 2>/dev/null)" && [[ -n "$mb" ]]; then
        # 若当前就在默认分支上，merge-base 等于 HEAD，退化为看工作区
        printf '%s' "$mb"; return 0
      fi
    fi
  done
  printf 'HEAD'
}

# 列出相对基准变更的文件（含工作区未提交改动）
changed_files() {
  local root="$1" base="$2"
  # 空仓（还没有任何 commit）时 HEAD 不存在，diff 会失败——只看未跟踪文件
  if ! git -C "$root" rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1; then
    git -C "$root" ls-files --others --exclude-standard | sort -u | grep -v '^$' || true
    return 0
  fi
  { git -C "$root" diff --name-only "$base" -- ;
    git -C "$root" diff --name-only --cached -- ;
    git -C "$root" ls-files --others --exclude-standard ; } | sort -u | grep -v '^$' || true
}

# 变更中新增的行（用于检查是否新增了测试）
added_lines() {
  local root="$1" base="$2"
  git -C "$root" rev-parse --verify -q "$base^{commit}" >/dev/null 2>&1 || { git -C "$root" diff -U0 --cached -- 2>/dev/null | grep '^+' | grep -v '^+++' || true; return 0; }
  { git -C "$root" diff -U0 "$base" -- ;
    git -C "$root" diff -U0 --cached -- ; } 2>/dev/null \
    | grep '^+' | grep -v '^+++' || true
}
