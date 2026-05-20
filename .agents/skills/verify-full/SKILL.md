---
name: verify-full
description: "Run the fuller Monopoly quality pass and include guidance about when the slow tooling lane is required."
---

跑完整质量车道（管道编排器）：

```
lua tools/quality/verify_full.lua
```

改动涉及以下任一时加 `--tooling`：

- `tools/quality/*`
- arch/crap/mutate 的 viewer 或导出流程
- `vendor/arch_view`、`vendor/crap4lua`、`vendor/mutate4lua` 等质量工具集成

```
lua tools/quality/verify_full.lua --tooling
```

其他选项：`--no-coverage` 跳过 lua5.5 覆盖率。

执行顺序：

1. lint + encoding（串行）
2. behavior（并行 3 worker）
3. contract + guards + arch [+ tooling]（并行）
4. crap report
5. coverage（需 lua5.5）

汇报：

- PASS/FAIL 汇总行
- 失败车道名
- 是否补跑 tooling 车道
- 跳过项（如 lint/coverage 依赖缺失）

适用场景：要求更广覆盖、提交前质量检查，或边界/工具链改动的回归验证。
