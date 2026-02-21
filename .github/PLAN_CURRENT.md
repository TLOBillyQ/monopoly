# 核心链路解耦重构实施计划（P1 先行）

本可执行计划是活文档。实施过程中必须持续维护“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `/Users/billyq/Dev/Github/Lua/monopoly/.github/PLANS.md`。

## 目的 / 全局视角

这次重构的目标不是改玩法，而是降低核心链路的结构风险。完成后，开发者可以在不拉起完整游戏运行时的前提下，单独测试 UI intent 分发、动作分发和路由策略；同时新增或调整 choice/action 时，不需要再修改多个“大函数”。

用户可见的验收方式是：现有回归（`regression + dep_rules + tick + presentation_ui`）保持全绿；并且新增的分层测试可以只依赖端口 mock 运行，证明核心链路的耦合已下降。

## 进度

- [x] (2026-02-21 09:15Z) 读取最新架构基线：`/Users/billyq/Dev/Github/Lua/monopoly/ARCHITECTURE.md`（已确认启动分段、`TurnFlow` 状态机、测试 profile 链路）。
- [x] (2026-02-21 09:22Z) 完成核心链路审查结论归档（P1/P2/P3 风险、文件与函数定位、验证建议）。
- [ ] 里程碑 1：切断 `presentation -> game` 直接依赖，落地 `TurnActionPort` 并通过 `dep_rules`。
- [ ] 里程碑 2：拆分 `GameplayLoop.set_game` 与 `TurnDispatch` 依赖面，形成最小可测接口。
- [ ] 里程碑 3：将 `UIChoiceRoutePolicy` 从硬编码语义改为显式路由元数据契约。
- [ ] 里程碑 4：降低启动层与运行时全局注入耦合（`UIBootstrap`、`RuntimeContext`、`GameStartup`）。
- [ ] 里程碑 5：补齐单测/集成测试，并完成一次全量回归与双端手测抽样。

## 意外与发现

- 观察：架构已从“单段 init”演进为“立即安装运行时 + `GAME_INIT` 延迟装配 UI/loop”，这要求重构时避免回退到旧初始化模型。
  证据：`ARCHITECTURE.md` 中“初始化分两段”和“启动链路”章节。
- 观察：`TurnFlow` 已成为回合推进核心，`GameplayLoop` 的职责应该聚焦在调度而不是阶段跳转细节。
  证据：`ARCHITECTURE.md` 的“Tick 链路”和“状态机说明”。
- 观察：`dep_rules` 当前可作为防线，但对语义级耦合（非显式 require）覆盖不足。
  证据：审查中发现 `UIChoiceRoutePolicy` 对 `choice.kind/option.id` 的硬编码不触发规则告警。

## 决策日志

- 决策：按“P1 先行，P2/P3 随后”的两批路线推进。
  理由：先解决高风险耦合（跨层依赖、职责过载），才能避免后续重构反复返工。
  日期/作者：2026-02-21 / Codex。

- 决策：先改接口注入，再改内部实现。
  理由：通过兼容适配层控制风险，保证每一步都可回归验证，避免一次性大改导致定位困难。
  日期/作者：2026-02-21 / Codex。

- 决策：保留现有玩法行为和 UI 表现为硬约束，重构只改结构与依赖方向。
  理由：本轮目标是稳定性和可维护性，不引入策划与表现层行为变更。
  日期/作者：2026-02-21 / Codex。

## 结果与复盘

当前尚未开始代码实施。本计划已根据最新架构文档重写为可执行版本，下一步按里程碑 1 开工。阶段完成后在本节补充：完成项、遗留项、回归结果、教训。

## 背景与导读

本仓库当前主链路是：
`main.lua -> src/app/init.lua -> RuntimeInstall.install -> GameStartup.build_state -> UIBootstrap.install(GAME_INIT) -> GameplayLoop.tick/TurnFlow/TurnDispatch -> UIModel/UIView`。

这条链路里的结构风险主要有四类：

第一类是依赖方向错误。典型问题是交互层直接依赖游戏分发实现，使高层策略无法仅依赖抽象接口。

第二类是职责混杂。典型问题是 `GameplayLoop.set_game` 一次做太多事情，任何一个子能力修改都要进入同一函数。

第三类是路由语义硬编码。典型问题是 choice 路由通过 `kind/option` 猜测，扩展新选择类型时容易落错页面。

第四类是启动期隐式全局注入。典型问题是 runtime helper 构建与全局写入耦合，导致测试和替换困难。

本计划限定以下文件为主实施区：

