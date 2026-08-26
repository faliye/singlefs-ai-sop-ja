---
name: gate
description: 跑 singlefs 的准入门禁。提交代码前、判断一个改动能不能收时用它——包含门禁各阶段的含义、怎么判读结果、哪些"失败"是环境问题而不是代码问题。
---

# 准入门禁

规则在 `rules/show-me-test.md`。**这里写怎么跑、怎么判、哪些失败是假的。**

## 跑

```bash
bash .claude/scripts/gate.sh          # 全套，提交前必跑
bash .claude/scripts/check.sh         # 只跑格式/lint/构建/单测，快速反馈
bash .claude/scripts/env.sh           # 只做环境自检
GATE_BASE=<commit> bash .claude/scripts/gate.sh   # 指定 diff 基准
```

## 阶段与判读

| 阶段 | 失败意味着 |
|---|---|
| 规范版本 | 项目的 `.singlefs-ai-sop-version` 和 singlefs-ai-sop 的 `VERSION` 不一致。**先读一遍规则变更**，再跑 `install.sh` 更新戳 |
| 文档铁律 | 正文里混了历史陈述。按提示删掉并挪进「历史版本」节，见 `rules/doc-discipline.md` |
| Show me test | 改了 `crates/*/src` 但没带测试。**这条不许绕过**，见 `rules/show-me-test.md` |
| 构建与单测 | 真的坏了，或者 cargo 缺失 |

## 未实现的阶段

`gate.sh` 每次都会列出**尚未实现**的门禁阶段（模型对拍 / 崩溃点重放 / QEMU 压测）。

**这不是提示噪音，是判读结果的必要前提**：门禁全绿只说明「文档合规 + 有测试 + 单测过」，
**不构成任何崩溃一致性证据**。在崩溃点重放接进来之前，
任何「写路径验证过了」的说法都是假的。

## 常见假失败

| 现象 | 真因 |
|---|---|
| 「没有检测到任何变更」 | 在默认分支上且工作区干净。门禁无对象可判，不是代码问题 |
| 构建阶段报 cargo 缺失 | 环境问题。跑 `env.sh` 看全貌，装工具链后重跑 |
| doc-lint 报了规则文档自己 | 该文件缺 `<!-- doc-lint:rule-definition -->` 标记 |
| Show me test 说没测试，但确实写了 | 测试写在了 `crates/*/src/` 里且没用 `#[cfg(test)]`/`#[test]` 标注，脚本认不出来 |

## 门禁自己也要能失败

改了 `gate.sh` 或 `doc-lint.sh` 之后，**必须造一个应该被拦的输入验证它真的会红**：

```bash
# 往某个 kb 文档正文里塞一句带历史陈述的话，确认 doc-lint 报错，再删掉
echo "节点大小 16K（原为 4K）。" >> .claude/kb/decisions.md
bash .claude/scripts/doc-lint.sh; echo "退出码 $? —— 应为 1"
git checkout .claude/kb/decisions.md
```
按 `rules/show-me-test.md`，不能证明会红的检查等于没写。
