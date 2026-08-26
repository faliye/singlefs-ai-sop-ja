#!/usr/bin/env bash
# 文档铁律的自动检查。rules/doc-discipline.md靠这个脚本强制，不靠自觉。
#
# 检查三条：
#   A. 正文（「## 历史版本」之前的部分）不许出现历史陈述与就地废弃标注
#   B. CLAUDE.md 不许有「## 历史版本」节（历史外置）
#   C. kb/*.md 必须有「## 历史版本」节收尾
#   D. kb/*.md 正文不许出现上下文指代（检索会把单条端出来，指代当场断掉）
#   E. kb/*.md 里引用的不变量编号（I-<类>.<号>）必须真的被某张表定义过
#
# 围栏代码块内的内容不检查（那是示例）。
# 定义规则本身的文件加 <!-- doc-lint:rule-definition --> 跳过，并会显式报告为已跳过。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
[[ -d "$ROOT" ]] || die "找不到项目根：$ROOT"

# 违规模式：正则 → 为什么违规
PATTERNS=(
  '~~[^~]'                    '正文不许用删除线标注废弃，直接删掉并写进「历史版本」'
  '[〔【\[]已废弃[〕】\]]'      '正文不许就地标注已废弃'
  '已废弃'                     '正文不许出现"已废弃"，删掉旧内容并写进「历史版本」'
  '原为'                       '正文不许写"原为 X"，直接改成现行值'
  '原先'                       '正文不许写历史陈述'
  '以前[是叫为]'                '正文不许写历史陈述'
  '之前[是叫为]'                '正文不许写历史陈述'
  '曾经'                       '"曾经"只能出现在「历史版本」节内'
  '已被.\{0,12\}覆盖'           '正文不许就地标注被覆盖，删掉并写进「历史版本」'
)

fails=0; skipped=0; checked=0

