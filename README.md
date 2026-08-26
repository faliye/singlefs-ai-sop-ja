# singlefs-ai-sop-ja

**singlefs 貢献者ガバナンス SOP の日本語版。**

> **実装は AI に優しく、レビューは人間に優しく。**

## このリポジトリは生成物である

**規則を変えるために、ここの rules を編集してはならない。**
原本は [singlefs-ai-sop-zh](https://github.com/faliye/singlefs-ai-sop-zh) であり、
そちらを変更してから全言語を再生成する。

「原本」とは*変更がどこから始まるか*を指すだけである——
中国語を使うのは表現の効率と精度のためであって、権威があるからではない。
**三つの文書の地位は同等である。** ある規則についての読み方が食い違う場合は、
**`scripts/` の実際の挙動が決める**——
スクリプトはこれらの規則の唯一の曖昧さのない表明である。

**唯一の例外**：翻訳そのものが誤っている場合（誤訳、ずれ、用語の不統一）は
ここで直す——**そして原本の記述が不明瞭でなかったかを併せて確認する。**
翻訳が曖昧さを露わにするのは副次的な価値であり、無駄にしない。

用語は三言語共通の [GLOSSARY.md](GLOSSARY.md) に従う。

## 同期の保ち方

`SOURCE-MANIFEST.sha256` は、この訳本を生成した時点の原本のマニフェストの写しである。
原本の現在の `MANIFEST.sha256` と比べれば、どのファイルが遅れているか分かる。
`VERSION` は三つのリポジトリで完全に一致し、一つ上げれば三つとも上がる。

## 導入

```bash
git clone https://github.com/faliye/singlefs-ai-sop-install
bash singlefs-ai-sop-install/sop-install.sh --lang ja
```

インストーラ自身の表示も、選んだ言語に従う。

## ライセンス

デュアルライセンス：[Apache-2.0](LICENSE-APACHE) または [MIT](LICENSE-MIT) の選択制。
