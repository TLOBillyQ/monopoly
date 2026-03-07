# 代码库现状研究报告（2026-03-07）

> 本文档基于当前代码库快照重写，结论只描述仓库里现在已经存在的结构、约束与问题，不追溯不可验证的历史过程。
>
> 主要证据来源：`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`src/app/`、`src/core/`、`src/game/`、`src/presentation/`、`tests/internal/dep_rules.lua`、`tests/suites/*contract.lua`。

## 执行摘要

### 架构结论

当前代码库已经基本满足 Clean Architecture 的核心约束：

- `src/app/bootstrap/` 与 `src/infrastructure/runtime/` 负责启动与宿主细节。
- `src/game/flow/` 负责用例编排与回合推进。
- `src/game/systems/` 已经成为主要玩法规则承载层，破产结算与胜负判定也已迁入 `src/game/systems/endgame/`。
- `src/presentation/` 通过 adapter / read_model / widget / canvas 承接展示，而不是直接吞掉玩法规则。

但边界仍有两处明显漏口：

- `src/game/core/player/state_ops/location_ops.lua` 直接依赖 `src/game.systems.endgame.bankruptcy`，形成 state → systems 的反向依赖。
- `src/game/systems/endgame/bankruptcy.lua` 直接读取 `game.gameplay_loop_ports`，让 systems 通过对象字段反向感知 flow/runtime 细节。

结论是：**目录层面的重构已经基本到位，当前主要问题不再是“文件放错目录”，而是“少量对象级依赖仍在跨边界泄漏”。**

## 项目概况

| 属性 | 当前值 |
|------|--------|
| 目标平台 | Eggy Game |
| 主要语言 | Lua 5.4 |
| `src/` Lua 文件数 | 297 |
| `tests/` Lua 文件数 | 47 |
| `src/` Lua 代码行数 | 24,922 |
| `tests/` Lua 代码行数 | 17,779 |

## 当前目录语义

### 顶层结构

```text
src/
├── app/                   # 启动、装配、测试场景入口
├── core/                  # 跨层稳定工具、端口、配置、运行时门面
├── game/                  # 游戏领域与用例实现
├── infrastructure/        # Eggy 宿主相关实现
└── presentation/          # UI 展示、事件映射、读模型
```

### `src/app/`

职责已经比较清晰：

- `src/app/init.lua` 负责应用级启动。
- `src/app/bootstrap/` 负责 runtime install、startup、UI bootstrap、runtime alias 安装。
- `src/app/testing/` 负责测试 profile 和测试引导。

这一层是“程序如何启动”的细节层，可以依赖其他层。

### `src/core/`

`src/core/` 现在主要是跨层稳定资产：

- `src/core/config/`：配置校验与 gameplay rules。
- `src/core/events/`：事件常量与事件边界。
- `src/core/ports/`：运行时能力与动作动画等端口。
- `src/core/runtime_facade/`：runtime context 门面。
- `src/core/runtime_ports/`：默认 runtime ports。
- `src/core/utils/`：日志、脏标记、角色 ID、数值工具。

这里已经基本摆脱“直接摸宿主全局”的旧模式，运行时访问统一收敛到 `runtime_context` / `runtime_ports`。

### `src/game/`

`src/game/` 已经形成相对稳定的子层次：

- `src/game/core/ai/`：AI 决策。
- `src/game/core/player/`：玩家状态与状态操作。
- `src/game/core/runtime/`：`Game` 聚合根、`composition_root`、`game_factory`、基础装配。
- `src/game/flow/`：回合推进、intent 分发、输出适配。
- `src/game/ports/`：玩法层对外声明的 Port 契约。
- `src/game/runtime/`：Port Adapter，目前只保留 `auto_play_port_adapter.lua` 与 `bankruptcy_port_adapter.lua`。
- `src/game/scheduler/`：协程调度。
- `src/game/systems/`：主要玩法规则系统。
- `src/game/turn_engine/`：历史执行器容器，文档已明确标记为 deprecated/frozen。

### `src/game/systems/`

当前规则主要集中在以下子域：

- `board/`
- `chance/`
- `choices/`
- `commerce/`
- `effects/`
- `endgame/`
- `items/`
- `land/`
- `market/`
- `movement/`
- `vehicle/`

其中 `src/game/systems/endgame/bankruptcy.lua` 与 `src/game/systems/endgame/game_victory.lua` 已经把“终局规则”从 `core/runtime` 中抽离出来，这与当前架构文档是对齐的。

### `src/presentation/`

展示层现在不是一个纯 Canvas 目录，而是几个稳定子域的组合：

- `adapter/`：展示层端口与 host runtime 适配。
- `canvas/`：页面级 UI。
- `canvas_runtime/`：Canvas 运行时桥接。
- `interaction/`：UI 输入到 intent/action 的映射。
- `read_model/`：UI 读取模型。
- `render/`：动画与可视反馈。
- `state/`：UI runtime state / ui_model。
- `widgets/`：可复用组件。

这说明当前展示层已经不是“UI 节点脚本堆”，而是带 adapter 边界的展示系统。

## 当前边界如何被落实

### 1. runtime 全局访问已被收敛

证据：

- `src/app/bootstrap/runtime_install.lua`
- `src/core/runtime_facade/runtime_context.lua`
- `src/core/ports/runtime_ports.lua`
- `tests/suites/runtime_ports_contract.lua`

当前策略是：

- 由 `runtime_install` 建立 context。
- 由 `runtime_ports` 提供严格模式访问。
- 测试明确约束“不再回退到 legacy fallback / context_policy”。

这是一条比较扎实的边界，说明宿主 API 访问已经不再散落在业务代码里。

### 2. flow 层承担回合编排与端口注入

证据：

- `src/game/flow/turn/gameplay_loop.lua`
- `src/game/flow/output_adapters/use_case_output_port.lua`
- `src/game/flow/output_adapters/intent_output_adapter.lua`

`gameplay_loop.lua` 会在运行时把以下能力接到 `game` 上：

- `board_scene_port`
- `popup_port`
- `tile_feedback_port`
- `anim_gate_port`
- `intent_output_port`
- `auto_play_port`
- `bankruptcy_port`

这意味着 flow 目前确实扮演“组装 use case 所需边界”的角色，而不是把规则本身写进 loop。

### 3. systems 已成为主要玩法承载层

证据：

- `src/game/systems/land/*`
- `src/game/systems/items/*`
- `src/game/systems/chance/*`
- `src/game/systems/market/*`
- `src/game/systems/endgame/*`

尤其是：

- `src/game/core/runtime/game.lua` 只保留 `Game` 聚合根与状态入口。
- `game.check_victory` 直接绑定 `src.game.systems.endgame.game_victory`。
- `bankruptcy_port_adapter` 只负责把端口适配到 `src.game.systems.endgame.bankruptcy`。

这比之前“规则和装配混在 runtime 目录里”的状态清晰很多。

### 4. 展示层与玩法层之间有测试护栏

证据：

- `tests/internal/dep_rules.lua`
- `tests/suites/architecture_guard_contract.lua`
- `tests/suites/usecase_boundary_contract.lua`

当前测试至少在以下方面起到了硬约束作用：

- `presentation/interaction` 不能直接 require `src.game.*`。
- `systems/` 不能直接 require `src.game.flow.*`。
- `systems/` 不能直接 require `src.game.core.runtime.*`。
- use case output 不能回写 legacy `state.ui_dirty`。
- runtime ports 必须走 context/strict mode，而不是旧兼容桥。

这说明边界不仅写在文档里，也被测试部分固化了。

## 主要问题（P0-P3）

### P0

当前没有发现“核心业务被外部框架直接反向控制”的新 P0 问题。

### P1：`state` 反向依赖 `systems`

**现状**

`src/game/core/player/state_ops/location_ops.lua` 直接 `require("src.game.systems.endgame.bankruptcy")`，并在医院扣费失败时直接调用 `bankruptcy.eliminate(...)`。

**为什么这是问题**

按照当前文档，`src/game/core/player/` 属于 state 侧，而 `src/game/systems/` 属于 shared-mechanics。现在 state 代码主动调用 systems 规则，说明“更右侧的状态层”反向依赖了“更左侧的规则层”。这不是目录问题，而是真实依赖方向问题。

**影响**

- `player/state_ops` 无法作为更稳定的状态层被复用。
- `bankruptcy` 规则未来若继续拆 Port，会把变更传染到 `player/state_ops`。
- dep_rules 目前没有覆盖这类 `core/player -> systems` 依赖，存在监控盲区。

### P1：`systems/endgame/bankruptcy.lua` 直接读取 `game.gameplay_loop_ports`

**现状**

`src/game/systems/endgame/bankruptcy.lua` 在 `_notify_tiles_cleared()` 中直接访问：

- `game.gameplay_loop_ports.state.on_bankruptcy_tiles_cleared`
- `game.gameplay_loop_ports.on_bankruptcy_tiles_cleared`

**为什么这是问题**

这让 systems 模块知道了 gameplay loop 的对象字段组织方式。虽然它没有 `require src.game.flow.*`，但它仍然通过运行时对象结构依赖了 flow/runtime 细节。

**影响**

- `gameplay_loop_ports` 的组织一旦变动，终局规则会被动修改。
- systems 无法只依赖稳定 Port 契约；它知道了“是谁注入、按什么字段名注入”。
- 当前 dep_rules 只能拦截 `require` 级依赖，拦不住这种“对象字段耦合”。

### P2：装配职责仍分散在 `app/bootstrap` 与 `composition_root`

**现状**

当前装配逻辑横跨：

- `src/app/bootstrap/runtime_install.lua`
- `src/app/bootstrap/game_startup.lua`
- `src/game/core/runtime/composition_root.lua`
- `src/game/flow/turn/gameplay_loop.lua`

`composition_root.lua` 负责 game 基础创建、registry、market limits、dirty tracker、turn engine、默认 adapter 安装；`app/bootstrap` 再负责 runtime context / startup / UI bootstrap；`gameplay_loop` 还会二次覆盖部分 port。

**为什么这是问题**

这并非错误，但说明“装配”目前分布在多个层次：启动装配、聚合根装配、运行时装配三者边界还没有完全极简化。

**影响**

- 新增一类运行时能力时，开发者往往需要同时理解 `app/bootstrap`、`composition_root`、`gameplay_loop` 三个入口。
- 默认值与运行时覆盖值的责任归属需要靠经验判断，而不是一眼可见。

### P3：依赖规则的监控强于对象级边界，弱于语义级边界

**现状**

`tests/internal/dep_rules.lua` 已经能防止很多路径级倒退，但它主要擅长捕获：

- 直接 `require` 错误路径
- 直接访问 runtime global
- 直接访问某些 legacy 字段

它不擅长捕获：

- `game` 对象上的临时字段耦合
- state 层对 systems 的语义反向依赖
- “通过字段名知道外层组织方式”的隐式耦合

**影响**

目录会越来越干净，但对象图耦合仍可能继续增长，只是测试暂时看不见。

## 重构方案

### 步骤 1：把 `location_ops` 的破产触发改成 Port 调用

**建议**

不要让 `src/game/core/player/state_ops/location_ops.lua` 直接 require `systems/endgame/bankruptcy.lua`。可选方案有两个：

- 方案 A：改为调用 `src/game/ports/bankruptcy_port.lua`。
- 方案 B：把“医院扣费导致破产”的结算上移到 use case / systems 层，`location_ops` 只返回状态结果。

**影响范围**

- `src/game/core/player/state_ops/location_ops.lua`
- `src/game/ports/bankruptcy_port.lua`
- 相关 gameplay / landing / status 测试

**预期收益**

修复最明确的 state → systems 反向依赖。

**回归风险**

中等。医院、停留回合、现金扣减、破产弹窗都可能受影响，需要用例级回归。

### 步骤 2：为破产后的地块清理通知补一个稳定 Port

**建议**

不要让 `src/game/systems/endgame/bankruptcy.lua` 直接摸 `game.gameplay_loop_ports`。建议引入显式 Port，例如：

- `src/game/ports/bankruptcy_feedback_port.lua`
- 或扩展已有 `tile_feedback_port`

Port 只暴露类似：

- `on_tiles_cleared(game, player, owned_tile_ids)`

adapter 再决定如何转给 gameplay loop / presentation。

**影响范围**

- `src/game/systems/endgame/bankruptcy.lua`
- `src/game/runtime/` adapter
- `src/game/flow/turn/gameplay_loop.lua`
- `src/presentation/adapter/` 相关状态端口

**预期收益**

把“终局规则”从“知道 gameplay_loop_ports 怎么长的”状态，收敛到“只知道我有一个反馈 Port”。

**回归风险**

低到中等。风险主要在事件通知链是否仍完整。

### 步骤 3：收紧 dep_rules，补齐语义级护栏

**建议**

在 `tests/internal/dep_rules.lua` 里增加两类规则：

- 禁止 `src/game/core/player/` 直接 require `src/game/systems/*`。
- 禁止 `src/game/systems/` 直接读取 `game.gameplay_loop_ports` 这类已知外层字段。

**影响范围**

- `tests/internal/dep_rules.lua`
- 可能波及少量现存实现，需要先清点再落规则

**预期收益**

让测试开始覆盖“对象级边界泄漏”，而不只覆盖路径级边界。

**回归风险**

低。主要风险是先暴露已有问题，导致一次性需要清一点旧耦合。

### 步骤 4：继续把装配责任写成更显式的分层说明

**建议**

当前不一定要马上大改 `composition_root.lua`，但至少应把以下责任写得更明确：

- 哪些默认 port 由 `composition_root` 安装
- 哪些运行时 port 由 `gameplay_loop` 覆盖
- 哪些宿主相关能力只允许出现在 `app/bootstrap` / `infrastructure/runtime`

这一步可以先以文档和 contract test 为主，不一定先动实现。

**影响范围**

- `docs/architecture/boundaries.md`
- `docs/architecture/layer-model.md`
- `tests/suites/*contract.lua`

**预期收益**

降低“新增能力时改哪一层”的决策成本。

**回归风险**

低。

## 测试建议

至少补齐以下四类验证：

### 用例级测试

- 医院扣费不足时，通过 Port 触发破产，而不是由 state 层直接 require systems。
- 破产后地块被清理、库存被清空、玩家被淘汰、弹窗与事件仍完整发出。

### 边界契约测试

- `bankruptcy_feedback_port`（或等价 Port）的默认行为、override 行为、空实现行为。
- `gameplay_loop` 注入的 port 与 `composition_root` 默认 port 的覆盖优先级。

### 依赖规则测试

- `src/game/core/player/` ↛ `src/game/systems/*`
- `src/game/systems/*` ↛ `game.gameplay_loop_ports`

### 回归测试

- `tests/suites/gameplay.lua` 中破产、落地、机会卡、市场打断相关用例。
- `tests/suites/usecase_boundary_contract.lua` 与 `tests/suites/runtime_ports_contract.lua`。

## 权衡说明

### 短期成本

- 引入新 Port 会多一层 adapter，调用链比“直接访问字段”更长。
- 破产相关逻辑分离后，需要补更多 contract test，短期改动面会变大。

### 长期收益

- systems 可以真正只依赖稳定契约，而不是依赖某个具体 `game` 对象怎么组装。
- state 层可以回到更稳定的位置，避免被玩法规则牵着走。
- 后续如果替换 `gameplay_loop` 或调整 UI 状态输出，终局规则不必跟着改。

## 当前验收结论

从当前仓库来看，可以得出以下结论：

1. **目录语义已经基本成型。** `app / core / game / infrastructure / presentation` 的职责比之前清晰得多。
2. **大部分关键边界已经有测试护栏。** 特别是 runtime strict mode、presentation ↛ game、systems ↛ flow、legacy bridge 移除等方向。
3. **本轮最重要的收获，是 `src/game/core/runtime` 已明显收窄。** 终局规则已迁出到 `src/game/systems/endgame/`，这是正确方向。
4. **下一阶段不该再做大面积目录搬家。** 更有价值的是补对象级 Port、收紧 dep_rules、消除少量反向依赖。

换句话说，当前代码库已经从“结构混杂，需要大拆目录”的阶段，进入了“结构基本正确，需要抠边界细节”的阶段。
