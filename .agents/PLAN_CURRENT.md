# 表现层重构执行计划：动画与弹窗解耦、节点映射集中化

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前 `src/presentation/**` 中动画、弹窗与事件路由存在职责混杂与硬编码节点名的问题，扩展成本高、测试困难。完成后，动画播放将通过可注册的 handler 进行扩展；弹窗与选择屏渲染将由独立渲染器负责；UI 节点名集中在单一映射表，避免全局散落字符串。验证方式是：现有 UI 行为不变；新增/替换动画类型无需改动核心调度函数；节点名改动只需改映射表即可生效；基础回归流程可继续通过。

## 进度

- [x] (2025-03-08 10:10Z) 建立节点映射表 `UINodes`，并替换事件绑定、意图构建、画布协调与面板渲染中的硬编码字符串。
- [x] (2025-03-08 10:18Z) 拆分 `ActionAnim` 为注册表与 handler，保持调度函数短小。
- [x] (2025-03-08 10:26Z) 拆分 `UIModalPresenter` 为屏幕渲染器与流程协调器。
- [x] (2025-03-08 10:32Z) 为 `UIEventRouter` 引入 Provider 注册表并迁移构建逻辑。
- [x] (2025-03-08 10:45Z) 继续拆分 `ActionAnimHandlers` 并补充回归测试用例。
- [x] (2025-03-08 10:55Z) 执行回归测试并修复 ActionAnimUnits 测试环境问题。

## 意外与发现

- 观察：测试环境没有 `GameAPI.create_unit_with_scale`，导致动画用例崩溃。
  证据：回归输出 `missing GameAPI.create_unit_with_scale`。

## 决策日志

- 决策：按“节点映射 -> 动画拆分 -> 弹窗拆分 -> 路由 Provider -> 验证”的顺序推进。
  理由：先建立共享基础，后处理高风险模块，可减少回滚成本。
  日期/作者：2025-03-08 / Codex
- 决策：在 `ActionAnim` 中引入注册表与 handler 模块，先完成行为分离，再继续细拆 handler 文件。
  理由：优先保证调度逻辑稳定，再细化文件规模。
  日期/作者：2025-03-08 / Codex
- 决策：将动画拆分为“单位/提示处理”与“骰子显示”，保证每个文件不超过 300 行。
  理由：符合 CodingDiscipline 的单文件限制并降低理解复杂度。
  日期/作者：2025-03-08 / Codex
- 决策：在缺失 GameAPI 的测试环境中跳过单位创建，避免单元测试崩溃。
  理由：测试目的是验证调度逻辑，不依赖引擎创建单元的成功。
  日期/作者：2025-03-08 / Codex

## 结果与复盘

完成动画拆分与回归用例新增，回归测试通过（123）。

## 背景与导读

表现层集中在 `src/presentation/**`。事件路由入口在 `src/presentation/interaction/UIEventRouter.lua`，意图构建在 `src/presentation/interaction/UIIntentBuilder.lua`，UI 节点绑定在 `src/presentation/interaction/UIEventBindings.lua`。动画播放集中在 `src/presentation/render/ActionAnim.lua`，其 handler 已拆到 `src/presentation/render/ActionAnimHandlers.lua`、`ActionAnimUnits.lua`、`ActionAnimDice.lua`。弹窗与选择屏渲染集中在 `src/presentation/ui/UIModalPresenter.lua`，已拆分为 `ChoiceScreenRenderer`、`PopupRenderer`、`MarketModalRenderer`。节点名与按钮名集中在 `src/presentation/shared/UINodes.lua`。

术语解释：
“节点映射表”指一个 Lua 模块，集中定义 UI 节点名与屏幕名，其他模块只引用映射表的字段；“动画 handler”指处理特定 `anim.kind` 的函数；“渲染器”指只负责将数据写入 UI 的函数集合，不负责流程决策。

## 工作计划

里程碑一已完成：建立节点映射表并替换多处硬编码。里程碑二已完成：动画模块拆分为注册表与 handlers，并继续拆为 `ActionAnimUnits` 与 `ActionAnimDice`。里程碑三已完成：`UIModalPresenter` 拆分为渲染器与流程协调器。里程碑四已完成：UIEventRouter 引入 Provider 注册表。里程碑五已完成：回归测试通过。

## 具体步骤

已完成，无新增步骤。

## 验证与验收

已执行：

    lua .agents/tests/regression.lua

结果：所有回归用例通过（123）。

## 可重复性与恢复

所有步骤为增量拆分，可重复执行。若出现回归，按里程碑逆序回退：先回退 Provider 化，再回退 UIModalPresenter 拆分，再回退 ActionAnim 拆分，最后回退节点映射替换。每次回退后重新运行基础流程验证。

## 产物与备注

新增文件：

    src/presentation/shared/UINodes.lua
    src/presentation/render/ActionAnimRegistry.lua
    src/presentation/render/ActionAnimHandlers.lua
    src/presentation/render/ActionAnimUnits.lua
    src/presentation/render/ActionAnimDice.lua
    src/presentation/ui/ChoiceScreenRenderer.lua
    src/presentation/ui/PopupRenderer.lua
    src/presentation/ui/MarketModalRenderer.lua
    src/presentation/interaction/UIIntentProviders.lua
    .agents/tests/suites/presentation_ui_action_anim.lua

已修改文件：

    src/presentation/interaction/UIEventBindings.lua
    src/presentation/interaction/UIIntentBuilder.lua
    src/presentation/interaction/UICanvasCoordinator.lua
    src/presentation/ui/UIPanelPresenter.lua
    src/presentation/render/ActionAnim.lua
    src/presentation/ui/UIModalPresenter.lua
    src/presentation/interaction/UIEventRouter.lua
    src/presentation/api/UIView.lua
    src/presentation/interaction/UIInputLockPolicy.lua
    src/presentation/interaction/UIEventState.lua
    .agents/tests/regression.lua

回归输出：

    All regression checks passed (123)

## 接口与依赖

新增接口：
- `UINodes`：返回一组常量表，例如 `UINodes.debug.toggle_button`、`UINodes.choice.player.slots`。
- `ActionAnimRegistry.register(kind, handler)`：注册动画处理函数。
- `UIIntentProviders.registry.register(provider)` 与 `UIIntentProviders.registry.build_specs(state)`：提供路由构建扩展点。

变更说明（2025-03-08 / Codex）：完成回归测试与测试环境适配，记录通过结果。
