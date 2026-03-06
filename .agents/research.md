# Monopoly 代码库架构审查报告

**审查日期**: 2026-03-06
**代码库规模**: 274 Lua 文件
**审查方法论**: Clean Architecture + 依赖规则静态分析 + 运行时契约验证

---

## 执行摘要

Monopoly 代码库正处于**架构迁移的关键阶段**——它已从"完全过程式耦合"演进至"分层骨架基本成型，但语义泄漏仍需收口"的状态。这不是一个失败的架构，而是一个**需要完成迁移**的架构。

**关键发现**:

| 维度 | 现状 | 风险等级 |
|------|------|----------|
| 目录结构 | 分层清晰（core/game/presentation/app） | 低 |
| 依赖方向 | 静态 import 基本正确 | 低 |
| 宿主耦合 | `src/core/` 仍含 6 个文件、42 处宿主 API 直接调用 | **P0** |
| UI 渗透 | `game.ui_port` 扩散至 15 个文件，形成反向依赖 | **P1** |
| 状态边界 | `game/flow` 直接操作 `state.ui_*` 等 UI 协调状态 | **P1** |
| 契约测试 | 已建立 dep_rules + 5 套契约测试 | 资产 |

**核心结论**: 当前架构不应推倒重来，而应**先补架构守护测试，再逐步收口三条关键边界**（use case→UI、core→runtime、market→payment）。

---

## 1. 架构现状全景

### 1.1 分层映射（实际 vs 理想）

```
┌─────────────────────────────────────────────────────────────────┐
│  Frameworks & Drivers (外层)                                     │
│  ├── src/app/bootstrap/          ← 组合根 + 生命周期协调          │
│  ├── src/core/RuntimeEnvBindings ← 宿主 API 绑定（应外迁）        │
│  └── src/presentation/api/host_runtime                          │
├─────────────────────────────────────────────────────────────────┤
│  Interface Adapters                                              │
│  ├── src/presentation/api/       ← UIViewService, UIRuntimePort │
│  ├── src/presentation/render/    ← BoardRuntime, ActionAnim     │
│  └── src/presentation/interaction/                              │
│      ├── UIIntentDispatcher      ← 真正的适配器                  │
│      └── PreConfirmFlow          ← 已吞入应用规则 ⚠️             │
├─────────────────────────────────────────────────────────────────┤
│  Use Cases / Application Rules                                   │
│  ├── src/game/runtime/           ← TurnEngine, PhaseRegistry    │
│  │                                 (引擎壳，通用调度)             │
│  └── src/game/flow/              ← GameplayLoop, TurnDispatch   │
│                                    (业务用例，但直接写 UI state ⚠️)│
├─────────────────────────────────────────────────────────────────┤
│  Entities / Enterprise Rules                                     │
│  ├── src/game/core/runtime/Game.lua  ← 聚合根                    │
│  ├── src/game/core/player/       ← Player, Inventory            │
│  └── src/game/systems/           ← board, land, items, chance   │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 关键设计决策（已落实）

1. **端口模式已建立**: `RuntimePorts`、`PresentationPorts`、`GameplayLoopPorts` 形成可注入边界
2. **依赖规则已配置**: `tests/internal/dep_rules.lua` 禁止 presentation 直接 require game 层
3. **组合根已集中**: `src/app/init.lua` 统一控制启动顺序
4. **读取模型已拆分**: `GameplayReadPort` 隔离 presentation 对 game 状态的直接访问

### 1.3 迁移未完成的关键证据

**证据 A: src/core 的宿主残留**

```lua
-- src/core/runtime_ports/DefaultPorts.lua (line 21, 32-33)
assert(GameAPI.random_int, "missing GameAPI.random_int")
...
return GameAPI.random_int(min, max)  -- 直接依赖宿主 API
```

涉及文件（6 个，42 处匹配）:
- `src/core/RuntimeEnvBindings.lua` - 安装全局 SetTimeOut/事件注册
- `src/core/runtime_ports/DefaultPorts.lua` - GameAPI 默认实现
- `src/core/RuntimeContext.lua` - 角色解析、helper 安装
- `src/core/RuntimeEditorExports.lua` - 编辑器导出
- `src/core/RuntimeEventBridge.lua` - 事件桥接
- `src/core/Logger.lua` - GlobalAPI.show_tips

**证据 B: game.ui_port 的广泛渗透**

```lua
-- src/game/flow/turn/TurnRoll.lua
local ui_port = assert(game.ui_port, "missing ui_port")
...
if ui_port.wait_action_anim then return "anim_blocking" end
```

直接使用者（15 个文件）:
- 用例层: `GameplayLoop`, `TurnRoll`, `TurnMove`, `TurnDecision`, `IntentDispatcher`
- 领域层: `Bankruptcy`, `GameStateTiles`
- 子域系统: `ItemPhase`, `ItemUseBroadcast`, `ItemInventory`, `LandingPresenter`

**证据 C: presentation 的应用规则累积**

```lua
-- src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua
local Market = require("Config.Generated.Market")  -- 直接依赖业务配置
...
if choice.kind == "market_buy" then
  -- 应用级二次确认逻辑
