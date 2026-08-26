#!/usr/bin/env bash
# 规则清单：给译文仓对账用的唯一接口。
#
#   manifest.sh            校验 MANIFEST.sha256 是否与当前 CLAUDE.md + rules/ 一致（门禁用）
#   manifest.sh --update   重新生成 MANIFEST.sha256（改了 CLAUDE.md 或 rules/ 之后跑）
#
# 为什么 CLAUDE.md 也在清单里：它是规范正文，且规定了对话语言。
# 不进清单的话，改了它译本仓不会知道，三份就会悄悄说不同的话。
#
# 为什么要有它：译文不放在本仓（那会让 SOP 随语言数线性膨胀）。
# 译文各自成仓，生成时抄走这份清单；之后只要比两份清单就知道哪几篇过期了。
# 本仓因此只多一个小文件，仍然是单语言、薄的。
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MF="$PKG/MANIFEST.sha256"
CF="$PKG/I18N"

# 清单只在参照仓里生成与校验。别的语言仓拿到的是原样复制的脚本，
# 它们那边的对账依据是 SOURCE-MANIFEST.sha256，不是这份。
THIS="$(sed -n 's/^this=//p' "$CF" 2>/dev/null)"
REF="$(sed -n 's/^reference=//p' "$CF" 2>/dev/null)"
if [[ -n "$THIS" && -n "$REF" && "$THIS" != "$REF" ]]; then
  head1 "规则清单"
  ok "本仓是 $THIS 版，清单以 $REF 仓为准，本阶段不适用"
  exit 0
fi

gen() { cd "$PKG" && { echo CLAUDE.md; find rules -maxdepth 1 -name '*.md'; } | sort | xargs sha256sum; }

if [[ "${1:-}" == "--update" ]]; then
  head1 "更新规则清单"
  gen > "$MF"
  ok "$MF  $(wc -l < "$MF") 条"
  say "        译文仓下次生成时抄走它，对账就靠这份。"
  exit 0
fi

head1 "规则清单"
[[ -f "$MF" ]] || { bad "缺 MANIFEST.sha256"
  howto "跑： bash scripts/manifest.sh --update"; exit 1; }

if diff <(gen) "$MF" >/dev/null 2>&1; then
  ok "清单与 CLAUDE.md + rules/ 一致（$(wc -l < "$MF") 条）"
  exit 0
fi

bad "MANIFEST.sha256 与 CLAUDE.md + rules/ 不一致"
diff <(gen) "$MF" | grep -E '^[<>]' | sed 's/^/        /' | head -20
howto "改了规范正文或规则就要更新清单，否则各语言译文无从知道自己过期了：" \
      "bash scripts/manifest.sh --update" \
      "" \
      "清单不是装饰——它是译文仓唯一的对账依据。清单停滞 =" \
      "所有译文都显示「最新」，而它们其实已经过期。"
exit 1
