# 术语表

**三语共用。** 译本必须照这里的对应关系翻，不许各篇分头造词。
新增术语先加到这里，再去译文里用。

| 中文 | English | 日本語 | 说明 |
|---|---|---|---|
| 门禁 | gate | ゲート | 自动化准入检查的总称 |
| 准入判据 | acceptance criterion | 受入判定基準 | 决定 patch 收不收的依据 |
| 参照仓 | reference repository | 参照リポジトリ | 清单与门禁脚本放在哪个语言的仓里；版本比对以它为准，不等于权威 |
| 会失败的检查 | failing check | 失敗しうる検査 | 与「提醒句」相对 |
| 出路 / 怎么办 | remedy | 対処 | 每条拒绝必须附带的下一步 |
| 证据 | evidence | 根拠 | acceptance is evidence-bound 里的那个 |
| 口径 | measurement basis | 計測条件 | 一个数字是怎么测出来的 |
| 实测 / 推理 | measured / inferred | 実測 / 推論 | kb 里每条结论必须二选一标注 |
| 不变量 | invariant | 不変条件 | checker 是它的可执行形式 |
| 崩溃点重放 | crash-point replay | クラッシュ点リプレイ | 在每个可能的断电点截断重放 |
| 模型对拍 | model-based differential testing | モデル対照テスト | 与内存里的理想实现比对 |
| 对照组 | control case | 対照ケース | litmus 里去掉屏障的那一份 |
| 意图日志 | intent log | インテントログ | 无界操作的「写意图 → 分批 → 可续做」 |
| 无界操作 | unbounded operation | 非有界操作 | 可能修改无限多项的操作 |
| 幂等 | idempotent | 冪等 | 续做时重复执行不出错 |
| 事务层 | transaction layer | トランザクション層 | 所有结构共用的那一个 |
| 反向索引 | reverse index / backpointer | 逆引きインデックス | 物理位置 → 逻辑引用 |
| 记账 | accounting | 会計 | 空间统计，事务的副产品 |
| 爆炸半径 | blast radius | 影響範囲 | 一处损坏波及多大 |
| 可重建性 | reconstructability | 再構築可能性 | 全盘扫描能否重建 |
| 分支 | branch（实现分支） | 分岐 | **不是 git branch**，是代码路径 |
| 路径数 | path count | 経路数 | 穷尽覆盖需要多少用例 |
| 上下文指代 | dangling reference | 文脈依存の参照 | kb 里禁止的那类写法 |
| 译本 | translation | 訳本 | 生成物，不是平行版本 |

## 三句核心表述

英文是原文，中日文是译文，**不要反过来改英文**：

> **Make every submitted patch review-worthy.**
> 让每一份提交都值得被 review。
> 提出されたすべてのパッチを、レビューに値するものにする。

> **Contribution throughput may be unbounded; acceptance throughput is evidence-bound.**
> 投稿吞吐可以无限，接收吞吐受证据约束。
> 投稿のスループットは無限でありうるが、受入のスループットは根拠に縛られる。

> **Gate proves evidence requirements, not semantic correctness.**
> 门禁证明的是证据要求被满足，不是代码语义正确。
> ゲートが証明するのは根拠要件の充足であって、意味的な正しさではない。

以及工程理念那一句：

> **实现上 AI 友好，审核上人类友好。**
> AI-friendly to implement, human-friendly to review.
> 実装は AI に優しく、レビューは人間に優しく。