end
```

---

## 2. 结构性问题深度分析

### 2.1 P0: Dependency Rule 未收口（src/core 宿主耦合）

**问题本质**: `src/core` 名义上是"最内层策略核心"，实际上承担"宿主环境适配器"职责。这导致：

1. **内层不稳定**: 无法脱离 Eggy runtime 进行单元测试
2. **依赖方向错误**: 内层认识外层（GameAPI），而非外层实现内层接口
3. **虚假抽象**: RuntimePorts 只是 indirection，不是真正的依赖倒置

**量化数据**:
- `src/core/` 共 21 个 Lua 文件
- 6 个文件含宿主 API 直接调用
- 42 处 `rg` 匹配行

**关键违规点**:

| 文件 | 违规内容 | 应迁移至 |
|------|----------|----------|
| RuntimeEnvBindings.lua | 安装 SetTimeOut/RegisterCustomEvent 全局 | app/bootstrap |
| runtime_ports/DefaultPorts.lua | GameAPI 默认实现 | app/bootstrap/runtime_install |
| RuntimeContext.lua | 角色解析、vehicle/camera helper 安装 | app/bootstrap |
| Logger.lua | GlobalAPI.show_tips | 通过 sink 注入 |

**迁移迹象（正面）**:
- `src/app/bootstrap/runtime_install/RuntimePortDefaults.lua` 已开始外迁部分实现
- `RuntimeInstall.lua` 启动时调用 `runtime_ports.configure(runtime_port_defaults.build())`

**结论**: 这是"迁移未完成"而非"未开始"，需彻底关闭 fallback 路径。

### 2.2 P1: 用例层持有 UI 协调状态

**问题本质**: `game/flow` 不仅编排用例，还直接管理 UI 等待状态、选择超时、模态框生命周期。

**量化数据**:
- `src/game/flow/` 中 `state.ui_* / state.pending_choice / state.ui_model` 共 60 处匹配
- 分布在 9 个文件中

**关键代码 smell**:

```lua
-- src/game/flow/turn/GameplayLoop.lua
function M.tick(game, state, dt)
  -- 业务逻辑与 UI 状态混杂
  state.ui_dirty = true  -- 直接写 UI 标记
  state.pending_choice_elapsed = (state.pending_choice_elapsed or 0) + dt
  ...
end

-- src/game/flow/turn/TurnDispatch.lua
function M.dispatch_action(game, state, action, opts)
  state.pending_choice = nil      -- 直接清理 UI 状态
  state.pending_choice_id = nil
  state.ui_dirty = true
