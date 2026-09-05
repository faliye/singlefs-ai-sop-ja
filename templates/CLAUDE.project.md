<!-- generated-from: templates/CLAUDE.project.md sha256:64d43f9ae51f9eb8988adbeab22381e802f7aef2d69bcb6e772709910e7939d5 -->
# <プロジェクト名>

<三〜五行：このプロジェクトが何か、今どのマイルストーンか、singlefs 本線とどういう関係か。
それより長くしない。>

## 規則（常時有効）

@.claude/singlefs-ai-sop/rules/engineering-philosophy.md
@.claude/singlefs-ai-sop/rules/sop-first.md
@.claude/singlefs-ai-sop/rules/show-me-test.md
@.claude/singlefs-ai-sop/rules/machine-first.md
@.claude/singlefs-ai-sop/rules/doc-discipline.md
@.claude/singlefs-ai-sop/rules/design-doc-discipline.md
@.claude/singlefs-ai-sop/rules/kb-discipline.md
@.claude/singlefs-ai-sop/rules/test-discipline.md
@.claude/singlefs-ai-sop/rules/evidence-discipline.md
@.claude/singlefs-ai-sop/rules/verify-before-claiming.md
@.claude/singlefs-ai-sop/rules/command-safety.md
@.claude/singlefs-ai-sop/rules/writing-economy.md
@.claude/singlefs-ai-sop/rules/writing-style.md
@.claude/singlefs-ai-sop/rules/session-wrapup.md

**ファイルシステム設計に固有の規則**（トランザクション、クラッシュ一貫性、ディスク書式の類）は
`.claude/rules/` に置き、ここで併せて `@` 参照する。共有 SOP へ上げない——
あちらには協働の規範だけを置く。

（上の `@.claude/singlefs-ai-sop/...` は
[singlefs-ai-sop](.claude/singlefs-ai-sop/README.md) が配布する共有規則である。
**それらを変えることは、参加者全員の下限を変えることに等しい**——変えるなら上流を変えて
`VERSION` を上げる。プロジェクト内でその場で書き換えてはならない。）

## プロジェクト固有の事実

| ファイル | 内容 |
|---|---|
| `.claude/kb/decisions.md` | 設計判断：何が決まり、なぜ決まり、何がまだ決まっていないか |
| `.claude/kb/experiments.md` | 実験記録：問い、先に決め打った判定基準、対照と変異、再実行コマンド |
| `.claude/kb/invariants.md` | 不変条件リスト。checker がその実行可能な形 |
| `.claude/kb/prior-art.md` | 他実装の調査。出典と計測条件つき |
| `.claude/kb/pitfalls.md` | 落とし穴一覧。設計判断のたびに照合しに戻る |
| `.claude/kb/checks-owed.md` | 借りている検査：止めたいと分かっているがまだ止められないもの。前提つき |
| `records/` | 構築の経過 |

## ゲート

ゲートの目的は**提出物のすべてを「人の時間を割いて見る価値がある」線まで引き上げる**ことであって、
誰かを締め出すことではない。出どころで提出者を分けず、根拠を伴うものと伴わないものだけを分ける。

```bash
bash .claude/scripts/gate.sh          # 受入ゲート。提出前に必ず
GATE_QEMU=1 bash .claude/scripts/gate.sh   # さらに QEMU harness 自己検査を加える

bash .claude/scripts/check.sh         # 速い折り返し（書式/lint/ビルド/単体テスト）
bash .claude/scripts/lkmm.sh          # メモリ順序（herd7 + litmus/）
bash .claude/scripts/qemu.sh --selftest    # QEMU harness 自己検査
bash .claude/scripts/gate-lint.sh     # ゲート自身：拒否のすべてが次の一手を示しているか
bash .claude/scripts/shell-lint.sh    # shell 規律：パターン一致での kill、サブシェルからの値の持ち出し
bash .claude/scripts/env.sh           # 環境自己検査
```

**Gate proves evidence requirements, not semantic correctness.**
緑は根拠要件が満たされたことを示すだけで、意味的な正しさを示さない——
`gate.sh` は毎回、未実装の段階を並べて出す。

## このプロジェクトの特殊性

<一〜三条。やり方が変わるものだけ書く。展開した判定基準は kb に置き、ここには道案内だけ残す。>

## 一段落版

<三〜四文。各文はこのプロジェクトで最も転びやすい判定基準を一つずつ。
一般的な規律はここに写さない。それは rules にある。>
