#!/usr/bin/env bash
# 一次升所有语言的 VERSION —— 版本一致不靠自觉，靠没有别的路可走。
#
#   bump.sh <新版本>            升 I18N 里声明的全部语言
#   bump.sh <新版本> --root D   译本仓不在兄弟目录时指定
#
# 为什么不让人手改 VERSION：三个仓各改一次，漏一个就是三份规则版本不一。
# 而版本不一时，项目侧只会看到自己那一份，看不出别人已经变了。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CF="$PKG/I18N"

NEW="${1:-}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { bad "用法: bump.sh <x.y.z>"
  howto "版本号必须是三段数字，例： bash scripts/bump.sh 1.1.0"; exit 1; }
ROOT="${3:-$(dirname "$PKG")}"
[[ -f "$CF" ]] || die "缺 I18N"
FAMILY="$(sed -n 's/^family=//p' "$CF")"
LANGS="$(sed -n 's/^languages=//p' "$CF")"
OLD="$(cat "$PKG/VERSION" 2>/dev/null || echo '?')"

head1 "升版本 $OLD → $NEW"
# 先全部检查存在，再动手——避免升到一半
for lang in $LANGS; do
  d="$ROOT/$FAMILY-$lang"
  [[ -d "$d" ]] || { bad "$lang  找不到 $d"
    howto "所有声明的语言仓都要在场才能升版本，否则会升出不一致的三份。" \
          "先把缺的仓 clone 下来，或用 --root 指定它们所在的目录。"; exit 1; }
done
for lang in $LANGS; do
  d="$ROOT/$FAMILY-$lang"
  printf '%s\n' "$NEW" > "$d/VERSION"
  [[ "$(cat "$d/VERSION")" == "$NEW" ]] || die "$lang 回读不一致"
  ok "$FAMILY-$lang  → $NEW"
done
bash "$PKG/scripts/manifest.sh" --update >/dev/null
ok "清单已重新生成"
say ""
warn "记得：改了规则就要重译，只升版本不重译等于把过期译本标成最新。"
