# 重构执行计划：解耦回合流程与 UI 依赖

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

把回合流程从 UI/运行时细节中解耦，降低高层策略对低层实现的依赖，让核心流程可被独立测试与替换。完成后应当能用“无 UI 端口”跑通回合推进与选择流程，同时 UI 仍可通过适配层正常驱动。验证方式是：在现有 UI 下功能不变；新增的无 UI 端口测试或脚本可推进回合并触发选择处理；手动或脚本可观察到日志与状态变化。

## 进度

- [x] (2025-03-08 09:05Z) 清空旧计划并建立新计划骨架。
- [x] (2025-03-08 09:10Z) 梳理当前回合流程与 UI 依赖点。
- [x] (2025-03-08 09:15Z) 设计并实现 GameplayPorts 抽象与默认实现。
- [x] (2025-03-08 09:25Z) 拆分 UIEventRouter 职责并迁移路由/意图/派发。
- [x] (2025-03-08 09:35Z) 拆分 CompositionRoot 的工厂与注册职责。
- [x] (2025-03-08 09:40Z) 拆分 TurnFlow 的选择处理与日志职责。
- [ ] (2025-03-08 09:40Z) 增补测试与验证脚本。

## 意外与发现

- 暂无。

## 决策日志

- 决策：优先做“端口抽象 + 事件路由拆分”，其余拆分作为后续里程碑。
  理由：对耦合风险下降最大，且对现有 UI 影响可控。
  日期/作者：2025-03-08 / Codex

## 结果与复盘

已完成端口抽象与主要模块拆分，待补充测试验证。

## 背景与导读

回合推进入口在 `src/game/flow/turn/GameplayLoop.lua`，其中通过 `GameplayLoopPorts` 与 `GameplayLoopPortsAdapter` 访问 UI 与运行时细节。当前 `GameplayLoop` 在 `set_game`/`tick` 中直接调用 UI 端口的状态、输入锁、弹窗与渲染逻辑，导致高层流程对 UI 细节耦合严重。UI 事件入口在 `src/presentation/interaction/UIEventRouter.lua`，该文件同时负责节点绑定、意图构造、业务派发、调试开关与节流，职责混杂。`src/game/core/runtime/CompositionRoot.lua` 同时承担对象创建、注册、阶段编排、游戏初始化。`src/game/flow/turn/TurnFlow.lua` 同时负责状态机推进与 choice 处理、日志记录。

术语解释：
- “端口”指以函数集合形式抽象的依赖层接口，用于在领域层与 UI/运行时细节之间解耦。
- “无 UI 端口”指不依赖 UI 层的端口实现，用于测试或服务器模拟。
- “意图”指 UI 事件转换出的领域动作（如 `ui_button`、`choice_select`）。

## 工作计划

首先创建 `GameplayPorts` 抽象与默认空实现，将 `GameplayLoop` 对 UI 端口的直接依赖收敛为接口调用；将 UI 相关实现保留在 `GameplayLoopPortsAdapter`。完成后确保 `GameplayLoop` 在没有 UI 端口时仍能执行核心回合推进逻辑，且不会访问不存在的 UI 状态。然后拆分 `UIEventRouter`：把节点绑定留在路由层、意图构造移到新模块、派发逻辑移到新模块；保持现有功能行为一致。接着拆分 `CompositionRoot`：把对象创建、注册、相位表构建拆为独立模块并保留原入口，避免对外接口变化。最后拆分 `TurnFlow` 中 choice 处理与日志，保留状态机推进职责，新增测试脚本验证“无 UI 端口”与基础流程。

## 具体步骤

1) 端口抽象与默认实现  
在 `src/game/flow/turn/` 新增 `GameplayPorts.lua`，定义 `resolve` 与默认空实现。把 `GameplayLoop` 依赖的端口方法集中列出并提供空实现；`GameplayLoop` 中任何直接使用 `GameplayLoopPortsAdapter` 的位置改为依赖该端口抽象。更新 `GameplayLoopPortsAdapter` 只负责提供 UI 实现。

2) UIEventRouter 拆分  
新增 `src/presentation/interaction/UIIntentBuilder.lua`，只负责从状态+输入构造意图。新增 `src/presentation/interaction/UIIntentDispatcher.lua`，只负责把意图交给 `TurnDispatch` 或 UI 操作。`UIEventRouter` 仅保留节点绑定与调试开关入口。保证旧节点名与行为保持一致。

3) CompositionRoot 拆分  
新增 `src/game/core/runtime/GameFactory.lua`（创建 board/players/rng）、`src/game/core/runtime/PhaseRegistry.lua`（构建 phases）、`src/game/core/runtime/Bootstrap.lua`（注册 items/choices/chance）。`CompositionRoot.assemble` 变为编排调用，行为保持一致。

4) TurnFlow 拆分  
新增 `src/game/flow/turn/TurnChoiceHandler.lua` 与 `src/game/flow/turn/TurnLogger.lua`，`TurnFlow` 中选择处理与日志改为调用这两个模块。

5) 测试与验证  
新增一个最小脚本或测试：创建 game，使用无 UI 端口，调用 `game:advance_turn()` 进入回合并触发 `pending_choice` 的处理路径，观察日志或状态变化。确保 UI 模式下功能不变。

## 验证与验收

1) 运行最小验证脚本，预期回合推进、无 UI 端口无报错。  
2) 在现有 UI 环境中运行回归流程：进入游戏、点击行动按钮、触发选择、确认 UI 行为不变。  
3) 若已有测试框架，运行 `agents/tests/` 下相关脚本，确保通过。

## 可重复性与恢复

变更主要为模块拆分与端口抽象，可重复执行。若出现回归问题，按模块逐一回退：先回退 `UIEventRouter` 拆分，再回退 `GameplayPorts` 抽象，最后回退 `CompositionRoot` 与 `TurnFlow` 拆分。

## 产物与备注

预期新增文件：

    src/game/flow/turn/GameplayPorts.lua
    src/presentation/interaction/UIIntentBuilder.lua
    src/presentation/interaction/UIIntentDispatcher.lua
    src/game/core/runtime/GameFactory.lua
    src/game/core/runtime/PhaseRegistry.lua
    src/game/core/runtime/Bootstrap.lua
    src/game/flow/turn/TurnChoiceHandler.lua
    src/game/flow/turn/TurnLogger.lua

预期修改文件：

    src/game/flow/turn/GameplayLoop.lua
    src/game/flow/turn/GameplayLoopPortsAdapter.lua
    src/presentation/interaction/UIEventRouter.lua
    src/game/core/runtime/CompositionRoot.lua
    src/game/flow/turn/TurnFlow.lua

## 接口与依赖

新增接口：
- `GameplayPorts.resolve(override_ports)` 返回包含默认方法的端口对象。

`GameplayLoop` 只依赖 `GameplayPorts` 抽象，不直接引用 UI 实现。

变更说明（2025-03-08 / Codex）：创建重构执行计划，明确端口解耦与模块拆分路线。

变更说明（2025-03-08 / Codex）：修正进度状态，记录完成骨架构建。

变更说明（2025-03-08 / Codex）：完成端口与模块拆分，待补充测试验证。
