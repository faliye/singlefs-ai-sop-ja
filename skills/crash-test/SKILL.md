---
name: crash-test
description: 跑 singlefs 的验证套件——LKMM 内存序、QEMU/KVM 压测、崩溃点重放、模型对拍。判断写路径对不对、或要给并发改动补验证时用它。
---

# 验证套件

规则在 `rules/test-discipline.md` 与 `rules/show-me-test.md`。

## 四种验证的分工

| 手段 | 验什么 | 状态 |
|---|---|---|
| **LKMM（herd7）** | 并发路径的内存序：无锁结构、屏障、跨核可见性 | ✅ 可用 |
| **QEMU/KVM** | 真实负载下的端到端行为，准入的最终判据 | ⚙️ harness 就绪，缺负载 |
| 崩溃点重放 | 任意断电点能否恢复 | ❌ 未实现 |
| 模型对拍 | 功能正确性：操作序列结果对不对 | ❌ 未实现 |

## LKMM

```bash
bash .claude/scripts/lkmm.sh
SINGLEFS_KERNEL_TREE=/path/to/linux bash .claude/scripts/lkmm.sh   # 指定内核树
```

每个 `litmus/*.litmus` 必须声明期望判定，脚本拿 herd7 的 `Observation` 行比对：

```
(* singlefs-expect: Never *)      坏结果必须不可能发生
(* singlefs-expect: Sometimes *)  坏结果可能发生（对照组）
```

**每条 Never 都要配一个去掉屏障的 Sometimes 对照组。** 只有一份的话，
判出 Never 也分不清是「屏障挡住了」还是「这个模式本来就撞不上」——
脚本会直接拒绝只有 Never 的清单。

写 litmus 时注意两个只有 klitmus7 才会炸的坑（脚本会提前拦）：
用了 `rN` 必须有 `int rN;`；init 块里给 `atomic_t` 形参赋初值必须带类型。

## QEMU

```bash
bash .claude/scripts/qemu.sh --selftest        # 验证 harness 本身
bash .claude/scripts/qemu.sh . payload.sh      # 跑一个负载
GATE_QEMU=1 bash .claude/scripts/gate.sh       # 门禁里带上 harness 自检
```

**`--selftest` 会跑一个故意失败的 payload**，确认 harness 认得出失败。
认不出就说明它会把失败当成成功，这时 harness 自己报错。

找不到可读内核时脚本会失败并给出两条路（`SINGLEFS_KERNEL=` 或给 `/boot/vmlinuz-*` 加读权限）——
**不会静默降级到软件模拟**，那会慢到不可用却看起来在跑。

## 为什么崩溃点重放不能用别的代替

**单测全绿、模型对拍全过、checker 无报错——三个加起来也不构成崩溃一致性证据。**

它们验的是「正常路径下状态对不对」。崩溃一致性问的是另一个问题：
**在任意一个写请求之后断电，重启还能不能收场。** 这只有把每个崩溃点都试一遍才能回答。

实现它需要（按依赖顺序）：磁盘格式第一版（`kb/decisions.md` D4/D8）→ mkfs + checker
→ 事务提交路径 → 块层写记录（`dm-log-writes`）。

## 判读纪律

- **「没复现问题」不等于「没问题」。** 要说崩溃一致性成立，
  得说清这一轮枚举了多少个崩溃点、是不是全部。
- **checker 没报错也可能是检查没实现。** 先看 `kb/invariants.md` 的状态列。
- **读不到判定结果时整轮作废**，绝不当成通过——`lkmm.sh` 读不到 `Observation`、
  `qemu/run.sh` 读不到退出标记，都是直接失败。
