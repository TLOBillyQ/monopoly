# Monopoly 代码库 Clean Architecture 深度研究（2026-03-01）

技能使用：`clean-architecture-reviewer`

## 研究范围与证据

- 扫描范围：`src/*`、`tests/internal/*`、`docs/architecture/*`。
- 实测回归：`lua tests/regression.lua`，结果为 `All regression checks passed (187)`，并且 `dep_rules ok / tick ok / forbidden_globals ok`。
- 代码规模（Lua）：
  - `src/core` 8 文件 / 887 行
  - `src/game/core` 21 文件 / 1447 行
  - `src/game/flow` 19 文件 / 2214 行
  - `src/game/runtime_coroutine` 5 文件 / 394 行
  - `src/game/systems` 52 文件 / 4507 行
  - `src/presentation` 97 文件 / 5958 行
  - `src/app` 7 文件 / 452 行

> **[R] 代码规模：全部精确命中，已独立复现验证。✓**

- 目录级依赖矩阵（摘录）：
  - ~~`presentation -> game/*` 存在 6 条直接依赖（`game/core` 1，`game/flow` 2，`game/systems` 3）。~~
  - `presentation -> game/*` 存在 **5** 条直接依赖（`game/core` 1，`game/flow` 2，`game/systems` **2**）。
  - `game/core -> game/flow` 存在 4 条直接依赖（`PhaseRegistry` -> `TurnStart/Roll/Move/Land`）。
  - `game/core -> game/runtime_coroutine` 存在 3 条直接依赖（`TurnEngine`）。

> **[R] 依赖矩阵：`game/core->flow` 4条 ✓、`game/core->runtime_coroutine` 3条 ✓。**
> **`presentation->game/systems` 实际为 2 条（`LandPricing` + `VehicleFeature`），原文误计为 3，总数应为 5 而非 6。已修正。**

## 系统策略与用例提炼

### Enterprise Rules（企业级规则）

- 玩家资产与生存规则：现金、地块、破产淘汰、胜利判定（`src/game/core/player/*`、`src/game/core/runtime/GameVictory.lua`、`src/game/core/runtime/Bankruptcy.lua`）。
- 棋盘与地块规则：路径推进、分支、地价/租金/连片租金（`src/game/systems/board/*`、`src/game/systems/land/LandRules.lua`）。
- 道具/机会/市场规则：效果执行、可选决策、购买资格（`src/game/systems/items/*`、`src/game/systems/chance/*`、`src/game/systems/market/*`）。

> **[R] Enterprise Rules 归类合理。`player/*` 和 `LandRules` 是纯规则，无外部依赖；`items/chance/market` 部分文件含编排逻辑（如 ItemPhase），可考虑进一步区分。✓**

### Application Rules（应用级用例）

- 回合主流程：`start -> roll -> move -> landing -> post_action -> end_turn`（`src/game/core/runtime/PhaseRegistry.lua` + `src/game/flow/turn/*`）。
- 协程调度与等待态：`wait_choice / wait_move_anim / wait_action_anim / detained_wait`（`src/game/runtime_coroutine/*`）。
- 输入动作分发：`ui_button / choice_select / choice_cancel` 到领域动作（`src/game/flow/turn/TurnDispatch.lua`）。
- UI 同步与超时控制：倒计时、modal 自动关闭、输入锁（`src/game/flow/turn/TickTimeout.lua`、`TickUISync.lua`，由 `PresentationPorts` 调用）。

> **[R] Application Rules 准确。PhaseRegistry.build_default_phases 确认了 6 阶段流程。注意 PhaseRegistry 在 `game/core` 但依赖 `game/flow`，这正是 P1 所指出的矛盾。✓**

## 分层映射（当前状态）

- Entities（偏内层）：`game/core/player`、`game/systems/board`、`game/systems/land/LandRules` 中的纯规则部分。
- Use Cases（中层）：`game/flow/turn`、`game/runtime_coroutine`、`game/systems/*` 的编排与决策逻辑。
- Interface Adapters（外层）：`presentation/*`、`app/bootstrap/*`、`presentation/api/PresentationPorts.lua`。
- Frameworks & Drivers（最外层）：Eggy `GameAPI/LuaAPI`、全局事件函数、`Config/*`、`vendor/third_party/*`。

