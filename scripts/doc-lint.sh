#!/usr/bin/env bash
# 文档铁律的自动检查。rules/doc-discipline.md靠这个脚本强制，不靠自觉。
#
# 检查八条：
#   A. 正文（「## 历史版本」之前的部分）不许出现历史陈述与就地废弃标注
#   B. CLAUDE.md 不许有「## 历史版本」节（历史外置）
#   C. kb/*.md 必须有「## 历史版本」节收尾
#   D. kb/*.md 正文不许出现上下文指代与自指称呼（检索把单条端出来时，
#      「上文」和「此处」一起断掉；rules/kb-discipline.md 第 1 条）
#   E. kb/*.md 里引用的不变量编号（I-<类>.<号>）必须真的被某张表定义过
#   F. kb/*.md 里一个编号只许有一处登记位（rules/kb-discipline.md 第 5 条）
#   G. kb/*.md 里编号的每一处引用都要带上简称，且与登记位一致（同上）
#   H. kb/*.md 里编号形状的记号反复出现（≥3 次）却一处登记位都没有（同上）
#
# 门禁自己的样本（$ROOT/scripts/fixtures/）不扫：那些文件是**故意写坏的**，
# 排除写成相对本次 ROOT 的路径——selftest 把某个样本目录当 ROOT 跑时，这个前缀不匹配，
# 样本照查（写成 */fixtures/* 的话样本永远被跳过，自检就成了摆设）。
# 由 scripts/selftest.sh 拿去证明检查会红，不是项目内容。
# 装进项目的 SOP 副本（*/singlefs-ai-sop/*）不扫：它由上游自己的门禁管，
# 在项目侧再扫一遍，只会让它的模板与项目 kb 的编号互相撞成假红。
# 围栏代码块内的内容不检查（那是示例）。
# 定义规则本身的文件加 <!-- doc-lint:rule-definition --> 跳过，并会显式报告为已跳过。

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-$(project_root)}"
[[ -d "$ROOT" ]] || die "找不到项目根：$ROOT"

tmpd="$(mktemp -d)"; trap 'rm -rf "$tmpd"' EXIT

# 不扫哪些：
#   $ROOT/scripts/fixtures/  —— 门禁自己的样本，故意写坏的，由 selftest.sh 拿去用
#   */singlefs-ai-sop/*      —— 装进项目的 SOP 副本，由上游自己的门禁管
# 两条都写成「相对本次 ROOT」的形态。写死成 */…/* 的话，selftest 把样本目录当 ROOT 跑时
# 路径照样匹配，样本被跳过、全绿——自检就成了摆设（装进项目后实测踩到）。
EXCL=(-not -path "$ROOT/scripts/fixtures/*")
case "$ROOT" in
  */singlefs-ai-sop|*/singlefs-ai-sop/*) ;;   # 就在包里（或包内样本里）跑，不排除自己
  *) EXCL+=(-not -path '*/singlefs-ai-sop/*') ;;
esac

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
    /^[ \t]*```/ { infence = !infence; next }
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
  #   D-1 上下文指代：指着「上文」，而检索结果里没有上文
  #   D-2 自指称呼：指着「此处」，而检索把这一条从文件里摘下来时，「此处」也没了——
  #       那个 `## D22 单元原子性怎么合成` 的标题不会跟着走。
  #       尾字排除是实测出来的：kb 里真有「该节点」，不排除就是假红。
  #       「本工程」「本仓」「本轮」「本机」不在其内——它们指的是项目，不是文档位置。
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
    self='[本该](决策|实验([^室]|$)|不变量|章节|表)|[本该]条([^件目]|$)|[本该]节([^点]|$)|[本该]文件([^夹]|$)|[本该]文档|这(条|个)(决策|实验|不变量)'
    if selfs="$(printf '%s\n' "$body" | grep -nE "$self" || true)"; [[ -n "$selfs" ]]; then
      while IFS= read -r r; do
        rln="$(printf '%s' "$r" | sed 's/^[0-9]*://; s/\t.*//')"
        rtx="$(printf '%s' "$r" | sed 's/^[0-9]*://; s/^[0-9]*\t//')"
        bad "$rel:$rln  kb 正文不许用自指称呼"
        say "        > $(printf '%s' "$rtx" | cut -c1-80)"
        howto "把当前位置写成名字：条目写成「D22（单元原子性怎么合成）」，" \
              "章节写成它的标题，文档写成它的文件名。" \
              "检索端出来的那一条没有「此处」——它已经被从文件里摘下来了。"
        filefail=1
      done <<< "$selfs"
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
done < <(find "$ROOT" -name '*.md' -not -path '*/.git/*' -not -path '*/target/*' \
                 "${EXCL[@]}" | sort)

