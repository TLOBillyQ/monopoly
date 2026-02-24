# 架构收敛：压平抽象层、降低改动扩散

本可执行计划是活文档。实施过程中必须持续更新"进度""意外与发现""决策日志""结果与复盘"。

本文件遵循 `.github/PLANS.md` 的维护要求。调研报告来源：`.github/docs/reports/research.md`。


## 目的 / 全局视角

调研（`.github/docs/reports/research.md`）确认：当前架构方向合理（状态机 + dirty 增量刷新），但实现层数过厚。问题不是"模块多"，而是"抽象层之间缺少语义增量 + 主循环职责过载 + 一条常见改动链路跨太多文件"。这导致新增一个按钮、改一个展示字段、排查一个启动失败，都需要跨多个薄封装文件追踪。

本计划的目标是**原地收敛**，不新建 `src_next/`，不改功能，只压层数。完成后用户可见结果是：

1. 新增一个 UI 按钮语义，只需改 1-2 个文件（而非 4-5 个）。
2. 改一个展示字段，只需改 `UIModel.lua`（而非跨 `UIModelProjection` + `UIModelPanelBuilder` + `UIModel` 三处）。
3. `lua .github/tests/regression.lua` 通过数不减少（当前基线 154）。
4. `ARCHITECTURE.md` 同步更新，新人阅读路径缩短。

如何看到它在工作：每完成一个里程碑，运行回归，通过数 >= 154；再检查被收敛的文件已删除或合并，改动链路变短。


## 进度

- [x] (2026-02-24 11:19Z) 阅读调研报告，确认 H1-H4 / M1-M3 问题分级。
- [x] (2026-02-24 11:19Z) 回归基线确认：`lua .github/tests/regression.lua` -> 154 通过，dep_rules ok，tick ok。
- [ ] 里程碑 M0：冻结基线与行为清单。
- [ ] 里程碑 M1：压平 interaction 链（H3 + M1 部分）。
- [ ] 里程碑 M2：收敛 UI 投影链（M3）。
- [ ] 里程碑 M3：删薄封装、保留硬边界（M1 + H4 部分）。
- [ ] 收尾：更新 `ARCHITECTURE.md`，最终回归。


## 意外与发现

- 观察：回归基线当前为 154，此前记忆记录的 136/142 已过时。
  证据：`lua .github/tests/regression.lua` -> `All regression checks passed (154), dep_rules ok, tick ok`。

- 观察：`UIIntentBuilder.lua`（43 行）是纯转发门面，每个方法只调对应子模块的 `.build()`，无额外逻辑。
  证据：`src/presentation/interaction/UIIntentBuilder.lua` 全部 9 个函数都是 `return xxx.build(state)`。

- 观察：`TurnActionPortAdapter.lua`（17 行）和 `TurnActionPort.lua`（23 行）合计 40 行，只做把 `TurnDispatch` 包成端口对象 + 空默认值。
  证据：`src/app/ports/TurnActionPortAdapter.lua`、`src/presentation/api/TurnActionPort.lua`。

- 观察：`MarketService.lua`（19 行）只是把 4 个子模块函数赋值到一张聚合表上，无独立语义。
  证据：`src/game/systems/market/MarketService.lua`。

- 观察：`GameplayLoopPortsAdapter.lua`（20 行）只组合 5 个子 ports 模块返回一张表。
  证据：`src/presentation/api/GameplayLoopPortsAdapter.lua`。


## 决策日志

- 决策：放弃"双轨重写"路线，改为原地收敛（M0-M3）。
  理由：调研结论是"过度抽象，不是错误架构"。原地删层比新建 `src_next/` 风险更低，改动更小，且测试保护网已足够。
  日期/作者：2026-02-24 / agent。

- 决策：收敛顺序为 interaction 链 -> UI 投影链 -> 薄封装清理。
  理由：interaction 链是当前改动扩散最大的区域（H3），优先压平收益最高。UI 投影链次之（M3）。薄封装清理放最后，因为前两步可能已自然消除部分薄层。
  日期/作者：2026-02-24 / agent。

- 决策：`GameplayLoop.tick` 职责过载问题（H2）不在本计划范围内做拆分。
  理由：tick 拆子函数文件是重构，不是删层；且当前 tick 已由 `GameplayLoopRuntime` 辅助，风险可控。优先做收益最大的"删层"。后续可专项拆解。
  日期/作者：2026-02-24 / agent。

- 决策：启动链拆分过细问题（H4）在 M3 阶段评估是否合并，不单独设里程碑。
  理由：启动链 5 个模块各有独立职责（安装运行时、构建状态、桥接事件、启动 UI、启动 tick），合并风险需要逐个评估。放到 M3 按"是否有独立语义"标准判断。
  日期/作者：2026-02-24 / agent。


## 结果与复盘

