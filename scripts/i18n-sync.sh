#!/usr/bin/env bash
# 各语言文本必须同步：改了任何一份，声明的每种语言都要跟上。
# this 标明本仓是哪种语言；reference 标明参照仓——清单与门禁脚本在那一份里维护，
# 其余语言的仓拿到的是它的原样复制。default 是给使用者的默认版本。
#
#   i18n-sync.sh [各语言仓所在目录]   默认找本仓的兄弟目录
#   i18n-sync.sh --update [目录]      把共享部分原样复制到各语言仓
#
# 检查什么：对 LANGUAGES 里声明的每种语言，
#   1. 那个语言的仓在不在  —— 不在则「无法检查」，按失败处理，不静默放过
#   2. 它抄走的清单是不是当前清单
#   3. 共享部分（install.sh、scripts/、skills/、templates/）与本仓逐字节一致
#   4. 清单里每一篇在那个仓里有没有对应文件
#
# 共享部分为什么要复制而不是只放一份：项目安装时只 clone 自己那一种语言的仓，
# 那个仓里没有门禁脚本就等于装不了。复制是**生成**的，不是手抄的——
# 手抄的重复会分叉，生成的不会（rules/machine-first.md）。
#
# 判据（按 kb-discipline「矛盾比空白更糟」定，但对已声明的语言收紧）：
#   已声明的语言缺文件或落后 —— 都失败。声明了却不跟，等于给人一份过期的规则。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE=0
[[ "${1:-}" == "--update" ]] && { UPDATE=1; shift; }
ROOT="${1:-$(dirname "$PKG")}"
MF="$PKG/MANIFEST.sha256"
CF="$PKG/I18N"

# 原样复制到各语言仓的部分：脚本与骨架不翻译，翻译的只有文本（清单里那几篇）。
SHARED=(install.sh scripts skills templates)

head1 "三语同步"

[[ -f "$CF" ]] || { ok "未声明语言族，本阶段不适用"; exit 0; }
FAMILY="$(sed -n 's/^family=//p' "$CF")"
THIS="$(sed -n 's/^this=//p' "$CF")"
REF="$(sed -n 's/^reference=//p' "$CF")"
LANGS="$(sed -n 's/^languages=//p' "$CF")"
[[ -n "$FAMILY" && -n "$THIS" && -n "$REF" && -n "$LANGS" ]] || {
  bad "I18N 配置不完整"
  howto "五行都要有：family=<族名>  this=<本仓语言>  reference=<参照仓语言>" \
        "default=<默认版本语言>  languages=<空格分隔>"; exit 1; }
if [[ "$THIS" != "$REF" ]]; then
  ok "本仓是 $THIS 版，同步以 $REF 仓为准，本阶段不适用"
  exit 0
fi
[[ -f "$MF" ]] || { bad "缺 MANIFEST.sha256"; howto "跑： bash scripts/manifest.sh --update"; exit 1; }

fails=0
for lang in $LANGS; do
  [[ "$lang" == "$THIS" ]] && continue   # 本仓就是这一种语言，不用跟自己对账
  repo="$ROOT/$FAMILY-$lang"
  if [[ ! -d "$repo" ]]; then
    bad "$lang  找不到译本仓 $repo"
    howto "克隆到本仓的兄弟目录，或指定位置：" \
          "bash scripts/i18n-sync.sh /path/to/repos" \
          "找不到就无法检查——按失败处理，不静默放过（rules/show-me-test.md）。"
    fails=$((fails+1)); continue
  fi
  sm="$repo/SOURCE-MANIFEST.sha256"
  if [[ ! -f "$sm" ]]; then
    bad "$lang  译本仓缺 SOURCE-MANIFEST.sha256"
    howto "更新该语言时把本仓的 MANIFEST.sha256 抄过去存成这个名字。"
    fails=$((fails+1)); continue
  fi
  if ! diff -q "$MF" "$sm" >/dev/null 2>&1; then
    bad "$lang  落后：与清单不一致"
    diff "$MF" "$sm" | grep '^<' | awk '{print $3}' | sed 's/^/        待重译: /' | head -10
    howto "把上面这几篇在该语言仓里改到位，然后把本仓的 MANIFEST.sha256 抄成它的 SOURCE-MANIFEST.sha256。" \
          "别只抄清单不改内容——那样门禁会绿，而用那种语言的人拿到的是旧规则。"
    fails=$((fails+1)); continue
  fi
  # 版本必须完全一致：一个升级三个升级
  tv="$(cat "$repo/VERSION" 2>/dev/null || echo '')"
  bv="$(cat "$PKG/VERSION" 2>/dev/null || echo '')"
  if [[ "$tv" != "$bv" ]]; then
    bad "$lang  版本不一致：$lang ${tv:-无} / 本仓 ${bv:-无}"
    howto "三份必须同版本。用这条命令一次升全部，不要手改单个 VERSION：" \
          "bash scripts/bump.sh <x.y.z>"
    fails=$((fails+1)); continue
  fi

  if [[ $UPDATE -eq 1 ]]; then
    [[ -d "$repo/.git" ]] || { bad "$lang  $repo 不是 git 仓，拒绝往里写"
      howto "共享部分是覆盖式写入，只往 git 仓里写——写错地方无从回退。" \
            "确认路径，或用 bash scripts/i18n-sync.sh --update /path/to/repos 指定。"
      fails=$((fails+1)); continue; }
    for item in "${SHARED[@]}"; do
      rm -rf "${repo:?}/$item"
      cp -a "$PKG/$item" "$repo/$item"
    done
    # I18N 只有 this= 一行按语言不同，其余照抄——各仓分头维护它必然漂
    sed "s/^this=.*/this=$lang/" "$CF" > "$repo/I18N"
    ok "$lang  共享部分已同步（${#SHARED[@]} 项 + I18N）"
  fi

  sdiff=""
  for item in "${SHARED[@]}"; do
    diff -rq "$PKG/$item" "$repo/$item" >/dev/null 2>&1 || sdiff+="$item "
  done
  if [[ -n "$sdiff" ]]; then
    bad "$lang  共享部分与本仓不一致：$sdiff"
    for item in $sdiff; do
      diff -rq "$PKG/$item" "$repo/$item" 2>&1 | sed 's/^/        /' | head -4
    done
    howto "共享部分是原样复制过去的，不翻译。一条命令同步全部语言：" \
          "bash scripts/i18n-sync.sh --update" \
          "手改那边的副本没有意义——下次同步会把它覆盖掉。"
    fails=$((fails+1)); continue
  fi

  miss=0
  while read -r _ path; do
    [[ -f "$repo/$path" ]] || { miss=$((miss+1)); say "        缺: $path"; }
  done < "$MF"
  if [[ $miss -gt 0 ]]; then
    bad "$lang  清单一致但缺 $miss 个文件"
    howto "补齐这几篇译文。声明了这种语言却不给全，等于给人一份残缺的规则。"
    fails=$((fails+1))
  else
    ok "$lang  与清单一致（$(wc -l < "$MF") 篇），共享部分一致"
  fi
done

say ""
[[ $fails -eq 0 ]] || { bad "三语同步失败：$fails 种语言未跟上"; exit 1; }
ok "声明的所有语言都与清单一致"