# E. 引用了不存在的编号 —— 空白比错误更危险（rules/kb-discipline.md 第 3 条）
#    典型形态：「历史版本」写了「补 I-4.4~I-4.7」，正文其实没补，别处还在引用它们。
#    人通读能察觉，检索不会——它只会把那条引用端出来，模型照单全收。
reffails=0
kb_files="$(find "$ROOT" -path '*/kb/*.md' -not -path '*/.git/*' \
                    "${EXCL[@]}" | sort)"
if [[ -n "$kb_files" ]]; then
  # 定义 = 表格行首的编号；引用 = 别的任何位置出现的编号。围栏代码块不算。
  defined="$(printf '%s\n' "$kb_files" | while IFS= read -r f; do
      awk '/^[ \t]*```/ { infence = !infence; next } !infence' "$f"
    done | grep -oE '^\| *I-[0-9]+(\.[0-9]+)+ *\|' | grep -oE 'I-[0-9]+(\.[0-9]+)+' | sort -u || true)"

  while IFS= read -r f; do
    rel="${f#"$ROOT"/}"
    refs="$(awk '/^[ \t]*```/ { infence = !infence; next } !infence { print FNR "\t" $0 }' "$f" \
            | grep -vE '\t\| *I-[0-9]+(\.[0-9]+)+ *\|' || true)"
    [[ -z "$refs" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      ln="${line%%$'\t'*}"
      for id in $(printf '%s' "$line" | grep -oE 'I-[0-9]+(\.[0-9]+)+' | sort -u); do
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

# F/G/H. 编号只能做索引，不能做称呼（rules/kb-discipline.md 第 5 条）
#   登记位有且只有两种：
#     1. 登记表：表格上方单独一行 <!-- doc-lint:registry name-col=N -->，
#        该表每行首列的编号即登记位，简称取第 N 列（N 默认 2，必须 ≥2）
#     2. 登记标题：`## D1 数据可移动性 —— 已定`，简称取编号之后、破折号之前那一段
#   不从「表格首列是编号」去猜——实测过，首列同样被用来当行标签
#   （`| D2 | 节点内 parity 与 D2 的… |`、`| I-6.1 | 补注：… |`），猜的话这些全是假红。
#   标题也要带破折号才算登记，否则「### D1 与 parity 的关系」这种讨论标题会被当成
#   第二处登记位，还把简称顶掉，让所有本来正确的引用一起红。
#   其余每一次出现都算引用，必须写成 `D1（数据可移动性）`。
#   F 查登记位（唯一、简称非空不超长、不重名、登记表本身没写坏），
#   G 查引用带简称且与登记位一致，H 查「反复出现却一处登记都没有」。
NAME_MAX=48     # 简称的显示宽度上限（汉字算 2、ASCII 算 1，即 24 个汉字）。
                # 带不动的名字等于没名字，逼登记处起个短的。一个字符数管三种语言不行：
                # 24 个汉字与 24 个 ASCII 字符的信息量差三倍。
ID_MIN=3        # H：出现几次才算「在当称呼用」。一两次算顺带提及。
numfails=0
if [[ -n "$kb_files" ]]; then
  mapfile -t kb_arr <<< "$kb_files"
  rawf="$tmpd/defs.raw"; defsf="$tmpd/defs.tsv"
  : > "$rawf"
  while IFS= read -r f; do
    awk -v FN="${f#"$ROOT"/}" '
      BEGIN { ID = "[A-Z]+-?[0-9]+([.][0-9]+)*" }
      /^[ \t]*```/ { fence = !fence; next }
      fence  { next }
      /<!-- *doc-lint:registry/ {
        reg = 1; intable = 0; ncol = 2; marker = FNR
        if (match($0, /name-col=[0-9]+/)) ncol = substr($0, RSTART + 9, RLENGTH - 9) + 0
        if (ncol < 2) printf "ERR\037%s\037%d\037name-col=%d 会把简称取成编号自己\n", FN, FNR, ncol
        next }
      reg && /^[ \t]*$/ { next }              # 标记与表头之间允许空行
      reg && !/^\|/ {
        # 标记没管住任何一张表：再往下就会捕获后面某张不相干的表，并按 name-col 错取简称。
        if (!intable) printf "ERR\037%s\037%d\037登记标记后面第一处非空内容不是表格\n", FN, marker
        reg = 0; intable = 0 }
      reg && /^\|/ {
        intable = 1
        n = split($0, c, "|")
        id = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", id)
        if (id ~ "^" ID "$") {
          if (n <= ncol) {
            # 静默跳过等于「登记表里写着却没登记上」，最后由 H 报成「没有任何登记位」——
            # 指着错的方向。这里直接报出来。
            printf "ERR\037%s\037%d\037这一行取不到第 %d 列（简称列），登记不上\n", FN, FNR, ncol
          } else {
            nm = c[ncol + 1]; gsub(/^[ \t]+|[ \t]+$/, "", nm)
            printf "DEF\037%s\037%s\037%s\037%d\n", id, nm, FN, FNR }
        }
        next }
      # 登记标题的形态是「编号 简称 —— 状态」。少了分隔符就不算登记位——
      # 否则「### D1 与 parity 的关系」这种讨论标题会被当成第二处登记位，
      # 还把简称顶掉，让所有本来正确的引用一起红。
      match($0, "^#+[ ]*" ID "[ \t].*(——|—)") {
        h = $0; sub(/^#+[ ]*/, "", h)
        match(h, "^" ID); id = substr(h, 1, RLENGTH)
        nm = substr(h, RLENGTH + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", nm); sub(/ *(——|—).*$/, "", nm)
        printf "DEF\037%s\037%s\037%s\037%d\n", id, nm, FN, FNR }
      END { if (reg && !intable) printf "ERR\037%s\037%d\037登记标记后面没有表格\n", FN, marker }
    ' "$f" >> "$rawf"
  done <<< "$kb_files"
  grep '^DEF' "$rawf" | cut -d$'\037' -f2- > "$defsf" || true

  # F. 登记表本身写坏了——这些以前是静默降级，最后由 H 报成「没有任何登记位」，指错方向
  while IFS=$'\037' read -r _tag df dl why; do
    [[ -z "$df" ]] && continue
    bad "$df:$dl  登记表写坏了：$why"
    howto "登记标记要紧挨着它管的那张表（中间只许空行），表里每一行都要能取到简称列，" \
          "且 name-col 必须 ≥2——取第 1 列等于把编号自己当简称，F 与 G 当场失效。"
    numfails=$((numfails+1))
  done < <(grep '^ERR' "$rawf" || true)

  # F. 一个编号只许有一处登记位
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    bad "编号 $id 有多处登记位——一个编号只许有一处登记"
    awk -F'\037' -v i="$id" '$1==i {printf "        %s:%s  简称「%s」\n", $3, $4, $2}' "$defsf"
    howto "留一处当登记位，别处改成引用：写成「$id（简称）」并链过去。" \
          "两处登记会各自漂移，而检索只端出一条、并且不告诉你它挑了哪条。"
    numfails=$((numfails+1))
  done < <(cut -d$'\037' -f1 "$defsf" | sort | uniq -d)

  # F. 两个编号共用一个简称 —— 带上名字也分不开，等于没带
  while IFS= read -r nm; do
    [[ -z "$nm" ]] && continue
    ids="$(awk -F'\037' -v n="$nm" '$2==n {printf "%s ", $1}' "$defsf")"
    bad "简称「$nm」被多个编号共用：$ids"
    howto "各起各的名。共用简称时「带上名字」这条就白做了——两处引用长得一模一样。"
    numfails=$((numfails+1))
  done < <(cut -d$'\037' -f2 "$defsf" | sort | uniq -d)

  # F. 简称要能被带着走：不许为空，不许长到没人愿意在引用处写
  while IFS=$'\037' read -r id nm df dl; do
    [[ -z "$id" ]] && continue
    nb="$(printf '%s' "$nm" | wc -c)"
    na="$(printf '%s' "$nm" | tr -d '\200-\377' | wc -c)"
    nlen=$(( na + (nb - na) / 3 * 2 ))      # 按字节算显示宽度，不随 locale 与 awk 实现变
    if [[ -z "$nm" ]]; then
      bad "$df:$dl  编号 $id 的登记位没有简称"
      howto "在登记表的简称列（或标题里编号之后）写一个短名，例：「## $id 反向索引 —— 已定」。" \
            "没有简称的编号在引用处只剩一个符号，含义可以被悄悄改掉。"
      numfails=$((numfails+1))
    elif [[ "$nm" == "$id" ]]; then
      bad "$df:$dl  编号 $id 的简称就是它自己"
      howto "简称要说清这个编号是什么，写成编号自己等于没写（多半是 name-col 指错了列）。"
      numfails=$((numfails+1))
    elif [[ "$nlen" -gt "$NAME_MAX" ]]; then
      bad "$df:$dl  编号 $id 的简称显示宽度 $nlen，超过 $NAME_MAX（汉字算 2、ASCII 算 1）"
      howto "起一个更短的简称——引用处每次都要带着它，带不动的名字等于没名字。" \
            "完整陈述留在登记位的其它列里，别塞进简称列。"
      numfails=$((numfails+1))
    fi
  done < "$defsf"

  # H. 反过来：编号形状的记号反复出现，却一处登记位都没有——那是拿编号当称呼在用。
  #    少了这一条，一个从没登记过的 kb 会全绿：登记位为空 ⇒ F、G 都无事可做，
  #    而实测出事的那个 kb 正是一处登记都没有的。
  #    领域术语（RAID5、SHA256、Z3）形状上与编号分不开，靠显式声明摘出去，不靠猜。
  exemptf="$tmpd/exempt.txt"
  cut -d$'\037' -f1 "$defsf" | sort -u > "$exemptf"
  grep -hoE '<!-- *doc-lint:not-numbers[^>]*-->' "${kb_arr[@]}" 2>/dev/null \
    | sed -E 's/<!-- *doc-lint:not-numbers//; s/-->//' | tr -s ' \t' '\n' \
    | grep -v '^$' >> "$exemptf" || true
  while IFS=$'\037' read -r tok cnt; do
    [[ -z "$tok" ]] && continue
    bad "编号 $tok 出现 $cnt 次，却没有任何登记位"
    howto "在登记表（表上方加 <!-- doc-lint:registry name-col=2 -->）或标题里登记它并给个简称，" \
          "然后每处引用写成「$tok（简称）」。它若根本不是编号而是领域术语，" \
          "在任一 kb 文件里声明摘出去：<!-- doc-lint:not-numbers $tok -->"
    numfails=$((numfails+1))
  done < <(awk -v MIN="$ID_MIN" -v EXEMPT="$exemptf" '
      BEGIN { ID = "[A-Z]+-?[0-9]+([.][0-9]+)*"
              while ((getline l < EXEMPT) > 0) exempt[l] = 1
              close(EXEMPT) }
      /^[ \t]*```/ { fence = !fence; next }
      fence  { next }
      {
        line = $0
        while (match(line, ID)) {
          tok = substr(line, RSTART, RLENGTH)
          before = (RSTART > 1) ? substr(line, RSTART - 1, 1) : ""
          line = substr(line, RSTART + RLENGTH)
          if (before ~ /[A-Za-z0-9._-]/) continue
          if (line ~ /^[A-Za-z]/) continue          # SHA256sum 这种，不是编号
          if (!(tok in exempt)) n[tok]++
        }
      }
      END { for (t in n) if (n[t] >= MIN) printf "%s\037%d\n", t, n[t] }
    ' "${kb_arr[@]}" | sort)

  # G. 引用处必须带简称，且与登记位一致
  while IFS= read -r f; do
    rel="${f#"$ROOT"/}"
    hits="$(awk -F'\037' -v FN="$rel" -v DEFS="$defsf" '
      function norm(s) {                       # 去掉强调标记，把连续空白压成一个
        gsub(/[*`]/, "", s); gsub(/[ \t]+/, " ", s)
        gsub(/^ | $/, "", s); return s }
      function matchclose(s,   i, d, ch) {     # 与开头那个括号配对的闭括号位置
        d = 0
        for (i = 1; i <= length(s); i++) {
          ch = substr(s, i, 1)
          if (ch == "（" || ch == "(") d++
          else if (ch == "）" || ch == ")") { d--; if (d == 0) return i }
        }
        return 0 }
      BEGIN { ID = "[A-Z]+-?[0-9]+([.][0-9]+)*"
              while ((getline l < DEFS) > 0) {
                split(l, d, "\037")
                name[d[1]] = norm(d[2]); raw[d[1]] = d[2]
                if (d[3] == FN) defid[d[4]] = d[1] }
              close(DEFS) }
      { L[FNR] = $0 }
      END {
        for (n = 1; n <= FNR; n++) {
          line = L[n]
          if (line ~ /^[ \t]*```/) { fence = !fence; continue }
          if (fence) continue
          # 引用可以被硬折行拆开（`O2（独立解析器\n+ checker）`，或编号在行尾、
          # 括注在下一行）。判定用接上后两行的那一段，报的行号还是编号所在这行。
          seg = line " " L[n + 1] " " L[n + 2]
          skipped = 0
          pos = 1
          while (match(substr(seg, pos), ID)) {
            st = pos + RSTART - 1
            tok = substr(seg, st, RLENGTH)
            if (st > length(line)) break                 # 已经扫进下一行，交给下一轮
            before = (st > 1) ? substr(seg, st - 1, 1) : ""
            after  = substr(seg, st + length(tok), 1)
            nxt    = substr(seg, st + length(tok) + 1, 1)
            pos = st + length(tok)
            if (before ~ /[A-Za-z0-9._-]/) continue
            if (after ~ /[A-Za-z]/) continue
            if (after ~ /[0-9]/) continue
            if (after == "." && nxt ~ /[0-9]/) continue  # I-6 出现在 I-6.1 里面
            if (!(tok in name)) continue
            # 登记行/登记标题：只放过它登记的那个编号本身，同一行里对**别的**编号的
            # 引用照查——那正是实测出事的位置形态（登记表的「判什么」列）。
            if (n in defid) {
              # 登记行/登记标题：放过它登记的那个编号，以及简称里含的编号——
              # 简称本身要求带名字是无限递归。同一行其它位置对别的编号的引用照查，
              # 那正是实测出事的位置形态（登记表的「判什么」列）。
              if (defid[n] == tok && !skipped) { skipped = 1; continue }
              if (index(raw[defid[n]], tok) > 0) continue
            }
            rest = substr(seg, st + length(tok))
            pre = 0
            if (match(rest, /^[*`]+/)) { pre += RLENGTH; rest = substr(rest, RLENGTH + 1) }
            if (match(rest, /^ +[（(]/)) {               # 英文写法 `O2 (name)`
              sub(/^ +/, "", rest); pre += RLENGTH - 1 }
            if (rest ~ /^[（(]/) {
              cl = matchclose(rest)                      # 配对计数：简称本身可以含括号
              if (cl == 0) {
                printf "%d\t括注没闭合\t%s\t%s\n", n, tok, substr(line, 1, 60)
              } else {
                inner = substr(rest, 2, cl - 2)
                if (norm(inner) != name[tok])
                  printf "%d\t名字不符\t%s\t写的是「%s」，登记处是「%s」\n", n, tok, inner, raw[tok]
                # 跳过简称内部：简称里含的是**别的**编号时，不跳就成了新的裸引用，
                # 补上名字又引出下一个——无限递归。
                pos = st + length(tok) + pre + cl
              }
            } else {
              printf "%d\t裸引用\t%s\t%s\n", n, tok, substr(line, 1, 60)
            }
          }
        }
      }
    ' "$f")"
    [[ -z "$hits" ]] && continue
    n="$(printf '%s\n' "$hits" | wc -l)"
    bad "$rel  $n 处编号引用没带简称或简称不符"
    printf '%s\n' "$hits" | head -3 | awk -F'\t' '{printf "        :%s  %s %s —— %s\n", $1, $3, $2, $4}'
    howto "每处引用都写成「编号（简称）」，简称照登记位抄，例：「D1（数据可移动性）」。" \
          "编号在引用处只剩一个符号，含义能被悄悄改掉而没有一个字看起来别扭——" \
          "实测代价见 rules/kb-discipline.md 第 5 条。全量清单：DOC_LINT_VERBOSE=1"
    [[ -n "${DOC_LINT_VERBOSE:-}" ]] && printf '%s\n' "$hits" | awk -F'\t' '{printf "        :%s  %s %s —— %s\n", $1, $3, $2, $4}'
    numfails=$((numfails+1))
  done <<< "$kb_files"
fi

say ""
if [[ $fails -gt 0 || $reffails -gt 0 || $numfails -gt 0 ]]; then
  bad "文档铁律检查失败：$fails 个文件违规、$reffails 处编号引用无定义、$numfails 处编号定义/引用不合规（检查 $checked，跳过 $skipped）"
  exit 1
fi
ok "文档铁律检查通过（检查 $checked，跳过 $skipped；DOC_LINT_VERBOSE=1 看全部）"