end
```

**设计问题**:
- `state` 同时是: 应用状态容器 + UI 协调容器 + 运行时容器
- 边界对象不稳定，UI 结构变化将波及用例层

### 2.3 P1: game.ui_port 形成反向依赖

**问题本质**: 内层模块通过隐式协议访问 `game.ui_port`，违反依赖倒置原则。

**隐式协议内容**:
- `game.ui_port` 必须存在
- 必须有 `push_popup`, `wait_action_anim`, `wait_move_anim` 方法
- 有时 `ui_port.state` 还能回指共享 state

**这不是端口抽象，而是共享对象图泄漏。**

**扩散范围**:

```
game.ui_port 渗透图:
├── game/flow/turn/GameplayLoop.lua      ← 创建并挂载
├── game/flow/turn/TurnRoll.lua          ← 读取 wait_action_anim
├── game/flow/turn/TurnMove.lua          ← 读取 wait_move_anim
├── game/flow/turn/TurnDecision.lua      ← 推送选择模态
├── game/flow/intent/IntentDispatcher.lua ← 推送弹窗
├── game/core/runtime/Bankruptcy.lua     ← 推送破产提示 ⚠️ 领域层
├── game/core/runtime/GameStateTiles.lua ← 地块变更通知 ⚠️ 领域层
└── game/systems/items/*.lua             ← 道具广播、库存操作
```

**严重性**: 已扩散至 `game/core` 和 `game/systems`，超出用例层。

### 2.4 P1: presentation 承接应用规则

**问题本质**: presentation 层通过 `choice.kind/meta` 隐式协议吸收业务语义，成为"adapter + UI orchestration + 局部决策"的混合层。

**关键证据**:

```lua
-- src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua
-- 58 处 choice.kind / Config.Generated.Market 相关匹配

if choice.kind == "market_buy" or choice.kind == "item_phase_choice" then
  -- 应用级二次确认逻辑
  local goods = Market.goods[choice.meta.goods_id]
  -- 生成确认文案、判断条件
end
```

**隐含风险**:
- `choice.kind` 成为横跨用例层与 UI 层的隐式 DSL
- 新增 choice 类型时，容易继续在 UI 层堆积业务分支

### 2.5 P1: Market 购买链路边界塌陷

**问题模块**: `src/game/systems/market/service/Purchase.lua`

**职责过载**:

```
Purchase.lua 同时承担:
├── 商品映射        _build_goods_mappings()        ← domain
├── 外部支付发起    _start_external_purchase()     ← runtime adapter
├── 平台回调注册    _register_purchase_event_for_role() ← event bridge
├── 购买兑现        _fulfill_paid_goods_purchase() ← domain
└── UI 刷新协调     _refresh_market_choice_after_paid_callback() ← presentation
```

**典型 transaction script 汇聚点**，跨越 4 个架构层级。

---

## 3. 正向资产识别

### 3.1 依赖规则测试体系

**文件**: `tests/internal/dep_rules.lua` (171 行)

**已生效规则**:
- presentation/interaction 禁止 require src.game.*
- game/core 禁止直接访问 GameAPI/GlobalAPI/SetTimeOut
- game/core 禁止依赖 game/flow
- 禁止退役模块（RuntimeCompat 等）
- 禁止遗留全局变量（all_roles, vehicle_helper 等）

### 3.2 契约测试覆盖

| 测试文件 | 验证内容 |
|----------|----------|
| runtime_ports_contract.lua | RuntimePorts 行为契约 |
| usecase_boundary_contract.lua | TurnAction port、clock contract |
| ui_gate_contract.lua | UI 门控契约 |
| read_model_contract.lua | ReadModel 与领域计算一致性 |
| cross_module_contract.lua | 跨模块事件、动画契约 |

### 3.3 已建立的端口边界

```lua
-- RuntimePorts 模式（已落实）
local ports = {
  rng_next_int = function(min, max) ... end,
  schedule = function(delay, fn) ... end,
  resolve_role = function(player_id) ... end,
  emit_event = function(event_name, payload) ... end,
  -- 等等
}

-- 使用方式（依赖注入）
runtime_ports.configure(ports)
```

### 3.4 回归验证状态

```
$ lua tests/regression.lua
All regression checks passed (361)
dep_rules ok
tick ok
```

---

## 4. 重构路线图

### 阶段 0: 建立架构守护（必须先做）

**目标**: 防止新代码继续违反边界

**行动**:
1. 在 `dep_rules.lua` 新增静态规则:
   - 禁止 `src/core` 新增 GameAPI/GlobalAPI 调用
   - 禁止 `src/game/flow` 新增 `state.ui_*` 写入
   - 禁止 `src/game` 新增 `game.ui_port` 读取点

2. 新增动态契约测试:
   - 拦截对 UI 字段的写入
   - 验证用例层只通过 port/DTO 输出

3. **必须**集成至 CI: 违反 dep_rules 即构建失败

**风险**: 低
**收益**: 停止架构债务增长

---

### 阶段 1: 定义用例输出协议

**目标**: 切断用例层与 UI 状态的直接耦合

**行动**:

```lua
-- 定义稳定输出协议（新增文件）
-- src/game/flow/ports/OutputPort.lua

---@class ChoiceRequestedEvent
---@field choice_id string
---@field choice_kind string
---@field options table
---@field timeout_ms number|nil

---@class PopupRequestedEvent
---@field popup_type string
---@field message string
---@field duration_ms number

-- GameplayLoop 不再直接写 state，而是输出事件
function M.tick(game, dt)
  -- ... 业务逻辑 ...
  if need_choice then
    output_port.emit(ChoiceRequestedEvent.new(...))
  end
end
```

**改造范围**:
- `src/game/flow/turn/GameplayLoop.lua`
- `src/game/flow/turn/TurnDispatch.lua`
- `src/game/flow/turn/TickChoiceTimeout.lua`

**风险**: 中（主流程路径）
**收益**: 切断最密集的跨层共享状态

---

### 阶段 2: 移除 game.ui_port 隐式挂载

**目标**: 修复 DIP 违规，内层不再知道 adapter 挂载方式

**行动**:

```lua
-- 改造前（GameplayLoop.lua）
game.ui_port = gameplay_loop_runtime.build_ui_runtime_port(state)
-- 各模块通过 game.ui_port.push_popup 访问

-- 改造后
-- 1. 定义 Output Port 接口（内层）
-- src/game/flow/ports/NotificationPort.lua
local NotificationPort = {
  notify_popup = function(payload) end,
  notify_tile_owner_changed = function(tile_id, owner_id) end,
  notify_action_anim = function(anim_spec) end,
}

-- 2. 用例层通过构造函数注入
function GameplayLoop.new(notification_port)
  return { notify = notification_port }
end

-- 3. presentation 层实现接口（外层）
local UINotificationAdapter = {
  notify_popup = function(payload)
    UIViewService.push_popup(payload)
  end,
  -- ...
}
```

**改造范围**:
- 15 个使用 `game.ui_port` 的文件
- `GameplayLoopRuntime` 的端口构建逻辑

**风险**: 中高（动画等待、弹窗是用户可见路径）
**收益**: 消除最严重的依赖方向错误

---

### 阶段 3: 完成 runtime 适配器外迁

**目标**: 让 `src/core` 回到纯策略层

**行动**:

| 当前位置 | 目标位置 | 改造内容 |
|----------|----------|----------|
| core/RuntimeEnvBindings.lua | app/bootstrap/EnvBindings.lua | 全局安装逻辑 |
| core/runtime_ports/DefaultPorts.lua | app/bootstrap/runtime_install/EggyRuntimePorts.lua | Eggy 特定实现 |
| core/RuntimeContext.lua | app/bootstrap/RuntimeContext.lua | 角色解析、helper 安装 |
| core/Logger.lua | core/Logger.lua + sink 注入 | 移除 GlobalAPI 直接调用 |

**Logger 改造示例**:

```lua
-- 改造前
function Logger.show_tip(message)
  GlobalAPI.show_tips(message)  -- 直接依赖
end

-- 改造后
function Logger.new(tip_sink)
  return {
    show_tip = function(message)
      tip_sink(message)  -- 通过注入的 sink
    end
  }
end

-- 组合根注入
local logger = Logger.new(function(msg)
  GlobalAPI.show_tips(msg)
end)
```

**风险**: 中（覆盖面广但路径集中）
**收益**: 真正收口 P0

---

### 阶段 4: 拆分 Market 购买链路

**目标**: 清掉最高耦合热点

**新结构**:

```
src/game/systems/market/
├── domain/
│   └── PurchasePolicy.lua        ← 纯业务规则（资格、扣费、兑现）
├── ports/
│   └── PaymentGatewayPort.lua    ← 支付端口接口
└── service/
    └── MarketService.lua         ← 协调购买流程（不直接调 GameAPI）

src/infrastructure/payment/
├── EggyPaymentGateway.lua        ← 支付适配器（goods 映射、面板调用）
└── PaymentCallbackHandler.lua    ← 平台回调处理

src/presentation/market/
└── MarketChoiceRefresh.lua       ← UI 协调（监听购买完成事件）
```

**流程改造**:

```lua
-- 改造前: Purchase.lua 直接调用 GameAPI.get_goods_list、RegisterTriggerEvent

-- 改造后
-- 1. 用例层发起购买意图
MarketService.purchase_intent(player_id, goods_id)
  → 验证资格
  → 调用 PaymentGatewayPort.charge(player_id, goods_id)

-- 2. 适配器层执行实际支付
EggyPaymentGateway.charge(player_id, goods_id)
  → 映射 goods_id → platform_goods_id
  → 调用 GameAPI.purchase_goods
  → 注册回调

-- 3. 回调通过事件总线
PaymentCallbackHandler.on_paid(callback_data)
  → 发布 DomainEvent.PurchaseCompleted

-- 4. 用例层兑现
MarketService.on_purchase_completed(event)
  → 发放道具
  → 通过 OutputPort 刷新 UI
```

**风险**: 中（支付链路复杂，但模块集中）
**收益**: 支付平台可替换、可测试

---

### 阶段 5: 整理 presentation 应用规则

**目标**: presentation 层只负责 ViewModel 解释与渲染

**行动**:

```lua
-- 改造前（PreConfirmFlow.lua）
if choice.kind == "market_buy" then
  local goods = Market.goods[choice.meta.goods_id]
  -- 计算确认文案、判断逻辑
end

-- 改造后
-- 用例层输出完整的确认模型
local ConfirmModel = {
  title = "确认购买",
  message = PurchasePolicy.get_confirm_message(goods_id),
  confirm_button = "购买",
  cancel_button = "取消"
}

-- presentation 只负责渲染
UIModalPresenter.show_confirm(ConfirmModel)
```

**改造范围**:
- `src/presentation/interaction/ui_intent_dispatcher/PreConfirmFlow.lua`
- `src/presentation/ui/choice_screen_service/common.lua`
- `src/presentation/render/TargetChoiceEffects.lua`

**风险**: 中（modal/choice 交互回归）
**收益**: 防止 `choice.kind` 继续演化成跨层 DSL

---

### 阶段 6: 目录语义整理（边界稳定后）

**待澄清命名**:

| 当前 | 问题 | 建议 |
|------|------|------|
| src/core | 像"领域核心"，实际含 runtime 适配 | 外迁后保留为纯策略目录 |
| src/game/runtime vs flow | 都像用例层，分工不明确 | 文档统一解释为 use case 层 |
| src/presentation/read_model | 像独立 query 层，实际是小助手 | 保持或发展为 query adapter |

**注意**: 本阶段必须在 1-5 完成后进行，避免目录变动与逻辑变动叠加。

---

## 5. 测试策略

### 5.1 三层测试体系

```
┌─────────────────────────────────────────────────────────────┐
│ 架构守护测试 (Architecture Fitness Functions)                │
│ ├── 静态: dep_rules 扫描禁用符号和 require                   │
│ └── 动态: 拦截 state.ui_* 写入、验证 port 输出              │
├─────────────────────────────────────────────────────────────┤
│ 契约测试 (Contract Tests)                                    │
│ ├── RuntimePorts 行为契约                                    │
│ ├── TurnAction port 规范化契约                               │
│ └── ReadModel 计算一致性契约                                 │
├─────────────────────────────────────────────────────────────┤
│ 用例测试 (Use Case Tests)                                    │
│ ├── Fake Output Port 下运行 GameplayLoop                     │
│ └── 验证无真实 UI/runtime 时的完整回合流程                   │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 关键测试实现

**架构守护测试示例**:

```lua
-- tests/suites/architecture_fitness.lua
function M.test_no_new_ui_state_writes_in_flow()
  local state = create_fake_state()
  local mt = {
    __newindex = function(t, k, v)
      if k:match("^ui_") or k == "pending_choice" then
        error("Use case layer should not write " .. k)
      end
      rawset(t, k, v)
    end
  }
  setmetatable(state, mt)

  -- 运行用例
  GameplayLoop.tick(game, state, 0.016)
end
```

**集成契约测试**:

```lua
-- 验证适配器与真实外部系统的契约
function M.test_eggy_payment_gateway_contract()
  local gateway = EggyPaymentGateway.new()
  -- 使用沙箱环境或 mock server 验证
  local result = gateway.charge(test_player_id, test_goods_id)
  assert(result.transaction_id)
  assert(result.status == "pending" or result.status == "completed")
end
```

---

## 6. 权衡与风险

### 6.1 短期成本

| 项目 | 估算 | 说明 |
|------|------|------|
| 架构守护测试 | 2-3 天 | 静态规则 + 动态拦截 |
| 用例输出协议 | 5-7 天 | choice/popup/anim 事件定义与迁移 |
| game.ui_port 移除 | 7-10 天 | 15 个文件改造，动画等待逻辑重构 |
| runtime 外迁 | 3-5 天 | 6 个文件迁移 + Logger 改造 |
| Market 拆分 | 5-7 天 | 支付链路重构 |
| presentation 规则内收 | 5-7 天 | choice.kind 语义迁移 |
| **总计** | **27-39 天** | 可分阶段并行 |

### 6.2 长期收益

1. **宿主可替换性**: 可脱离 Eggy runtime 进行单元测试、离线回归
2. **UI 可替换性**: 用例层不依赖具体 UI 结构，可支持多端（PC/移动端）
3. **支付可替换性**: 支付网关可切换至其他平台
4. **新功能接入成本**: 规则集中在 game/flow 与 game/systems，不再散落到 UI
5. **架构治理成本**: 清晰的依赖规则可写成 CI 自动验证

### 6.3 风险缓解

| 风险 | 缓解措施 |
|------|----------|
| 重构引入回归 | 每个阶段前补全契约测试；保持旧路径兼容直到新路径验证通过 |
| 新旧路径长期并存 | 设定明确的 deprecated 时间表；代码中标记 TODO 移除版本 |
| 支付链路重构出故障 | 保留旧 Purchase.lua 作为 fallback；灰度切换 |
| 团队理解成本 | 编写 ADR（架构决策记录）；重构期间代码审查强化 |

---

## 7. 结论与行动项

### 7.1 核心结论

Monopoly 代码库已进入**架构迁移的收尾阶段**。它具备：
- 正确的分层骨架
- 有效的依赖规则护栏
- 可工作的端口模式

但仍需完成：
- **src/core 的宿主解耦**（P0）
- **game.ui_port 的依赖倒置**（P1）
- **use case 与 UI 状态的边界收口**（P1）

### 7.2 立即行动项

| 优先级 | 行动 | 负责人 | 验收标准 |
|--------|------|--------|----------|
| P0 | 将 dep_rules 集成至 CI | DevOps | 违反规则即构建失败 |
| P0 | 新增 core 宿主 API 守护规则 | 架构 | src/core 无法新增 GameAPI 调用 |
| P1 | 定义 Choice/Popup/Anim 输出协议 | 后端 | 协议文档 + 接口定义 |
| P1 | 迁移 Bankruptcy 的 ui_port 使用 | 后端 | 通过 NotificationPort |

### 7.3 关键原则

1. **先守护，后迁移**: 没有测试护栏的渐进式重构 = 债务翻倍
2. **小步快跑**: 每次 PR 只改一个边界点，保持回归通过
3. **ADR 文档化**: 每个架构决策记录为 Markdown，存入 `docs/architecture/`
4. **债务看板**: 追踪每个违规点的修复状态，防止报告被遗忘

---

## 附录 A: 代码抽样验证依据

### A.1 抽样范围

- `src/app/init.lua`
- `src/app/bootstrap/*` (7 files)
- `src/core/*` (21 files)
- `src/game/core/*` (15 files)
- `src/game/runtime/*` (4 files)
- `src/game/flow/*` (33 files)
- `src/game/systems/*` (board, items, land, market, chance, effects)
- `src/presentation/*` (151 files)
- `tests/internal/dep_rules.lua`
- `tests/suites/*` (40+ test files)

### A.2 验证执行

```bash
# 依赖规则验证
lua tests/internal/dep_rules.lua
# 输出: dep_rules ok

# 全量回归
lua tests/regression.lua
# 输出: All regression checks passed (361)

# 宿主 API 调用统计
cd src/core && rg "GameAPI|GlobalAPI|SetTimeOut|RegisterTriggerEvent|RegisterCustomEvent|TriggerCustomEvent" --count
# 输出: 42 matches across 6 files
```

### A.3 关键代码引用

**引用 1**: src/core/runtime_ports/DefaultPorts.lua:21
```lua
assert(GameAPI.random_int, "missing GameAPI.random_int")
```

**引用 2**: src/game/flow/turn/GameplayLoop.lua (多处)
```lua
game.ui_port = gameplay_loop_runtime.build_ui_runtime_port(state)
state.pending_choice = {...}
state.ui_dirty = true
```

**引用 3**: src/game/systems/market/service/Purchase.lua
```lua
function _build_goods_mappings() ... GameAPI.get_goods_list ... end
function _register_purchase_event_for_role() ... RegisterTriggerEvent ... end
function _start_external_purchase() ... GameAPI.open_shop_panel ... end
```

---

*报告完成*
