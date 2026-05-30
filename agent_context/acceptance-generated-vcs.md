# acceptance-generated-vcs — ADR 评估：tools/acceptance/generated/ 是否继续版本控制

specifier 路由给 architect 起 ADR 评估（用户指示）。不是规约变更，是仓库/管线策略决策。

## 决策问题

`tools/acceptance/generated/*`（22 个 busted 验收 spec，~850KB）继续 **track**，还是改为
**gitignore + 在验收入口前确定性重生成**？

## 现状机制（specifier 已核实）

- 纯生成物：`.feature` → `acceptance4lua` parser → generator → 内嵌 `embedded_ir` 的
  busted spec。CLAUDE.md 明令不可手改、从 feature/generator 源头更新——完全可重新派生，无手改。
- **`busted --run acceptance` 直接消费已提交文件**（`.busted:90` ROOT=`tools/acceptance/generated`），
  **运行时不重生成**。→ 今天 untrack 会让验收命令空跑/失败。
- **`make verify`（smoke + full）不跑 acceptance lane**（lanes: arch/behavior/contract/encoding/
  guards/crap/coverage/tooling），generated 目录与 verify 无关。
- 单 feature 开发走 `tools/acceptance/run_acceptance.lua`，**即时 parse+generate+run**
  （已用 `acceptance4lua.generator`）——证明确定性重生成路径已存在、可复用。

## 取舍

继续 track（现状）：
- 验收命令开箱即用、PR 可见 diff。
- 代价：~850KB、高 churn（skin_shop 单次重生成 = 1725 行 diff）、合并冲突面大、
  催生整类"generated 陈旧 vs feature"漂移 bug，需 coder/architect 手动"重生成"提交。

gitignore + 重生成入口：
- 单一真相源 = `.feature` + step handlers；消灭漂移 bug 类 + churn。
- 可能让 `feature_stamp`/`spec_hash` 漂移守卫机制（ADR 0009 那套）失去存在理由。
- 代价：验收入口 + CI 要接确定性重生成；engineering 规则要求"生成与验收顺序跑"，
  需确认耗时可接受；fresh checkout/CI 复现依赖 acceptance4lua 子模块（已 init）。

## ADR 应裁定

1. track vs gitignore+regen。
2. 若改：重生成接在哪（`busted --run acceptance` 前置 hook / 独立 make 目标 / CI 步骤），
   determinism + 耗时（顺序跑全部 feature）+ fresh-checkout 复现。
3. `feature_stamp`/`spec_hash` 漂移守卫的去留（与 ADR 0009 的关系）。
4. mutation 不受影响（Gherkin 突变作用于 `.feature`，stamp/manifest 内嵌 .feature，非 generated）。

## specifier 倾向（非决策）

high-churn + 可派生 + 不进 verify 的产物，gitignore + 验收前重生成是更干净的长期设计；
但反转 ADR 0009-邻近的"提交生成物 + stamp 守卫"决策属架构层，故起 ADR 而非随手 .gitignore。

相关：[[project_acceptance_pipeline_spec_gap]] [[reference_agent_context_local_exclude]]