# 输出正文部分（截到「## 历史版本」之前），并剔除围栏代码块
body_of() {
  awk '
    /^## 历史版本[[:space:]]*$/ { exit }
    /^```/ { infence = !infence; next }
    { if (!infence) print NR "\t" $0; else print NR "\t" }
  ' "$1"
}

head1 "文档铁律检查"

while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  # 标记必须独占一行且在文件头 5 行内——否则正文里"提到"这个字符串会被误判为跳过
  if head -5 "$f" | grep -qx '<!-- doc-lint:rule-definition -->'; then
    [[ -n "${DOC_LINT_VERBOSE:-}" ]] && warn "跳过 $rel（规则定义文件）"
    skipped=$((skipped+1)); continue
  fi
  checked=$((checked+1))
  body="$(body_of "$f")"
  filefail=0

  i=0
  while [[ $i -lt ${#PATTERNS[@]} ]]; do
    pat="${PATTERNS[$i]}"; why="${PATTERNS[$((i+1))]}"
    if hits="$(printf '%s\n' "$body" | grep -n "$pat" || true)"; [[ -n "$hits" ]]; then
      while IFS= read -r h; do
        ln="$(printf '%s' "$h" | sed 's/^[0-9]*://; s/\t.*//')"
        txt="$(printf '%s' "$h" | sed 's/^[0-9]*://; s/^[0-9]*\t//')"
        bad "$rel:$ln  $why"
        say "        > $(printf '%s' "$txt" | cut -c1-80)"
        howto "删掉正文里这句，改写成现行值；确实要留档的，挪到文末「## 历史版本」，" \
              "写成「曾经 X / 现在 Y / 改动依据 Z」。"
        filefail=1
      done <<< "$hits"
    fi
    i=$((i+2))
  done

  # kb 是被检索的，不是被通读的：一条事实被单独取出时必须仍然成立
  if [[ "$f" == */kb/*.md ]]; then
    if refs="$(printf '%s\n' "$body" | grep -nE '如上所述|如前所述|同上|见上文|见上面|前面提到|上一节|前述|下面会说|后面会说' || true)"; [[ -n "$refs" ]]; then
      while IFS= read -r r; do
        rln="$(printf '%s' "$r" | sed 's/^[0-9]*://; s/\t.*//')"
        rtx="$(printf '%s' "$r" | sed 's/^[0-9]*://; s/^[0-9]*\t//')"
        bad "$rel:$rln  kb 正文不许用上下文指代"
        say "        > $(printf '%s' "$rtx" | cut -c1-80)"
        howto "把被指代的内容直接写出来，或链到那条事实所在的文件。" \
              "检索会把这一条单独端出来，指代当场断掉——而模型不会说看不懂，它会补一个。"
        filefail=1
      done <<< "$refs"
    fi
  fi

  base="$(basename "$f")"
  has_hist=0; grep -q '^## 历史版本[[:space:]]*$' "$f" && has_hist=1

  if [[ "$base" == "CLAUDE.md" && $has_hist -eq 1 ]]; then
    bad "$rel  CLAUDE.md 不许有「## 历史版本」节，历史外置到 kb/ 或 CHANGELOG.md"
    howto "把这一节整段挪到 CHANGELOG.md 或 kb/。CLAUDE.md 每次开工都要通读，" \
          "混进历史会稀释它（rules/doc-discipline.md）。"
    filefail=1
  fi
  if [[ "$f" == */kb/*.md && "$base" != "INDEX.md" && $has_hist -eq 0 ]]; then
    bad "$rel  kb 文档必须有「## 历史版本」节收尾"
    howto "在文末补上（没有历史也要留这个节，供以后写）：" \
          "## 历史版本" "" "### $(date +%F)" "- 建档。"
    filefail=1
  fi

  if [[ $filefail -eq 0 ]]; then
    [[ -n "${DOC_LINT_VERBOSE:-}" ]] && ok "$rel"
  else
    fails=$((fails+1))
  fi
done < <(find "$ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/target/*' | sort)

# E. 引用了不存在的编号 —— 空白比错误更危险（rules/kb-discipline.md 第 3 条）
#    典型形态：「历史版本」写了「补 I-4.4~I-4.7」，正文其实没补，别处还在引用它们。
#    人通读能察觉，检索不会——它只会把那条引用端出来，模型照单全收。
reffails=0
kb_files="$(find "$ROOT" -path '*/kb/*.md' -not -path '*/.git/*' | sort)"
if [[ -n "$kb_files" ]]; then
  # 定义 = 表格行首的编号；引用 = 别的任何位置出现的编号。围栏代码块不算。
  defined="$(printf '%s\n' "$kb_files" | while IFS= read -r f; do
      awk '/^```/ { infence = !infence; next } !infence' "$f"
    done | grep -oE '^\| *I-[0-9]+\.[0-9]+ *\|' | grep -oE 'I-[0-9]+\.[0-9]+' | sort -u)"

  while IFS= read -r f; do
    rel="${f#"$ROOT"/}"
    refs="$(awk '/^```/ { infence = !infence; next } !infence { print FNR "\t" $0 }' "$f" \
            | grep -vE '\t\| *I-[0-9]+\.[0-9]+ *\|' || true)"
    [[ -z "$refs" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ln="${line%%$'\t'*}"
      for id in $(printf '%s' "$line" | grep -oE 'I-[0-9]+\.[0-9]+' | sort -u); do
        if ! printf '%s\n' "$defined" | grep -qx "$id"; then
          bad "$rel:$ln  引用了没有定义的不变量编号 $id"
          howto "要么在 kb/invariants.md 里把 $id 真的写成一行（可判定的陈述 + checker 状态），" \
                "要么删掉这处引用。引用一个不存在的编号，检索出来看不出它不存在——" \
                "而模型不会说找不到，它会补一个（rules/kb-discipline.md 第 3 条）。"
          reffails=$((reffails+1))
        fi
      done
    done <<< "$refs"
  done <<< "$kb_files"
fi

say ""
if [[ $fails -gt 0 || $reffails -gt 0 ]]; then
  bad "文档铁律检查失败：$fails 个文件违规、$reffails 处编号引用无定义（检查 $checked，跳过 $skipped）"
  exit 1
fi
ok "文档铁律检查通过（检查 $checked，跳过 $skipped；DOC_LINT_VERBOSE=1 看全部）"