本节在所有里程碑完成后填写。完成标准：
1. 回归通过数 >= 154。
2. `dep_rules` 和 `gameplay_loop_no_ui` 通过。
3. 被合并或删除的薄封装文件列表明确。
4. `ARCHITECTURE.md` 反映新的模块结构。


## 背景与导读

以下为与本计划直接相关的现有代码结构，面向完全不了解仓库的读者。

**项目入口**：`main.lua` 加载 `src/app/init.lua`。启动经过 `RuntimeInstall`（安装运行时）-> `GameStartup`（构建状态）-> `UIBootstrap`（GAME_INIT 回调）-> `GameRuntimeBootstrap`（注入 ports、创建游戏、启动 tick）。这些文件在 `src/app/bootstrap/`。

**主循环**：`src/game/flow/turn/GameplayLoop.lua` 每帧执行 `tick(game, state, dt)`，协调输入锁、自动执行、超时、动画、脏刷新。它不直接依赖 UI 节点，而是通过 `GameplayLoopPorts`（`src/game/flow/turn/GameplayLoopPorts.lua`）定义的 6 组端口接口（modal/anim/ui_sync/debug/clock/state）间接调用。端口的默认实现在 `GameplayLoopPorts.lua` 内部，真实实现由 `GameplayLoopPortsAdapter`（`src/presentation/api/GameplayLoopPortsAdapter.lua`，20 行）组合 5 个子模块（`src/presentation/api/ports/` 目录下的 `ModalPorts/AnimPorts/UISyncPorts/DebugPorts/StatePorts`）。

**UI 交互链（本计划的主要收敛目标）**：用户点击某个 UI 节点后，事件经过如下多跳：
1. `UIEventRouter.lua`（`src/presentation/interaction/`）注册节点点击，调用 `UIIntentBuilder` 获取意图规范列表。
2. `UIIntentBuilder.lua`（43 行，纯转发门面）委托给 `intent_builders/` 下的 6 个子模块（`BasicIntents`、`ActionLogIntents`、`PopupIntents`、`ItemSlotIntents`、`ChoiceIntents`、`MarketIntents`）。
3. 每个子模块返回 `{ name, build_intent }` 数组。`UIEventRouter` 用 `UIEventBindings` 把它们注册为节点点击回调。
4. 回调触发时，构造出 intent 对象，交给 `UIIntentDispatcher.lua`（193 行）分流：游戏动作走 `TurnActionPort` -> `TurnDispatch`；纯视图命令直接执行。
5. `TurnActionPort.lua`（23 行）提供空默认值 + resolve 逻辑；`TurnActionPortAdapter.lua`（17 行）把 `TurnDispatch` 包成端口对象。

问题：新增一个按钮语义，需要：(a) 新增一个 `intent_builders/XxxIntents.lua`；(b) 在 `UIIntentBuilder.lua` 加一个转发方法；(c) 在 `UIEventRouter._build_default_route_specs` 加一行 `_append`；(d) 可能在 `UIIntentDispatcher` 加分支。共 4 个文件。

**UI 投影链**：领域状态经过如下路径变为 UI 数据：`UIModelProjection.lua`（投影函数集合）+ `UIModelPanelBuilder.lua`（面板数据构建）-> `UIModel.lua`（读模型）。改一个展示字段需要跨 3 个文件找依赖。这三个文件在 `src/presentation/state/`。

**回归入口**：`lua .github/tests/regression.lua`，当前通过 154 项。附带执行 `dep_rules`（依赖方向检查）和 `gameplay_loop_no_ui`（无 UI tick 测试）。


## 工作计划

### 里程碑 M0：冻结基线与行为清单

在任何结构改动之前，先记录"什么算不退化"。运行回归并记录输出作为证据。产出一份必须始终常绿的验收命令列表。不改任何代码。

完成标志：回归通过证据写入本计划"产物与备注"；验收命令列表固化。

### 里程碑 M1：压平 interaction 链

把 `UIIntentBuilder` + `intent_builders/*` + `UIEventRouter._build_default_route_specs` 的多层跳转收敛成单入口。具体做法是：

1. **删除 `UIIntentBuilder.lua`（纯转发门面）**。它的 9 个方法各只调一次对应子模块的 `.build()`，没有组合、过滤、变换逻辑。
2. **在 `UIEventRouter.lua` 的 `_build_default_route_specs` 中直接 require 各 `intent_builders/*` 并调用 `.build()`**。即把原来 `ui_intent_builder.build_basic_intents(state)` 替换为 `basic_intents.build(state)`。这消除中间层，减少一跳。
3. **评估 `TurnActionPortAdapter.lua` + `TurnActionPort.lua` 能否合并为 `TurnDispatch` 上的直接调用**。`UIIntentDispatcher.lua` 当前通过 `TurnActionPort.resolve()` 获取端口再调 `dispatch_action`。如果把 resolve 逻辑内联到 `UIIntentDispatcher` 中（10 行左右），可以删除 `TurnActionPort.lua` 和 `TurnActionPortAdapter.lua` 两个文件。但需注意 `GameplayLoop.lua` 也通过 ports 间接使用 `TurnDispatch`，那条路径不经过 `TurnActionPort`，所以删除不影响它。

