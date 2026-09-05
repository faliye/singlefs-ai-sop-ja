---
name: crash-test
description: singlefs の検証スイートを走らせる——LKMM メモリ順序、QEMU/KVM ストレス、クラッシュ点リプレイ、モデル対照テスト。書き込み経路が正しいかを判断するとき、並行性の変更に検証を付けるときに使う。
---
<!-- generated-from: skills/crash-test/SKILL.md sha256:03baaac78f5de9508b3473142cef72d25fdd23bd8138713225d7a659d955f9f8 -->

# 検証スイート

規則は `rules/test-discipline.md` と `rules/show-me-test.md`。

## 四つの手段の分担

| 手段 | 何を検証するか | 状態 |
|---|---|---|
| **LKMM（herd7）** | 並行経路のメモリ順序：ロックフリー構造、バリア、コア間の可視性 | ✅ 利用可 |
| **QEMU/KVM** | 実負荷での端から端までの挙動。受入の最終判定基準 | ⚙️ harness は用意済み、負荷が無い |
| クラッシュ点リプレイ | 任意の断電点から復帰できるか | ❌ 未実装 |
| モデル対照テスト | 機能的正しさ：操作列の結果が正しいか | ❌ 未実装 |

## LKMM

```bash
bash .claude/scripts/lkmm.sh
SINGLEFS_KERNEL_TREE=/path/to/linux bash .claude/scripts/lkmm.sh   # カーネルツリーを指定
```

`litmus/*.litmus` は期待する判定を宣言しなければならない。スクリプトは herd7 の
`Observation` 行と突き合わせる：

```
(* singlefs-expect: Never *)      悪い結果は起こり得てはならない
(* singlefs-expect: Sometimes *)  悪い結果は起こり得る（対照群）
```

**Never の一本ごとに、バリアを外した Sometimes の対照群を付ける。** 一本しか無ければ、
Never が出ても「バリアが止めたのか」「そのパターンが元々当たらないのか」を区別できない——
対になる一本が無い Never をスクリプトは拒否する。

対応付けは**ファイル名で見る**：`x.litmus` の対照群は `x-<接尾辞>.litmus`
（慣例は `x-nofence.litmus`）で、Sometimes を宣言する。他所に Sometimes が何本あろうと
数に入らない——それは別の問いに答えている。

klitmus7 でしか露見しない落とし穴が二つある（スクリプトが手前で止める）：
`rN` を使うなら `int rN;` が要る。init ブロックで `atomic_t` の仮引数に初期値を与えるなら型が要る。

## QEMU

```bash
bash .claude/scripts/qemu.sh --selftest        # harness 自体を検証する
bash .claude/scripts/qemu.sh . payload.sh      # 負荷を一つ走らせる
GATE_QEMU=1 bash .claude/scripts/gate.sh       # ゲートに harness 自己検査を含める
```

**`--selftest` はわざと失敗する payload を走らせ**、harness が失敗を失敗と見分けられるか
確かめる。見分けられなければ失敗を成功として報告することになり、そのとき harness は自ら
エラーを出す。

読めるカーネルが見つからないときスクリプトは失敗し、二つの道を示す
（`SINGLEFS_KERNEL=` を指すか、`/boot/vmlinuz-*` に読み権限を付けるか）——
**ソフトウェアエミュレーションへ黙って降格しない**。動いているように見えて使い物にならない遅さになる。

## クラッシュ点リプレイを他で代替できない理由

**単体テストが全緑、モデル対照が全通過、checker が無報告——三つ足してもクラッシュ一貫性の根拠にならない。**

それらが検証するのは「正常経路での状態が正しいか」である。クラッシュ一貫性が問うのは別の問いだ：
**任意の書き込み要求のあとで断電したとき、再起動して収拾がつくか。**
これは各クラッシュ点を一つずつ試す以外に答えようがない。

実装に必要なもの（依存順）：ディスク書式の第一版（プロジェクトの `kb/decisions.md` の
ディスク書式に関する項目を見る）→ mkfs + checker → トランザクションのコミット経路 →
ブロック層の書き込み記録（`dm-log-writes`）。

## 判読の規律

- **「再現しなかった」は「問題が無い」ではない。** クラッシュ一貫性が成立すると言うには、
  この回でクラッシュ点をいくつ列挙したのか、それが全部なのかを述べること。
- **checker が無報告なのは、その検査が未実装なだけかもしれない。** 先に
  `kb/invariants.md` の状態列を見る。
- **判定が読めないときはその回を破棄**し、決して通過扱いにしない——`lkmm.sh` が
  `Observation` を読めない、`qemu/run.sh` が終了マーカーを読めない、どちらも即失敗である。
