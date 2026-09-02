# CHANGELOG

規則とゲートのバージョン履歴。`CLAUDE.md` と `rules/*.md` は履歴節を持たない
（design-doc-discipline）ので、履歴はここに記す。個々の変更の詳細は `git log`
を参照——コミットメッセージがそのまま変更説明になっている。

## 0.0.23 — 2026-09-02

敵対的監査を受けたゲート修正の一括投入（監査レポートは当該セッションの記録）：

- doc-lint：閉じていないコードフェンスを赤に；「履歴節」の後の `##` 節を赤に；
  履歴節内の表による不変条件定義は無効に；rules ファイルの履歴節を赤に；
  rule-definition マーカーは CLAUDE.md / rules / skills に限定；登録済み番号の
  not-numbers 免除を赤に；「脚本文件」「同上游」等の複合語を誤検知しないよう修正。
- gate-lint：`bad` を全形態で認識（単/二重引用符、変数、`;{|&` / `then` / `else`
  の後）；コメント内の howto は対処と見なさない；サマリ免除を
  「失敗/未通過/未過：$カウンタ」に限定。
- Show me test を show-me-test.sh に分離：コメント内の `#[test]` は無効；
  tests/ は `.rs` のみ有効；build.rs もコード扱い；デフォルトブランチでは
  diff 基準を HEAD~1 に後退させ、先にコミットしても「判定対象なし」にならない。
- lkmm：各 Never litmus に同名 `-nofence` の対照ペアを必須化（全体で
  Sometimes が 1 本あれば良い、を廃止）；静的検査を herd7 探索より前に；
  全拒否に howto を追加。
- i18n-sync / manifest：失敗分岐の diff 診断パイプラインが set -e + pipefail で
  スクリプトを途中終了させていた（howto と残り言語の検査が消える）——
  `|| true` で保護；i18n-sync は先にマニフェストの鮮度を検証；GLOSSARY.md を
  共有（そのまま複製）セットに追加。
- version-discipline.sh を新設：規範本体を変えて VERSION を上げなければ赤
  （従来は注意書きのみ）。
- selftest を全ゲートスクリプトに一般化：doc-lint / gate-lint / lkmm の
  サンプルに加え、show-me-test / version-discipline / manifest / i18n-sync の
  スクリプト化ケース、計 51 件。

## 0.0.22 — 2026-09-02

- session-wrapup に「同じリポジトリで他のセッションが飛んでいないか」節を追加；
  show-me-test にミューテーションリスト；test-discipline に「決定的モデル × N 回」
  「ミューテーションテストが証明するのはアサーションが赤になれること」；
  GLOSSARY にミューテーションテスト関連の用語を追加。

## 0.0.21 以前

`git log --oneline` を参照——各コミットメッセージは「バージョン：何を変えたか」
の形式で書かれている。