- `/Users/billyq/Dev/Github/Lua/monopoly/src/app/bootstrap/GameStartup.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/app/bootstrap/UIBootstrap.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/core/RuntimeContext.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/GameplayLoop.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/GameplayLoopRuntime.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/TurnDispatch.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/TurnDispatchValidator.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/game/flow/turn/GameplayLoopPorts.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UIEventRouter.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UIIntentBuilder.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UIIntentDispatcher.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UIInputLockPolicy.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UITouchPolicy.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/src/presentation/interaction/UIChoiceRoutePolicy.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/Config/GameplayRules.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/Config/Map.lua`
- `/Users/billyq/Dev/Github/Lua/monopoly/.github/tests/internal/dep_rules.lua`

## 里程碑

### 里程碑 1：UI intent 分发端口化（先切断跨层硬依赖）

本里程碑只处理 `UIIntentDispatcher` 的依赖方向。完成后，`presentation/interaction` 不再直接 `require src.game.flow.turn.TurnDispatch`，改为依赖注入的 `TurnActionPort`。这一步完成后就能独立测试 UI intent 分发，不需要完整 game runtime。

工作内容包括：在交互层定义最小动作端口（分发 action、检查阻塞、必要时读取最小 UI 数据），在启动装配阶段完成注入，保留兼容适配器让旧路径可运行。`dep_rules` 必须在此里程碑结束时保持通过。

验收命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/internal/dep_rules.lua

预期结果：不再出现 `presentation` 到 `src.game.*` 的直接违规依赖；现有回归不倒退。

### 里程碑 2：回合主循环与动作分发职责拆分

本里程碑聚焦 `GameplayLoop.set_game` 和 `TurnDispatch`。完成后，`set_game` 只做编排，初始化细节下沉到小函数；`TurnDispatch` 只依赖最小端口，不直接碰 UI 结构细节。

工作内容包括：

- 在 `GameplayLoop.lua` 提取 `initialize_ports`、`configure_environment`、`configure_pending_choice` 等职责函数。
- 在 `TurnDispatch.lua` 引入最小注入端口，减少 `resolve` 与具体 `state.ui` 读取。
- 在 `TurnDispatchValidator.lua` 通过抽象 `ItemSlotData` 访问道具槽数据，不直接绑定 UI 字段结构。

验收命令：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

预期结果：`All regression checks passed`、`dep_rules ok`、`tick ok`；并能通过 mock 端口测试 `dispatch_action` 关键分支。

### 里程碑 3：Choice 路由契约显式化

本里程碑解决 `UIChoiceRoutePolicy` 的硬编码语义问题。完成后，路由基于显式字段（如 `route_key`、`requires_confirm`），而不是猜测 `kind/option.id`。

工作内容包括：

- 在 choice 产生路径中补充路由元数据（兼容期保留旧字段 fallback）。
- `UIChoiceRoutePolicy.resolve` 优先使用显式契约，逐步移除硬编码组合判断。
- 增加表驱动测试覆盖“有元数据/无元数据/未知类型”三类情况。

验收场景：新增一种 choice 类型时，仅改数据契约即可路由正确，不需要改策略分支。

### 里程碑 4：启动层与运行时上下文解耦

本里程碑处理 `UIBootstrap`、`GameStartup`、`RuntimeContext` 的边界。完成后，运行时 helper 默认以返回对象传递，启动层选择是否做兼容全局挂载；`build_state` 与事件注册分离。

工作内容包括：

- `UIBootstrap` 不再创建 game/loop，仅负责 UI 节点装配和路由绑定。
- `GameStartup.build_state` 保持纯状态构建，事件订阅迁到桥接模块。
- `RuntimeContext.install_runtime_helpers` 以返回 context 为主路径，全局写入仅作兼容开关。

验收场景：在测试环境可仅创建 state + mock context 完成交互层测试，不依赖引擎全局。

### 里程碑 5：测试补齐与回归收口

本里程碑用于把结构重构转化为稳定产物。完成后，新增测试覆盖主要端口与策略，且现有回归全部通过。

工作内容包括：

- 单测：`UIIntentDispatcher` 端口注入路径、`TurnDispatch` 最小端口分支、`UIChoiceRoutePolicy` 表驱动。
- 集成：启动链路注入 fake port/fake runtime context，验证 intent->dispatch->tick 基本闭环。
- 回归：跑全量 + presentation UI 分片 + dep_rules。

## 工作计划

