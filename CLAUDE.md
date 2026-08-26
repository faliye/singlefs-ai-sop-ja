<!-- doc-lint:rule-definition -->
# singlefs-ai-sop-ja

**貢献者ガバナンス規範とゲートツール（Contributor Governance）。**
扱うのは**プロジェクトが AI とどう協働するか**であり、
特定分野のシステムをどう設計するかではない。
このリポジトリ内で作業するときも、これらの規則の対象となる。

`rules/` または `scripts/` を変更したら**必ず同時に `VERSION` を上げる**。
上げなければ各プロジェクトのゲートがバージョン不一致を報告する。

## 対話言語

**このリポジトリで作業するときは、対話も成果物もすべて日本語で行う。**

**開発者は自分の言語に合った版を選ぶ。** 現在は中国語・英語・日本語があり、
他の言語版も準備中である。既定の版は英語。入れたリポジトリの言語でそのまま作業する
——日本語で作業する人が中国語を読む必要はない。
**AI もそこで訳し直す必要がない**。転記が一度減れば、情報の損失も一度分減る。

規則の内容はすべての版で一致していなければならない。
読み方が食い違う場合は言語で決めず、`scripts/` の実際の挙動を正とする。

**規則を変えるなら公開済みのすべての言語版を同時に変え、同時にマージする。**
一致しているかどうかは変更した本人が保証する——
ゲートに分かるのはハッシュの不一致だけである。

## 規則（常時有効）

@rules/engineering-philosophy.md
@rules/sop-first.md
@rules/show-me-test.md
@rules/machine-first.md
@rules/doc-discipline.md
@rules/design-doc-discipline.md
@rules/kb-discipline.md
@rules/test-discipline.md
@rules/evidence-discipline.md
@rules/verify-before-claiming.md
@rules/command-safety.md
@rules/writing-economy.md
@rules/session-wrapup.md

## 切り分けの判定基準

ある内容をどこに置くかは、一言で問う「**他のプロジェクトもこれを必要とするか**」：

- する → このリポジトリ。方法論は `rules/`、手順は `skills/`、実行できるものは `scripts/`。
- しない → プロジェクト側。設計決定は `kb/decisions.md`、不変条件は `kb/invariants.md`、
  **プロジェクト固有の規則は `.claude/rules/`**、専用スクリプトは `.claude/scripts/`。

ここでいう「他のプロジェクト」とは、この SOP を使う**あらゆる**プロジェクトであり、
「同種のプロジェクト」ではない。ファイルシステムだけが必要とする規律は、
どれほどよく書けていてもプロジェクト側のものである。

逆に、プロジェクトのファイル内に**他のプロジェクトでも書き写されている**内容を見つけたら、
それはこのリポジトリに欠けている一条である——引き上げること。三度目を書き写さない。

## 接続方法

各プロジェクトはこのリポジトリの内容を複製しない。三層それぞれに接続方法がある
（**シンボリックリンクは使わない**）：

| 層 | 接続方法 |
|---|---|
| rules | プロジェクトの `CLAUDE.md` から `@.claude/singlefs-ai-sop/rules/x.md` で参照し、複製を置かない |
| プロジェクト固有規則 | `.claude/rules/x.md` に置き、`@.claude/rules/x.md` で参照する。上流には上げない |
| skills | プロジェクトの `.claude/skills/<名>/SKILL.md` は**スタブ**：frontmatter ＋ 共有本文への案内 |
| scripts | プロジェクトの `.claude/scripts/x.sh` は**ラッパー**：環境を整えて共有スクリプトを `exec` する |

スタブとラッパーに本文やロジックを書かない——そこに書いても他のプロジェクトからは見えず、
次にまた書き写されることになる。
