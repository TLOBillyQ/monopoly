# Monopoly 架构研究（当前评估与后续方向）

技能使用：`clean-architecture-reviewer`

## 1) 研究范围与证据

本次评估聚焦当前代码库的分层、依赖方向与边界穿越方式，抽样范围覆盖：

- 启动与装配：`src/app/bootstrap/*`、`src/app/init.lua`
- 核心策略：`src/game/core/*`、`src/game/runtime/*`
- 用例编排：`src/game/flow/turn/*`
- 适配层：`src/presentation/*`
- 规则守护与契约：`tests/internal/dep_rules.lua`、`tests/suites/*contract*.lua`

验证基线：

- `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
- `lua tests/regression.lua` -> `All regression checks passed (208)`（含 `tick ok`、`forbidden_globals ok`）

---

## 2) 系统策略与关键用例

企业级规则（Entities / Enterprise Rules）：

- 玩家资产/状态与胜负：`src/game/core/player/*`、`src/game/core/runtime/player_state/*`、`src/game/core/runtime/GameVictory.lua`
- 棋盘/地块/租金计算：`src/game/systems/board/*`、`src/game/systems/land/*`

应用级规则（Use Cases / Application Rules）：

- 回合推进与动作分发：`src/game/runtime/TurnEngine.lua`、`src/game/flow/turn/TurnDispatch.lua`
- Tick 编排：`src/game/flow/turn/GameplayLoop.lua`、`GameplayLoopTickFlow.lua`
- 自动行为与超时策略：`AutoRunner.lua`、`TurnTimerPolicy.lua`、`TurnRoleControlPolicy.lua`、`TurnCameraPolicy.lua`

---

## 3) 分层与边界映射

分层映射（由内向外）：

- `Entities`：`src/game/core/player`、`src/game/systems/*` 中纯规则模块
- `Use Cases`：`src/game/core/runtime`、`src/game/runtime`、`src/game/flow/turn`
- `Interface Adapters`：`src/presentation/api`、`src/presentation/interaction`、`src/presentation/render`
- `Frameworks & Drivers`：`GameAPI`/`GlobalAPI`/`SetTimeOut`/`RegisterTriggerEvent` 等运行时宿主 API

边界穿越现状：

- 正向：`src/app/bootstrap/GameRuntimeBootstrap.lua` 通过 `PresentationPorts.build()` 注入 `gameplay_loop_ports`。
- 正向：`src/core/RuntimePorts.lua` 作为核心对宿主能力的统一端口。
- 残余：`RuntimePorts` 与 `RuntimeContext` 仍保留全局变量 fallback（`all_roles` / `vehicle_helper` / `camera_helper`），并支持可选全局写回。

---

## 4) 架构结论

当前代码库已具备清晰的“核心规则 -> 用例编排 -> 表现适配”主干，且依赖规则守护与回归基线稳定。  
但运行时能力边界仍有“上下文注入 + 全局 fallback”双轨，导致内层行为在特定场景下仍受外部隐式状态影响。  
整体属于“方向正确、边界尚未完全收口”的阶段。

---

## 5) 主要问题（P0-P3）

- `P0`：未发现会立即破坏核心业务正确性的依赖反向错误。

- `P1`：运行时端口存在隐式全局回退，边界不完全封闭。
  - 位置：`src/core/RuntimePorts.lua`、`src/core/RuntimeContext.lua`
  - 现象：`resolve_roles/resolve_vehicle_helper/resolve_camera_helper` 在缺少 context 时回退到全局变量或 `GameAPI`。
  - 风险：同一用例在不同启动路径下可能出现不同行为，问题定位困难。

- `P1`：运行时上下文与端口配置为全局单例，可并发性与可组合性受限。 Qin: 不存在这个问题，因为没有这个需求
  - 位置：`runtime_context.set_current/current`、`runtime_ports.configure`
  - 风险：多实例运行、并行测试、热重载场景容易产生状态污染。

- `P2`：适配层仍有较多直接宿主 API 访问，未完全经由统一端口。
  - 位置示例：`src/presentation/ui/UIPanel.lua`、`src/presentation/ui/PopupRenderer.lua`、`src/presentation/api/UIEventHandlers.lua`
  - 风险：替换渲染宿主或做离线回放测试时，mock 面过大。

- `P2`：契约命名与语义尚未完全去“兼容化”。
  - 位置：`tests/suites/runtime_compat_contract.lua`（suite 名虽已迁移为 `runtime_ports_contract`，文件名仍含 compat）
  - 风险：团队心智仍默认“兼容桥长期存在”，影响后续治理决策。

- `P3`：守护规则描述存在历史术语残留。
  - 位置：`tests/internal/dep_rules.lua` 的若干 description 仍提及 `RuntimeCompat` 表述。
  - 风险：规则意图与当前实现不完全对齐，增加维护噪音。

---

## 6) 重构方案（最小可落地步骤）

1. 收口运行时能力入口（context-first 单轨）
- 改动范围：`src/core/RuntimePorts.lua`、`src/core/RuntimeContext.lua`、`src/app/bootstrap/RuntimeInstall.lua`
- 做法：将全局 fallback 下沉到单独 `LegacyRuntimeAdapter`；`RuntimePorts` 默认只读 context，非 legacy 模式不触达全局。
- 预期收益：边界行为确定性提升，依赖方向更清晰。
- 回归风险：历史启动路径若未注入 context 可能暴露空指针，需配套启动契约测试。

2. 去全局单例化（引入作用域容器）Qin:不存在这个问题，因为没有这个需求
- 改动范围：`src/core/RuntimeContext.lua`、`src/core/RuntimePorts.lua`、`src/app/bootstrap/*`
- 做法：把 `current/configured` 改为与 game/state 绑定的 scoped container（显式传入/挂载）。
- 预期收益：支持多实例与并发测试，减少状态串扰。
- 回归风险：调用链参数会增加，短期重构面较大。

3. 统一适配层宿主访问端口
- 改动范围：`src/presentation/ui/*`、`src/presentation/api/*`、`src/presentation/render/*`
- 做法：新增并推广 `RoleReadPort/TimerPort/ScenePort`，替代散落的 `GameAPI/SetTimeOut/GlobalAPI` 直接调用。
- 预期收益：适配层可替换性和可测试性提升，mock 粒度统一。
- 回归风险：UI 行为时序敏感，需要分批迁移并回归验证。

4. 继续细化 turn 用例编排职责
- 改动范围：`src/game/flow/turn/GameplayLoopTickFlow.lua` 及策略模块
- 做法：保持语义不变前提下，继续把“phase 驱动、timeout 驱动、dirty 刷新驱动”拆成更窄的用例函数。
- 预期收益：单点复杂度下降，回归定位更快。
- 回归风险：tick 顺序敏感，需严格保持调用顺序契约。

5. 同步更新命名与规则语义
- 改动范围：`tests/suites/runtime_compat_contract.lua`（重命名）、`tests/internal/dep_rules.lua`（描述文本）
- 做法：将“compat”语义从文件名和规则描述中彻底移除。
- 预期收益：团队认知与当前架构一致，减少历史债务心智残留。
- 回归风险：低，主要是测试注册路径与文案同步。

---

## 7) 测试建议

- 用例级测试（必须）：
  - 锁定 `gameplay_loop.tick` 的时序契约：auto runner、timeout、phase sync、dirty refresh 的先后关系与触发条件。
  - 继续覆盖 action timeout、popup timeout、camera follow、dispatch gate 的组合场景。

- 边界契约测试（必须）：
  - 为 `RuntimeInstall` 增加“严格 context 模式”契约：未注入 context 时显式失败或受控降级，不允许隐式全局取值。
  - 为 `PresentationPorts` 增加契约：关键 UI 行为只通过端口访问宿主能力。

- 架构守护测试（建议）：
  - 在 `dep_rules` 增加规则：`src/core` 除 `LegacyRuntimeAdapter` 外不得读写 `all_roles/ALLROLES/vehicle_helper/camera_helper`。
  - 增加“启动路径矩阵”回归：正式模式、legacy 模式、测试模式三套入口都可稳定启动。

---

## 8) 权衡说明

短期成本：

- 运行时端口与上下文改为作用域化后，函数签名和装配代码会变长，重构面广。
- UI 适配层端口化迁移会带来阶段性重复代码和双轨维护。

长期收益：

- 核心用例对宿主细节的耦合进一步降低，行为可预测性显著提升。
- 依赖规则更容易长期守住，回归定位和新人上手成本下降。
- 支持多实例、并行测试、离线模拟等后续能力演进。

总体建议：优先做“边界收口 + 单例去除”两步，再推进表现层全面端口化；这是当前收益/风险比最高的演进路径。

---

## 9) 执行状态（R14 回填）

以下状态基于本轮已落地改动与回归结果（`lua tests/regression.lua` -> `All regression checks passed (209)`，`lua tests/internal/dep_rules.lua` -> `dep_rules ok`）。

- `已完成`：步骤 1（收口运行时能力入口，context-first 默认路径）
  - 已落地：`src/core/RuntimePorts.lua` 增加显式 `legacy_global_fallback` 开关，默认不再隐式读取全局 `all_roles/vehicle_helper/camera_helper`。
  - 已落地：`src/app/bootstrap/RuntimeInstall.lua` 增加 `context_policy=strict|legacy` 与 `skip_context_install` 受控策略；strict 模式缺失 context 时显式失败。
  - 备注：未单独引入 `LegacyRuntimeAdapter` 文件，采用 `RuntimePorts` 内显式 legacy 分支达成同等治理目标。

- `不纳入`：步骤 2（去全局单例化）
  - 根据注释“没有这个需求”，本轮未执行该项。

- `已完成`：步骤 3（统一适配层宿主访问端口）
  - 已迁移关键路径：`src/presentation/ui/UIPanel.lua`、`src/presentation/ui/PopupRenderer.lua`、`src/presentation/api/UIEventHandlers.lua` 改为通过 `RuntimePorts.resolve_role` 读取角色。
  - 已新增迁移：`src/presentation/interaction/ui_intent_dispatcher/ViewCommandDispatcher.lua`、`src/presentation/render/BoardScene.lua`、`src/presentation/render/board_runtime/player_units.lua`、`src/presentation/render/status3d_service/scene.lua`、`src/presentation/render/status3d_service/status.lua`。
  - 收口结果：新增 `src/presentation/api/HostRuntimePort.lua`，将 `render/api/interaction` 的宿主调用统一收敛到端口层；`status3d` 保留受控 `resolve_game_role` 回退以兼容测试桩与观察者角色对象差异。
  - 证据：`rg "\\b(GameAPI|GlobalAPI|SetTimeOut|RegisterCustomEvent|TriggerCustomEvent)\\b" src/presentation -n` 仅命中 `HostRuntimePort.lua`（另有一处 `Status3DService` 告警文案字符串命中）。

- `未开始`：步骤 4（继续细化 turn 用例编排职责）
  - 本轮未触及 `GameplayLoopTickFlow.lua` 的进一步职责拆分。

- `已完成`：步骤 5（同步更新命名与规则语义）
  - 已完成：`tests/suites/runtime_compat_contract.lua` -> `tests/suites/runtime_ports_contract.lua`，并同步 `tests/regression.lua` 注册入口。
  - 已完成：`tests/internal/dep_rules.lua` 清理 `MonopolyEvents compatibility bridge` 历史术语。
  - 已新增：`dep_rules.lua` 中 RuntimeCompat 规则描述调整为“retired runtime bridge path”，降低历史兼容语义噪音。

本次增量验证（2026-03-02）：

- `lua tests/regression.lua` -> `All regression checks passed (209)`（含 `tick ok`、`forbidden_globals ok`）
- `lua tests/internal/dep_rules.lua` -> `dep_rules ok`
