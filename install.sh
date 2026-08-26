#!/usr/bin/env bash
# 把本 SOP 接进一个项目（任一语言版本，目录名统一为 .claude/singlefs-ai-sop）。
#
# 用法（在项目根跑）：
#   git clone <singlefs-ai-sop> .claude/singlefs-ai-sop
#   bash .claude/singlefs-ai-sop/install.sh
#
# 原则：已存在的文件一律不覆盖，只报告；每一步写完都回读验证。
set -euo pipefail
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PKG/scripts/lib.sh"

ROOT="${1:-$PWD}"
[[ -d "$ROOT" ]] || die "目标目录不存在：$ROOT"
ROOT="$(cd "$ROOT" && pwd)"
[[ "$ROOT" != "$PKG" ]] || die "不能装到自己身上"

VER="$(cat "$PKG/VERSION")"
head1 "安装 $(basename "$PKG") $VER → $ROOT"

created=0; skipped=0

put() { # put <目标相对路径> <内容来源:file|stdin>
  local rel="$1" src="${2:-}"
  local dst="$ROOT/$rel"
  if [[ -e "$dst" ]]; then warn "已存在，跳过  $rel"; skipped=$((skipped+1)); return 0; fi
  mkdir -p "$(dirname "$dst")"
  if [[ -n "$src" ]]; then cp "$src" "$dst"; else cat > "$dst"; fi
  [[ -s "$dst" ]] || die "写入后回读为空：$rel"
  ok "创建  $rel"; created=$((created+1))
}

# 1. 项目 CLAUDE.md
put "CLAUDE.md" "$PKG/templates/CLAUDE.project.md"

# 2. kb 骨架
for f in "$PKG"/templates/kb/*.md; do
  [[ -e "$f" ]] || continue
  put ".claude/kb/$(basename "$f")" "$f"
done

# 3. scripts 包装（不写逻辑，只 exec 共享脚本）
for s in env check gate doc-lint lkmm gate-lint; do
  put ".claude/scripts/$s.sh" <<WRAP
#!/usr/bin/env bash
# 包装：转发到共享脚本。逻辑不写在这里，写在 .claude/singlefs-ai-sop/scripts/。
exec bash "\$(dirname "\${BASH_SOURCE[0]}")/../singlefs-ai-sop/scripts/$s.sh" "\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)" "\$@"
WRAP
  chmod +x "$ROOT/.claude/scripts/$s.sh" 2>/dev/null || true
done

# 3b. qemu 包装（在子目录里，单独处理）
put ".claude/scripts/qemu.sh" <<'WRAP'
#!/usr/bin/env bash
# 包装：转发到共享脚本。逻辑不写在这里，写在 .claude/singlefs-ai-sop/scripts/qemu/。
exec bash "$(dirname "${BASH_SOURCE[0]}")/../singlefs-ai-sop/scripts/qemu/run.sh" "$@"
WRAP
chmod +x "$ROOT/.claude/scripts/qemu.sh" 2>/dev/null || true

# 3c. litmus 骨架（内存序声明，项目本地）
for f in "$PKG"/templates/litmus/*.litmus; do
  [[ -e "$f" ]] || continue
  put "litmus/$(basename "$f")" "$f"
done

# 4. skill 桩
for d in "$PKG"/skills/*/; do
  [[ -d "$d" ]] || continue
  n="$(basename "$d")"
  put ".claude/skills/$n/SKILL.md" <<STUB
---
name: $n
description: $(sed -n 's/^description: //p' "$d/SKILL.md" | head -1)
---

正文在共享层，读它：\`.claude/singlefs-ai-sop/skills/$n/SKILL.md\`

**不要把正文抄到这里。** 正文只该有一处，抄一份就多出第二处，两处早晚说不同的话。
STUB
done

# 5. 版本戳（这个总是覆盖——它就是用来跟踪版本的）
printf '%s\n' "$VER" > "$ROOT/.singlefs-ai-sop-version"
[[ "$(cat "$ROOT/.singlefs-ai-sop-version")" == "$VER" ]] || die "版本戳回读不一致"
ok "版本戳  .singlefs-ai-sop-version = $VER"

# 6. gitignore 提醒（不自动改）
if [[ -f "$ROOT/.gitignore" ]] && ! grep -q 'singlefs-ai-sop' "$ROOT/.gitignore"; then
  warn "建议在 .gitignore 或 .gitmodules 里处理 .claude/singlefs-ai-sop/ 的归属"
fi

say ""
ok "完成：新建 $created 个，跳过 $skipped 个（已存在的不覆盖）"
say "下一步： bash .claude/scripts/gate.sh"
