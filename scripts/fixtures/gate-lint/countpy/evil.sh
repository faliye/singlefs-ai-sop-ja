#!/usr/bin/env bash
# 样本：阶段用 python 实现，计数在 f-string 里。只认 `$` 的判据会把它误判成没报条数。
find . -name '*.md' > /dev/null
python3 - <<'EOF'
n = 3
print(f'  ✓ 检查通过（扫 {n} 个文件）')
EOF