实施顺序必须遵守“先建立兼容接口，再迁移调用方，最后收紧规则”的原则。第一阶段先引入 `TurnActionPort` 和适配层，确保行为不变且可单测。第二阶段拆分 `GameplayLoop` 与 `TurnDispatch`，把混杂职责下沉为可测小函数。第三阶段切换 choice 路由契约，减少策略分支。第四阶段再处理启动层和 runtime 全局注入，避免在前两阶段引入额外变量。最后一阶段补测试并做回归收口。

每个阶段结束都要保证：已有用例全绿、关键手测路径可走通。若某阶段失败，先回退该阶段新增的入口绑定，再恢复上一阶段稳定状态继续推进。

## 具体步骤

1. 基线确认（每次开始重构前执行）：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

2. 里程碑 1 实施完成后验证：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/internal/dep_rules.lua

3. 里程碑 2-4 每阶段完成后验证：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

4. 里程碑 5 最终验证：

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua .github/tests/regression.lua

    cd /Users/billyq/Dev/Github/Lua/monopoly
    lua -e 'package.path=package.path..";./.github/tests/?.lua;./.github/tests/suites/?.lua;./.github/tests/fixtures/?.lua"; local h=require("TestHarness"); h.run_all({require("presentation_ui_timing_anim"),require("presentation_ui_model_dispatch"),require("presentation_ui_interaction"),require("presentation_ui_popup_market"),require("presentation_ui_action_status"),require("presentation_ui_action_anim")})'

5. 编辑器抽样手测（双端）：

    pwsh /Users/billyq/Dev/Github/Lua/monopoly/.github/scripts/deploy.ps1 -TargetPath "/Users/billyq/Documents/eggy/LuaSource_monopoly"

    # 主端操作：投骰、choice、黑市、调试开关
    # 副端观察：可见性隔离/同步是否符合预期

## 验证与验收

本计划的通过标准分三层。

第一层是自动化稳定性：`regression.lua`、`dep_rules.lua`、`presentation_ui` 分片全部通过。

第二层是结构目标：

- `UIIntentDispatcher` 不再直接依赖 `src.game.*`。
- `GameplayLoop.set_game` 拆分后函数职责清晰且可单测。
- `TurnDispatchValidator` 不直接读取 UI 细节字段。
- `UIChoiceRoutePolicy` 基于显式路由元数据。
- `RuntimeContext` 支持无全局注入的 context 返回路径。

第三层是行为不变：关键 UI 流程（投骰、choice、黑市、弹窗、破产）在双端抽样下与现有体验一致。

## 可重复性与恢复

本计划按里程碑增量执行，可重复。每次只推进一个里程碑，验证通过后再进入下一步。若某一步失败：

- 先撤回本里程碑新增入口（适配器绑定/新注入点），保留已稳定的前一里程碑代码。
- 保持 `default` 配置可运行，不改策划数值与地图规则。
- 所有回退都以“恢复回归全绿”为准，不做破坏性 git 操作。

## 产物与备注

实施完成后，至少应新增或更新以下产物：

- 新/改接口定义与适配器（`TurnActionPort`、`ItemSlotData`、相关注入点）。
- `GameplayLoop`/`TurnDispatch` 的拆分实现与对应测试。
- `UIChoiceRoutePolicy` 新契约与兼容回退路径。
- 启动层与 runtime context 解耦实现。
- 覆盖上述结构变更的单测/集成测试。

必要时记录每个里程碑的关键日志片段，用于证明“行为不变 + 结构改善”同时成立。

## 接口与依赖

本计划实施后，核心接口目标如下（命名可微调，但语义必须保留）：

- `TurnActionPort`
  - `dispatch_action(game, state, action)`
  - `should_block_action(action_type, state)`

- `ItemSlotData`
  - `get_item_ids(actor_role_id)`
  - `resolve_slot_action(actor_role_id, slot_index_or_id)`

- `RuntimeContext.install_runtime_helpers(...)`
  - 返回 `{ vehicle_helper, camera_helper, roles, ... }` 的 context 对象；全局写入路径仅用于兼容。

- `UIChoiceRoutePolicy.resolve(choice, option, context)`
  - 优先读取显式路由字段（例如 `route_key`），旧字段仅兼容。

依赖保持现有 Lua 运行时和仓库测试体系，不引入新工具链。

## 更新记录

- 2026-02-21：将 `PLAN_CURRENT.md` 从“编辑器快速测试配置实施计划”切换为“核心链路解耦重构实施计划（P1 先行）”。原因：用户要求把审查得到的重构方案落为可执行计划，且 `ARCHITECTURE.md` 已更新，原计划不再匹配当前主任务。
