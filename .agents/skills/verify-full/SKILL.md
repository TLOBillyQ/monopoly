---
name: verify-full
description: "Run the fuller Monopoly quality pass and include guidance about when the slow tooling lane is required."
---

用管道编排器跑完整质量车道：

```
lua tools/quality/verify_full.lua
```

满足以下任一条件加 `--tooling`：

- 改动涉及 `tools/quality/*`
- 改动涉及 arch/crap/mutate 的 viewer 或导出流程
- 改动涉及 `vendor/arch_view`、`vendor/crap4lua`、`vendor/mutate4lua` 等质量工具集成

```
lua tools/quality/verify_full.lua --tooling
```

其他选项：`--no-coverage` 跳过 lua5.5 覆盖率收集。

编排器内部执行顺序：

1. lint + encoding（串行）
2. behavior（并行 3 worker）
3. contract + guards + arch [+ tooling]（并行）
4. crap report
5. coverage（需 lua5.5）

汇报时包含：

- 编排器输出的 PASS/FAIL 汇总行
- 失败的具体车道名
- 是否建议补跑 tooling 车道
- 跳过项（如 lint/coverage 依赖缺失）

适用场景：用户要求更广覆盖、提交前质量检查，或边界/工具链类改动的回归验证。
