<!-- generated-from: CLAUDE.md sha256:486d6196426c2e69eb62b59bc7a69bfbf427d082ea5eb3a10a7c27cfe6bd64e8 -->
<!-- doc-lint:rule-definition -->
# singlefs-ai-sop-ja

**貢献者ガバナンス規範とゲートツール（Contributor Governance）。**
扱うのは**プロジェクトが AI とどう協働するか**であり、
ファイルシステムをどう設計するかではない。利用者は singlefs 一つだけである。
このリポジトリ内で作業するときも、これらの規則の対象となる。

規範本体を変更したら**必ず同時に `VERSION` を上げる**。
上げなければプロジェクト側のゲートがバージョン不一致を報告する。
**どのパスが「規範本体」かは `scripts/version-discipline.sh` の `GOVERNED` を正とする**
——一覧はそこ一箇所だけで、ここには写さない。

## 対話言語

**このリポジトリで作業するときは、対話も成果物もすべて日本語で行う。**
入れたリポジトリの言語でそのまま作業する。その理由と言語の一覧は
[README](README.md) の「自分の言語の版を選ぶ」節にあり、ここには写さない。

**読み方が食い違う場合は言語で決めず、`scripts/` の実際の挙動を正とする。**

**規則を変えるなら公開済みのすべての言語版を同時に変え、同時にマージする。**
一致しているかどうかは変更した本人が保証する——
ゲートに分かるのはハッシュの不一致だけである。

**何を翻訳し、何を原様のまま複製するか**の判定基準は一つだけ、
「そこに人が読む散文が含まれているか」である。二つの一覧は
`scripts/manifest.sh`（`translated_paths` と `not_translated_re`）にある。
どちらにも入らないものは網羅性の検査が止める。

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
@rules/writing-style.md
@rules/session-wrapup.md

## 切り分けの判定基準

**この SOP は singlefs のために作られたものであり、利用者は singlefs 一つだけで、
他のプロジェクトで通用することを前提にしていない。**
したがって判定基準は「他のプロジェクトもこれを必要とするか」ではない——
見るべき他のプロジェクトが無い以上、誰でも「する」と答えられ、何もかもが上流に上がる。

ある内容をどこに置くかは、それが何を扱っているかで決める：

- **協働を扱う**——提出物にどんな証拠を添えるか、文書の書き方、決定をどこに記すか、
  ゲートが拒否するとき次の一手をどう示すか。
  → このリポジトリ。方法論は `rules/`、手順は `skills/`、実行できるものは `scripts/`。
- **ファイルシステムの設計を扱う**——トランザクション、クラッシュ整合性、ディスク上の形式、
  この種類のシステムに固有の規律。
  → プロジェクト側。設計決定は `kb/decisions.md`、不変条件は `kb/invariants.md`、
  **プロジェクト固有の規則は `.claude/rules/`**、専用スクリプトは `.claude/scripts/`。

**迷ったらプロジェクト側に置く。** 上げるべきでない規則を上流に上げると、
以後どの回の作業もそれを避けて通ることになる。
プロジェクト側で置き場所を誤っても、直すのはファイル一つである。

## 接続方法

プロジェクトはこのリポジトリの内容を複製しない。三層それぞれに接続方法がある
（**シンボリックリンクは使わない**）：

| 層 | 接続方法 |
|---|---|
| rules | プロジェクトの `CLAUDE.md` から `@.claude/singlefs-ai-sop/rules/x.md` で参照し、複製を置かない |
| プロジェクト固有規則 | `.claude/rules/x.md` に置き、`@.claude/rules/x.md` で参照する。上流には上げない |
| skills | プロジェクトの `.claude/skills/<名>/SKILL.md` は**スタブ**：frontmatter ＋ 共有本文への案内 |
| scripts | プロジェクトの `.claude/scripts/x.sh` は**ラッパー**：環境を整えて共有スクリプトを `exec` する |

スタブとラッパーに本文やロジックを書かない——本文が在るべき場所は一箇所だけであり、
そこに書けば二箇所目ができ、二箇所はいずれ違うことを言い出す。
