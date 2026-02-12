# 第四轮：拆分 GameState/TurnFlow/Landing 的职责与依赖


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前回合流程与落地事件处理集中在少数大文件里（`GameState`、`TurnFlow`、`Landing`），职责混杂、依赖方向不清晰，导致规则改动需要跨层修改。此轮目标是拆分职责、把 UI/动画/AI 决策从核心状态修改中剥离，并通过端到端验证证明“行为不变但可维护性提高”。可见结果：核心逻辑只依赖明确接口，落地事件与 UI 展示可独立演进。

## 进度

- [x] (2025-03-04 12:00Z) 明确拆分边界与接口草案。
- [x] (2025-03-04 12:00Z) 拆分 `GameState` 子模块并接入。
- [x] (2025-03-04 12:00Z) 拆分 `TurnFlow` 的决策/状态迁移与 UI 等待。
- [x] (2025-03-04 12:00Z) 拆分 `Landing` 的规则执行与表现层。
- [x] (2025-03-04 12:00Z) 回归与依赖检查验证。

## 意外与发现

- 观察：回归卡住源于 `GameState.new` 递归。
  证据：修复 `GameState.new` 后回归恢复通过。

## 决策日志

- 决策：以“接口先行”的方式拆分核心流程与表现层。
  理由：降低耦合，避免一次性迁移导致行为漂移。
  日期/作者：2025-03-04 / Codex

## 结果与复盘

已完成 GameState/TurnFlow/Landing 拆分并保持行为一致；回归与无 UI 脚本通过，依赖检查通过。拆分后职责更清晰，后续规则改动可在更小模块内完成。

## 背景与导读

当前关键文件：
- `src/game/core/runtime/GameState.lua`：聚合玩家/回合/地块/动画队列等状态读写，并直接调用 UI 或外部 helper。
- `src/game/flow/turn/TurnFlow.lua`：同时承担状态机、自动决策、UI 时序与日志输出。
- `src/game/systems/land/Landing.lua`：落地规则、事件触发、弹窗/动画混在一起。

这些文件同时承担“规则计算”和“表现/交互”，违反 SRP，且高层逻辑依赖底层细节，导致扩展困难。

## 工作计划

先定义最小接口与数据边界：把“状态修改”与“表现/交互”拆分成模块，并在原调用处保留组合逻辑。随后拆出 `GameState` 的子模块（例如玩家状态、回合状态、地块状态），让 `TurnFlow` 只驱动状态迁移与决策，UI 等待/动画推进由独立协调器处理。再把 `Landing` 的 UI 弹窗与动画排队剥离，保留纯规则执行返回结构化结果。最后补齐回归与依赖检查，确保行为不变。

## 具体步骤

1) 定义边界与接口。

在 `src/game/core/runtime/` 新增接口模块（如 `GameStatePlayers.lua`、`GameStateTiles.lua`、`GameStateTurn.lua`），明确每个模块负责的字段与方法。保证原 `GameState` 对外 API 不变，仅改内部委托。

2) 拆分 `GameState`。

把与玩家状态、地块状态、动画队列、车辆状态相关的函数分别移动到新模块，通过组合方式注入到 `game_state`。目标是让每个模块有单一变化原因，且单文件不超过 300 行。

3) 拆分 `TurnFlow`。

新增 `TurnDecision.lua`（自动决策/日志格式化）与 `TurnWaits.lua`（等待状态与动画推进），`TurnFlow` 只负责状态机驱动与调用这些模块。保持现有对外行为不变。

4) 拆分 `Landing`。

把弹窗/动画排队移动到 `LandingPresenter.lua`，`Landing` 只产出“规则结果”（结构化 intent 或待播动画信息）。调用方统一负责表现层执行。

5) 验证与回归。

运行现有脚本，确保行为一致。若出现差异，限定在拆分范围内修正，不引入新功能。

## 验证与验收

在仓库根目录执行：

    lua .agents/tests/regression.lua
    lua .agents/tests/gameplay_loop_no_ui.lua
    lua .agents/tests/dep_rules.lua

预期：全部通过；`gameplay_loop_no_ui.lua` 输出 `tick ok`。

## 可重复性与恢复

拆分保持接口不变，步骤可逐个模块回滚。若某一步引发回归，可暂时恢复为原文件并停止拆分，保证回归可运行。

## 产物与备注

预期新增/修改：

    src/game/core/runtime/GameStatePlayers.lua
    src/game/core/runtime/GameStateTiles.lua
    src/game/core/runtime/GameStateTurn.lua
    src/game/flow/turn/TurnDecision.lua
    src/game/flow/turn/TurnWaits.lua
    src/game/systems/land/LandingPresenter.lua
    src/game/core/runtime/GameState.lua
    src/game/flow/turn/TurnFlow.lua
    src/game/systems/land/Landing.lua

## 接口与依赖

- `GameState` 仍是对外入口，但内部通过组合调用子模块。
- `TurnFlow` 只依赖 `TurnDecision` 与 `TurnWaits` 的公开函数。
- `Landing` 只返回规则结果，`LandingPresenter` 执行 UI/动画。

---

变更说明（2025-03-04 / Codex）：清空旧计划，写入“职责拆分与依赖方向”第四轮计划。

变更说明（2025-03-04 / Codex）：完成全部步骤与验证，记录阻塞原因与修复结果。
