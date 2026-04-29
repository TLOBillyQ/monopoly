---
name: verify-full
description: Run the fuller Monopoly quality pass and include guidance about when the slow tooling lane is required.
---

按以下顺序跑完整质量车道：

1. `lua tools/quality/lint.lua`（仅当本地装了 `luacheck`）
2. `busted --run behavior`
3. `busted --run contract`
4. `busted --run guards`
5. `lua tools/quality/arch.lua check`
6. `lua tools/quality/crap.lua report --lane behavior --out tmp/crap_report.json`

满足以下任一条件再追加 `busted --run tooling`：

- 改动涉及 `tools/quality/*`
- 改动涉及 arch/crap/mutate 的 viewer 或导出流程
- 改动涉及 `vendor/arch_view`、`vendor/crap4lua`、`vendor/mutate4lua` 等质量工具集成

汇报时包含：

- 实际跑了哪些命令
- 主动跳过了哪些命令
- 是否建议补跑慢速 tooling 车道
- 任何跳过项对应的下一条精确命令

适用场景：用户要求更广覆盖、提交前质量检查，或边界/工具链类改动的回归验证。