结论：项目已经有端口化意识（`GameplayLoopPorts` / `PresentationPorts`）与可无 UI 运行测试（`tests/internal/gameplay_loop_no_ui.lua`），但圈层边界仍存在多处反向穿透。

> **[R] 分层映射准确。`GameplayLoopPorts` 已体现六组端口（modal/anim/ui_sync/debug/clock/state），结构化程度优于典型 Lua 项目。`PresentationPorts.build()` 提供具体适配实现，是合格的 Interface Adapter 形态。✓**

## 架构结论

当前架构已具备“可测试的用例主线”和“端口适配器雏形”，但尚未满足 Clean Architecture 的核心依赖约束。主要阻碍是内层仍直接依赖框架全局（`GameAPI/SetTimeOut/Register*`）与 UI 运行状态对象，导致规则层受外部细节牵引。整体可通过增量方式演进，无需一次性推倒重来。

> **[R] 结论准确且务实。"增量演进"定位与 PLAN_CURRENT 原地收敛路线一致。✓**

## 主要问题（P0-P3）

- P0: 核心业务直接调用框架全局，Dependency Rule 被打穿。
  - 证据 1：`src/game/core/runtime/GameFactory.lua:15-16` 在 RNG 中直接断言并调用 `GameAPI.random_int`。
  - 证据 2：`src/game/core/runtime/Bankruptcy.lua:91-95` 在淘汰逻辑中直接 `GameAPI.get_role(...).lose()`。
  - 证据 3：`src/game/flow/turn/TurnAnim.lua:25` 直接调用 `SetTimeOut` 驱动状态迁移。
  - 风险：核心用例无法脱离 Eggy 运行时独立替换/复用，且框架异常会直接污染业务路径。

> **[R] P0 全部证据精确命中。**
> - 证据 1：GameFactory.lua:15 assert(GameAPI and GameAPI.random_int), :16 return GameAPI.random_int(min, max) ✓
> - 证据 2：Bankruptcy.lua:91-95 if GameAPI and GameAPI.get_role then … role.lose() ✓
> - 证据 3：TurnAnim.lua:25 SetTimeOut(delay, function() … end) ✓
> - 补充：Bankruptcy 已做防御性 if GameAPI 判断，重构时可直接抽为端口注入。TurnAnim 的 SetTimeOut 是唯一的全局定时器调用点，可单点替换。

- P1: 用例层与适配层边界混杂，UI 细节回流到用例编排。
  - 证据 1：`src/game/flow/turn/GameplayLoop.lua:90` 直接把 `state` 赋给 `game.ui_port`，`:91` 又挂载 `game.gameplay_loop_ports`。
  - 证据 2：`src/presentation/api/PresentationPorts.lua:4-5` 反向依赖 `game/flow` 的 `TickTimeout` 与 `TickUISync`，导致 adapter 反向携带 use-case 实现。
  - 风险：任何 UI 交互/渲染改动都更容易扩散到回合循环。

> **[R] P1（边界混杂）证据准确。**
> - 证据 1：GameplayLoop _initialize_ports 第 90 行 game.ui_port = state、第 91 行 game.gameplay_loop_ports = ports ✓
> - 证据 2：PresentationPorts.lua:4-5 反向引用 TickTimeout / TickUISync，违反 Dependency Rule ✓
> - 补充：PresentationPorts 还引用了 CanvasStore(:6)、UIEventState(:7)，这些属同层引用，无违规。

- P1: “core” 命名层并非真正内层，职责与依赖方向不一致。
  - 证据 1：`src/game/core/runtime/PhaseRegistry.lua:3-6` 依赖 `src.game.flow.turn.*`。
  - 证据 2：`src/game/core/runtime/TurnEngine.lua:1-3` 依赖 `runtime_coroutine` 实现细节。
  - 风险：目录语义误导，后续贡献者更难判断可改动边界。

> **[R] P1（core 命名）证据准确。**
> - PhaseRegistry:3-6 依赖 TurnStart/Roll/Move/Land（均在 game.flow.turn） ✓
> - TurnEngine:1-3 依赖 Scheduler/Session/ActionRouter（均在 game.runtime_coroutine） ✓
> - 补充：core->flow 4条 + core->runtime_coroutine 3条 = 7条反向引用。把 PhaseRegistry+TurnEngine 外移到 flow 层即可全部清除。

