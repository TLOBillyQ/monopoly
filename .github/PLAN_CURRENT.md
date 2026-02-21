# 代码库深度清理实施计划

本可执行计划是活文档。实施过程中必须持续维护“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.github/PLANS.md`。

## 目的 / 全局视角

本次深度清理的目标是：在不改变玩法与 UI 行为的前提下，减少代码噪音和维护成本，删除明确无用代码，收敛重复实现，统一低层工具的调用路径。完成后，开发者能更快定位核心逻辑，新增功能时需要改动的文件更少，回归成本更可控。

可见验收方式是：`regression` 全绿，核心交互测试全绿，且仓库中高置信无用项数量显著下降（有证据链与改动清单）。

## 进度

- [x] (2026-02-21 23:28Z) 读取并确认计划规范与仓库约束（`PLANS.md` / `CODING.md` / `THIS.md`）。
- [x] (2026-02-21 23:29Z) 清空并重建当前计划文件，切换到“代码库深度清理”任务。
- [x] (2026-02-21 23:31Z) 基线验证完成：`lua .github/tests/regression.lua` 通过（`143`）。
- [x] (2026-02-21 23:34Z) 全库审计完成：识别出“回归漏跑测试”“UI 图片渲染重复逻辑”“无效分支条件”等高置信清理点。
- [x] (2026-02-21 23:38Z) 实施第一批低风险清理：补齐 `gameplay_loop` 与 `presentation_ui_action_status` 的 slice 覆盖，删除 `UIModelPanelBuilder` 的无效条件分支。
- [x] (2026-02-21 23:39Z) 实施第二批结构清理：`PopupRenderer` 提取节点贴图回退公共逻辑，收敛重复实现。
- [x] (2026-02-21 23:40Z) 最终验证完成：`lua .github/tests/regression.lua` 通过（`149`），`dep_rules ok`、`tick ok`。
- [x] (2026-02-21 15:40Z) 后续清理（选项 1）：移除 `ChoiceScreenService` 纯转发层，`UIModalPresenter` 直接依赖 `choice_screen_service/openers` 与 `common`，回归保持 `149` 全绿。

## 意外与发现

- 观察：`gameplay_loop` 与 `presentation_ui_action_status` 的 slice 上限偏小，导致已定义测试未进入回归。
  证据：基线 `regression` 为 `143`；修正 slice 后为 `149`。

- 观察：静态“未引用”判断会漏掉测试运行时的间接依赖。
  证据：删除 `TestSupport.first_adjacent_land_pair` 后，`land` 套件报错 `attempt to call a nil value`；已回补并恢复全绿。

## 决策日志

- 决策：先做“证据驱动”的清理，不做主观式大改。
  理由：深度清理最怕误删，先建立引用证据和测试护栏可控性最高。
  日期/作者：2026-02-21 / Codex。

- 决策：分两批实施，第一批仅低风险删除和去重，第二批再做小范围结构重排。
  理由：将风险前置隔离，保证每批都能独立回归验证。
  日期/作者：2026-02-21 / Codex。

- 决策：保留 `TestSupport.first_adjacent_land_pair`，不再作为“僵尸 helper”清理对象。
  理由：实测被 `land` 套件间接使用，删除会破坏回归稳定性。
  日期/作者：2026-02-21 / Codex。

- 决策：删除 `ChoiceScreenService` 包装层并把唯一业务逻辑内聚到 `UIModalPresenter`。
  理由：该模块多数函数仅转发，增加无效跳转；改为直接依赖 `openers/common` 可降低维护路径长度且不改行为。
  日期/作者：2026-02-21 / Codex。

## 结果与复盘

本轮深度清理已完成并通过回归。主要成果有三类：第一，修复测试覆盖盲区，`regression` 用例数从 `143` 提升到 `149`；第二，去掉了 `UIModelPanelBuilder` 中不可达条件（`flags.turn`）；第三，合并了 `PopupRenderer` 内重复的节点贴图回退逻辑，减少未来维护分叉风险。

按后续指令已追加一轮包装层清理：删除 `ChoiceScreenService`，并将 `select_choice_option` 的 building 标题刷新逻辑迁入 `UIModalPresenter`。回归结果保持不变。

回顾中最重要的教训是：对“测试工具是否未使用”的判断必须以回归执行结果二次确认，不能只依赖静态引用搜索。该问题已通过“误删即回补 + 回归复测”的方式闭环。

## 背景与导读

本仓库是 Lua 项目，运行链路入口为 `main.lua` 与 `src/app/init.lua`，核心玩法在 `src/game`，表现层在 `src/presentation`，配置与生成数据在 `Config` 与 `Data`。已有测试入口为 `/Users/billyq/Dev/Github/Lua/monopoly/.github/tests/regression.lua`。

本次清理只处理“行为不变”的内容：无引用代码、重复逻辑、过时封装、冗余中间层、测试中的重复样板。禁止修改策划数值、地图规则和 UI 交互语义。

## 工作计划

先执行基线回归，确保当前分支健康。然后做静态审计，建立“候选清理项 -> 证据 -> 风险”的列表。实施时按风险从低到高推进：先删明确无引用项，再合并重复代码，最后做小范围函数职责收敛。每一批改动结束都跑回归，确保行为不变。

## 具体步骤

1. 基线回归：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

2. 全库审计（引用关系与重复逻辑）：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    rg "require\(" src Config .github/tests

    cd /Users/billyq/Dev/Github/Lua/monopoly
    rg "TODO|deprecated|legacy|unused|兼容" src .github/tests

3. 实施低风险清理后回归：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

4. 实施结构清理后回归：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

## 验证与验收

验收通过需同时满足：

1. `regression.lua` 全通过。
2. 无新增跨层违规依赖（以现有 `dep_rules` 为准）。
3. 清理项都有“删除/合并理由 + 引用证据 + 风险说明”。
4. 用户可见行为不变（choice、行动分发、UI 交互路径不变）。

## 可重复性与恢复

每批改动保持独立且可回滚，不使用破坏性 git 操作。若某批引发回归失败，回退该批新增改动并保留前一批已验证结果。

## 产物与备注

- 变更文件：
  - `.github/tests/suites/gameplay_loop.lua`
  - `.github/tests/suites/presentation_ui_action_status.lua`
  - `src/presentation/state/UIModelPanelBuilder.lua`
  - `src/presentation/ui/PopupRenderer.lua`
  - `src/presentation/ui/UIModalPresenter.lua`
  - `src/presentation/ui/ChoiceScreenService.lua`（已删除）
  - `.github/tests/TestSupport.lua`（仅回补误删，净效果为保持原行为）
- 回归摘要：
  - 清理前：`All regression checks passed (143)`
  - 清理后：`All regression checks passed (149)`，并保持 `dep_rules ok`、`tick ok`

## 接口与依赖

本次清理优先复用已有抽象：`TurnActionPort`、`GameplayLoopPorts`、`UIRuntimePort`。不新增外部依赖，不引入新框架。若需要新增内部工具函数，必须放在现有模块边界内，避免再造并行层。

---

更新记录（2026-02-21 23:29Z）：新任务“代码库深度清理”已重建计划文件，替换上一任务的重构计划，避免上下文污染。
更新记录（2026-02-21 23:40Z）：已补齐回归遗漏测试、完成 UI 去重清理并验证全绿；同时记录一次误删回补，修正“静态引用即未使用”的假设。