这一步完成后，新增一个按钮语义只需：(a) 新增或修改一个 `intent_builders/XxxIntents.lua`；(b) 在 `UIEventRouter._build_default_route_specs` 加一行 `_append(xxx.build(state))`。从 4 个文件降到 2 个。

完成标志：`UIIntentBuilder.lua` 已删除；`TurnActionPortAdapter.lua` 和 `TurnActionPort.lua` 已合并或删除；回归通过 >= 154。

### 里程碑 M2：收敛 UI 投影链

把 `UIModelProjection.lua` 和 `UIModelPanelBuilder.lua` 的核心逻辑并入 `UIModel.lua`。具体做法是：

1. **`UIModelPanelBuilder.lua` 的 `build` 和 `update` 内联到 `UIModel.lua`**。`UIModelPanelBuilder` 只被 `UIModel` 调用，没有其他消费者。它的逻辑（构建回合标签、玩家行、自动标签）可以直接写在 `UIModel` 的 `build` 和 `update` 函数内部。
2. **`UIModelProjection.lua` 的简单投影函数（如 `resolve_current_player`、`board_tiles`、`resolve_item_slot_count`、`build_item_slots_by_player`）内联到 `UIModel.lua`**。如果 `UIModelProjection` 中某些函数被其他模块引用（不只是 `UIModel`），则保留该函数在 `UIModelProjection` 中，不强制内联。
3. 删除已清空的文件。

这一步完成后，改一个展示字段只需在 `UIModel.lua` 中修改，不再跨 3 个文件。

完成标志：`UIModelPanelBuilder.lua` 已删除或清空；`UIModelProjection.lua` 被显著缩减或删除；回归通过 >= 154。

### 里程碑 M3：删薄封装、保留硬边界

逐个评估 `src/` 中行数 <= 25 且命中抽象命名模式（Adapter/Port/Service/Builder/Presenter）的文件。对每个文件判断：它是否提供独立语义（边界隔离、默认值、错误处理），还是只做单纯转发。只删只做单纯转发的文件。

调研列出的候选清单（按风险从低到高）：

1. `src/presentation/api/GameplayLoopPortsAdapter.lua`（20 行）：只组合 5 个子 ports 返回一张表。如果调用方只有 `GameRuntimeBootstrap.lua`，可以把组合逻辑内联到那里。
2. `src/presentation/api/ports/ModalPorts.lua`（约 21 行）：只把 `UIViewService` 的 3 个方法包成 ports 表。可以内联到组合处。
3. `MarketService.lua`（19 行）：只做 4 个子模块的赋值聚合。如果调用方可以直接 require 子模块，则删除此门面。但需检查是否有多个调用方依赖 `MarketService` 提供的统一命名空间。
4. 启动链模块（`RuntimeInstall.lua` 22 行）：虽然行数少，但它有独立语义（安装运行时上下文），保留不删。

每删一个文件，立即跑回归。如果失败，回退该文件。

完成标志：删除的文件列表记录在"产物与备注"；回归通过 >= 154；`dep_rules` 和 `gameplay_loop_no_ui` 通过。


## 具体步骤

工作目录：`/home/runner/work/monopoly/monopoly`（CI 环境）或本地克隆根目录。

**M0 步骤**：

    lua .github/tests/regression.lua

预期输出包含 `All regression checks passed (154)`、`dep_rules ok`、`tick ok`。把这段输出记录到"产物与备注"。

**M1 步骤**：

1. 在 `src/presentation/interaction/UIEventRouter.lua` 顶部，把 `require("src.presentation.interaction.UIIntentBuilder")` 替换为直接 require 各 `intent_builders/*`。把 `_build_default_route_specs` 中的 `ui_intent_builder.build_xxx(state)` 替换为对应的 `xxx.build(state)`。
2. 删除 `src/presentation/interaction/UIIntentBuilder.lua`。
3. 在 `src/presentation/interaction/UIIntentDispatcher.lua` 中，把 `_resolve_turn_action_port` 的 resolve 逻辑从 `TurnActionPort.resolve()` 内联为本地函数。
4. 删除 `src/presentation/api/TurnActionPort.lua` 和 `src/app/ports/TurnActionPortAdapter.lua`。
5. 检查是否有其他文件引用了 `TurnActionPort` 或 `TurnActionPortAdapter`：

        grep -rn "TurnActionPort" src/

   如果有其他引用方，保留被引用的模块或把引用替换为直接调用 `TurnDispatch`。