- P2: 端口抽象存在，但端口默认实现夹带框架细节。
  - 证据：`src/game/flow/turn/GameplayLoopPorts.lua:102-121` 在 `clock` 默认端口直接读 `GameAPI`。
  - 风险：测试替身与生产实现语义不稳定，端口“默认行为”不可预测。

> **[R] P2（端口默认）论点成立，行号微调。**
> - `_base_clock_ports()` 实际位于 99-129 行（原文 102-121 偏窄）。`now` :102 调用 `GameAPI.get_timestamp`，`diff_seconds` :117 调用 `GameAPI.get_timestamp_diff` ✓
> - 补充：clock 默认含 `os.clock` 回退路径(:109)，语义上不等价于 `GameAPI.get_timestamp`（wall-clock vs CPU time），可能导致测试/生产计时偏差。建议拆为两个显式实现，去掉 fallback。

- P2: 架构规则测试覆盖面不足，无法防止关键违例回归。
  - 证据：`tests/internal/dep_rules.lua:1-31` 仅检查少量历史禁用依赖与 canvas 规则，未约束 `GameAPI/SetTimeOut` 的使用边界，也未约束 `core -> flow`。
  - 风险：依赖方向持续漂移时，CI 仍可能全部通过。

> **[R] P2（dep_rules）准确。当前 5 条规则聚焦退役模块和 canvas 隔离，确实未约束全局 API 边界与 core->flow 方向。✓**

- P3: `state` 顶层字段过多（`GameStartup.build_state`），语义聚合不足。
  - 证据：`src/app/bootstrap/GameStartup.lua` 构建单一大状态包并被多个层共享读写。
  - 风险：可读性下降、字段冲突概率上升、局部重构成本偏高。

> **[R] P3 准确。build_state 返回的 state 表含 30+ 顶层字段(:79-142)，混合 UI/动画/回合运行时/调试四类关注点，缺乏命名空间隔离。✓**

## 重构方案

以下方案按"最小可落地 + 可回滚"顺序设计。

> **[R] 方案排序评审：建议将方案 5（守护测试）前置到第 1 步。先写测试再改结构是 TDD 原则的自然延伸，且风险最低、可立即锁定退化基线。当前排序把它放在最后，容易在前 4 步改动过程中引入无守护的依赖漂移。**

1. 建立运行时输入端口，先替换 P0 直连点。
   - 动作：在用例层定义 `runtime_ports`（`rng.now/diff/schedule/get_role/emit_event`），由 `RuntimeInstall` 提供 Eggy 适配实现；`GameFactory`、`Bankruptcy`、`TurnAnim` 改为依赖端口。
   - 影响范围：`game/core/runtime`、`game/flow/turn`、`app/bootstrap`。
   - 预期收益：核心业务不再直接依赖全局 API，单测可完全替身化。
   - 回归风险：中等（初始化链路变化）；回滚点为"保留旧全局读取 fallback 一版"。

> **[R] 方案 1 合理。端口签名建议区分 `rng`（纯函数）和 `platform`（`schedule/get_role/emit_event`），避免单一端口过大。`rng` 只需 `next_int(min,max)`，可直接从 GameFactory._new_rng 提取。✓**

2. 把 `core/runtime` 中的流程编排外移到 use-case 层。
   - 动作：将 `PhaseRegistry`、`TurnEngine` 语义上归到 `game/flow`（或 `game/runtime`）；`Game` 仅保留实体状态与状态变更操作。
   - 影响范围：`Game.lua`、`PhaseRegistry.lua`、`TurnEngine.lua`、启动装配。
   - 预期收益：目录语义与依赖方向一致，降低误改风险。
   - 回归风险：中等；回滚点为"保留兼容 require 代理文件"。

> **[R] 方案 2 合理。移动后可消除全部 7 条 core->flow/runtime_coroutine 反向引用。"代理文件"回滚策略可行，Lua require 可做路径重映射。✓**

