---
name: mutate
description: 对单个 src/ 文件做变异测试，验证现有测试是否真能杀掉简单 bug。触发：变异测试、survivor、测试锋利度。不用于：默认回归、全仓跑、merge gate。
---

# Mutate

按文件运行的 Lua 变异测试。诊断"测试绿但断言不够锋利"。

## 何时用 / 何时不用

- 用：怀疑某模块测试只是"跑到了"而不是"断严了"；重构高风险逻辑前；CRAP 高分函数做锋利度验证
- 不用：日常回归、全仓跑、合并门禁

## 决策树

1. **首次接入差分** → `lua tools/quality/mutate.lua <file> --mutate-all`
   wrapper 检测到 bootstrap-only manifest 会报错退出；必须先用 `--mutate-all` 把至少一次 `passed` / `no_sites` 状态写回 manifest，差分模式才有基线。
2. **日常 survivor 闭合** → `lua tools/quality/mutate.lua <file>`（默认差分）
3. **限定行号** → `--lines 12,18`（不刷新 manifest）
4. **只重写 manifest** → `--update-manifest`（扫描，不跑测试）
5. **切 lane** → `--lane behavior|contract`，默认 behavior

## 红线

- **survivor 闭合写 busted spec，不在 Gherkin 加 Examples**：Gherkin feature 不进 mutation corpus；只有 `spec/<lane>/*_spec.lua` 算。
- **pinning spec 不抽 state helper**：nil 与显式字段本身就是测试规约；helper 的默认值会埋掉 mutation 闭合。可抽 setup/teardown 和断言模式，不抽 state shape。
- **不全仓跑、不当默认 gate**：上游设计就是单文件诊断；进默认回归会拖垮 lane 时长。
- **bootstrap-only manifest 不算覆盖**：没有 `lastMutationStatus` 的 manifest 在差分模式会全部跳过，看起来"没东西要变异"但其实从未证明过覆盖。首次差分前必须 `--mutate-all`。
- **manifest 写在源文件末尾的注释块里**：不要手改；只有 mutation lane 全 kill 且未传 `--lines` 时才写入。
- **怀疑等价突变前先看历史**：循环缓冲、self-healing reset 路径常见 `or 1`、`<=/<`、`or/and` 等价突变；杀法是预填状态，不是改断言。

## 真源

- 工具机制、子命令、bootstrap-only 守卫：`docs/guides/mutation-testing.md`
- 差分契约：`features/quality/differential_mutation.feature` + `docs/decisions/0004-differential-mutation-testing.md`
- 上游：`swarmforge/tools.lock` 钉定的 `mutate4lua`，按需缓存到 `.swarmforge/tools/mutate4lua@<sha>/`

## 输出汇报

- 命令 + 目标文件
- survived / killed / timeout / no_sites 计数
- 每个 survivor：行号 + 突变类型 + 候选成因（真 bug / 等价突变 / 测试缺失）
- 下一步：补 spec 路径或申报等价

## 工具链改动

动到 `tools/quality/*` 任何文件 → handoff 跑 `lua tools/quality/verify_full.lua` + `busted --run tooling` 兜底（前者跑 shell-out 端到端，后者跑工具模块单测）。