6. 跑回归：`lua .github/tests/regression.lua`。

**M2 步骤**：

1. 查找 `UIModelProjection` 和 `UIModelPanelBuilder` 的所有引用方：

        grep -rn "UIModelProjection" src/
        grep -rn "UIModelPanelBuilder" src/

2. 如果只有 `UIModel.lua` 引用它们，把它们的函数体搬入 `UIModel.lua`，删除源文件。
3. 如果有其他引用方，把共享函数保留在 `UIModelProjection.lua`，只合并 `UIModelPanelBuilder`。
4. 跑回归。

**M3 步骤**：

1. 对每个候选文件，先 grep 确认引用方数量和位置，再决定内联目标，再删除并跑回归。
2. 每删一个文件独立提交，方便单点回退。

**收尾**：

1. 更新 `ARCHITECTURE.md`，把已删模块从"分层与职责"和"扩展点"中移除，把新的改动链路写清楚。
2. 最终全量回归：

        lua .github/tests/regression.lua

   加跑：

        lua .github/tests/internal/dep_rules.lua
        lua .github/tests/internal/gameplay_loop_no_ui.lua


## 验证与验收

验收以"改动链路变短 + 回归不退化"为准。必须同时满足：

1. `lua .github/tests/regression.lua` 通过数 >= 154。
2. `dep_rules` 通过（依赖方向未被破坏）。
3. `gameplay_loop_no_ui` 通过（无 UI tick 仍正常）。
4. 新增一个按钮语义只需改 2 个文件（而非 4-5 个）。这通过检查 `UIEventRouter` 和 `intent_builders/` 的结构来验证：不再有 `UIIntentBuilder.lua` 中间层。
5. 改一个展示字段只需改 `UIModel.lua`（而非跨 3 个文件）。这通过检查 `UIModelPanelBuilder.lua` 已不存在来验证。
6. `ARCHITECTURE.md` 反映当前结构。


## 可重复性与恢复

本计划的每个里程碑都是原地改动 + 删文件。恢复方式是 `git checkout -- <被删文件路径>`，再跑回归确认恢复成功。每个里程碑独立提交，失败时可按提交粒度回退。

跑回归是幂等操作，可任意重复。如果某一步回归失败，先用 `git diff` 检查改动范围，缩小排查面。


## 产物与备注

基线证据（M0 完成后填写）：

    lua .github/tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok

M1 删除的文件（M1 完成后填写）：

    （待填）

M2 删除/合并的文件（M2 完成后填写）：

    （待填）

M3 删除的文件（M3 完成后填写）：

    （待填）


## 接口与依赖

本计划不新增接口或依赖，只删除中间层。收敛后保留的硬边界模块：

1. `src/game/flow/turn/GameplayLoop.lua`：主循环，不动。
2. `src/game/flow/turn/TurnDispatch.lua`：动作分发，不动。
3. `src/core/DirtyTracker.lua`：脏标记，不动。
4. `src/core/Flow.lua`：状态机步进器，不动。
5. `src/game/core/runtime/Game.lua`：领域门面，不动。
6. `src/presentation/api/UIViewService.lua`：UI 渲染门面，不动。
7. `src/presentation/interaction/UIEventRouter.lua`：收敛后成为 interaction 单入口。
8. `src/presentation/interaction/UIIntentDispatcher.lua`：intent 分流，内联 resolve 后变简单。
9. `src/presentation/state/UIModel.lua`：收敛后成为 UI 状态单入口。

被删除或合并的中间层（计划值，实际以执行为准）：

1. `src/presentation/interaction/UIIntentBuilder.lua` -> 删除（转发内联到 `UIEventRouter`）。
2. `src/presentation/api/TurnActionPort.lua` -> 删除（resolve 内联到 `UIIntentDispatcher`）。
3. `src/app/ports/TurnActionPortAdapter.lua` -> 删除（不再需要端口对象）。
4. `src/presentation/state/UIModelPanelBuilder.lua` -> 合并到 `UIModel.lua`。
5. `src/presentation/state/UIModelProjection.lua` -> 部分或全部合并到 `UIModel.lua`。
6. `src/presentation/api/GameplayLoopPortsAdapter.lua` -> 评估后决定。
7. `src/game/systems/market/MarketService.lua` -> 评估后决定。


## 本次更新说明

本次更新将 `PLAN_CURRENT.md` 从"全量重写路线图（src_next 双轨）"改写为"原地收敛路线图（M0-M3）"。改写原因：调研报告（`.github/docs/reports/research.md`）确认当前架构方向合理，问题是层数过厚而非架构错误。原地删层比新建平行目录风险更低、改动更小、验证更简单。新计划聚焦调研报告的 H3（交互链过深）、M1（薄封装比例偏高）、M3（投影链过碎）三个问题，按收益降序排列里程碑。