3. 收敛 `PresentationPorts` 的职责，只保留 adapter，不承载 use-case 算法。
   - 动作：`TickTimeout/TickUISync` 迁回用例层端口实现，`PresentationPorts` 仅做 UI 调用/事件桥接。
   - 影响范围：`presentation/api/PresentationPorts.lua`、`game/flow/turn/*`。
   - 预期收益：adapter 不再反向依赖用例模块，边界更清晰。
   - 回归风险：中等偏高（UI 时序）；回滚点为"保留旧实现分支开关"。

> **[R] 方案 3 合理但需注意：TickTimeout/TickUISync 当前被 PresentationPorts 的 ui_sync 组直接调用(:117-134)，迁移后需确保 GameplayLoopPorts 的 base 实现能完整替代。风险评估"中等偏高"恰当。✓**

4. 把共享 `state` 分片，降低跨层隐式耦合。
   - 动作：把 `state` 切为 `turn_runtime/ui_runtime/anim_runtime` 子对象；跨边界只传 DTO。
   - 影响范围：`GameStartup.lua`、`GameplayLoop.lua`、`UIViewService.lua`。
   - 预期收益：状态修改责任更清晰，字段回归更容易定位。
   - 回归风险：中等；回滚点为"保留旧字段镜像过渡期"。

> **[R] 方案 4 影响范围可能低估。`state` 被 PresentationPorts(:72-277)、AutoRunner、BoardRuntime 等大量模块直接读写字段，分片改造的实际触及面远超 3 个文件。建议先做字段归属分析再定影响范围。风险应为"中等偏高"。**

5. 扩展架构守护测试（先写测试再改结构）。
   - 动作：在 `tests/internal/dep_rules.lua` 增加：
     - 禁止 `src/game/core/**` 直接使用 `GameAPI/GlobalAPI/SetTimeOut/Register*`。
     - 禁止 `src/game/core/**` 依赖 `src.game.flow.*`。
     - 允许例外名单由白名单文件管理。
   - 影响范围：仅测试与 CI。
   - 预期收益：防止架构退化，降低长期维护成本。
   - 回归风险：低（主要是暴露已有问题，需要分批清理）。

> **[R] 方案 5 价值最高/风险最低，强烈建议前置执行。新增的两条规则（禁止 core 用 GameAPI、禁止 core->flow）将立即暴露全部 P0+P1 违规点，为后续重构提供明确的完成定义。✓**

## 测试建议

- 用例级测试（必须）：对 `TurnStart/Roll/Move/Land/PostAction` 做端口替身测试，验证状态迁移与领域事件，不依赖 Eggy 全局。
- 边界契约测试（必须）：固定 `GameplayLoopPorts`、`PresentationPorts` 的端口签名与默认语义（尤其 `clock`、`modal`、`state`）。
- 依赖规则测试（必须）：把上文新增规则并入 `tests/internal/dep_rules.lua`，CI 中强制执行。
- 回归测试（保持）：继续使用 `lua tests/regression.lua`（当前基线 187）作为行为等价门槛。
- 高风险场景专项：补“破产清算 + 动画等待 + 市场中断 + 偷窃中断”串联路径，确保拆边界后行为不变。

> **[R] 测试建议全面且分层清晰。回归基线 187 与实测一致。高风险场景列表覆盖了 Bankruptcy + TurnAnim（SetTimeOut）+ Market + Steal 的交叉路径，切中要害。✓**

## 权衡说明

- 短期成本：需要重排部分模块职责并补端口测试，预计会增加少量样板代码与迁移工时。
- 长期收益：核心规则对运行时/UI 解耦后，可测试性、可替换性和变更隔离能力显著提升，后续功能迭代风险明显下降。
- 取舍建议：优先做 P0（全局依赖反转）和守护测试，再做目录语义与状态分片；这样投入最小、收益最大且可持续验证。

> **[R] 权衡说明务实。取舍建议与评审意见一致：守护测试 + P0 先行是最优起步。✓**
>
> **[R] 整体评审结论：本研究文档质量优秀，证据链完整且绝大多数精确命中源码。发现 1 处数据纠正（presentation->game/systems 依赖数 3→2，总数 6→5）、行号微调 1 处（GameplayLoopPorts clock 端口 102-121→99-129）、1 条优先级建议（守护测试前置）、1 条影响范围低估提醒（state 分片）。核心论点和重构方向均成立。**
