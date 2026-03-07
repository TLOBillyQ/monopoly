# 代码库现状研究报告（2026-03-07）

> 本文档描述当前仓库已经落地的事实，不追溯不可验证的历史过程。
>
> 主要证据来源：`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`src/app/`、`src/core/`、`src/game/`、`src/infrastructure/`、`src/presentation/`、`tests/internal/dep_rules.lua`、`lua tests/regression.lua`。

## 执行摘要

当前代码库已经完成本轮“兼容层与 legacy 债务清理”的主要目标，仓库状态从“研究中建议清理”进入“已落地收口”。

### 当前结论

- `src/app/bootstrap/` 与 `src/infrastructure/runtime/` 负责启动与宿主细节
- `src/game/flow/` 负责用例编排、回合推进、输入校验与输出端口协同
- `src/game/systems/` 是主要玩法规则承载层；破产与胜负判定已稳定位于 `src/game/systems/endgame/`
- `src/presentation/` 负责 UI 展示、事件映射、读模型和渲染适配
- `state.ui_runtime` 已成为 UI runtime 的唯一真源；root UI 字段不再作为生产读路径
- runtime façade 路线已经确定为 **方案 B**：调用方统一直接引用 `src/infrastructure/runtime/*` 真实实现，纯转发壳已删除

### 本轮已完成的关键收口

1. **删除纯兼容壳与导入别名壳**
   - `src/game/flow/output_adapters/legacy_output_mirror.lua` 已删除
   - `src/game/systems/market/service/paid_purchase_gateway.lua` 已删除
2. **删除历史 runtime façade 壳**
   - `src/core/runtime_facade/runtime_context.lua` 已删除
   - `src/core/runtime_facade/runtime_event_bridge.lua` 已删除
   - `src/core/runtime_ports/default_ports.lua` 已删除
3. **完成 UI runtime state 迁移**
   - `runtime_state.ensure_ui_runtime()` 不再从 root state seed 新结构
   - `presentation` 与 `flow` 的生产读写已切到 `ui_runtime` / `runtime_state.*`
4. **收缩宿主全局别名使用面**
   - `SetTimeOut` / `RegisterCustomEvent` / `TriggerCustomEvent` 的使用已收口到 bootstrap 外壳与极少数兼容点
   - `tests/internal/dep_rules.lua` 已新增增长预算与 forbidden file 防回流
5. **移除历史 loop 对象泄漏**
   - `game.gameplay_loop_ports` 写入已删除；生产代码使用显式 port/状态对象

**结论：当前仓库已从“架构重组期”进入“边界稳定 + 债务冻结期”。** 接下来的工作重点不再是继续大规模搬目录，而是围绕已形成的边界做小步精修。

## 项目概况

| 属性 | 当前值 |
|------|--------|
| 目标平台 | Eggy Game |
| 主要语言 | Lua 5.4 |
| `src/` Lua 文件数 | 293 |
| `tests/` Lua 文件数 | 46 |
| `src/` Lua 代码行数 | 24,913 |
| `tests/` Lua 代码行数 | 17,872 |

## 当前目录语义

### 顶层结构

```text
src/
├── app/                   # 启动、装配、bootstrap、测试引导
├── core/                  # 跨层稳定工具、配置、状态 façade（仅保留 runtime_state）
├── game/                  # 游戏领域、用例流、ports、runtime adapter
├── infrastructure/        # Eggy 宿主真实实现
└── presentation/          # UI 展示、交互映射、读模型、渲染
```

### `src/app/`

`src/app/` 是最外层装配区：

- `src/app/init.lua` 负责应用级启动与最后一层兼容调度
- `src/app/bootstrap/` 负责 runtime install、startup、UI bootstrap、alias 安装
- `src/app/testing/` 负责测试 profile 与测试引导

这一层可以依赖其他层，因为它表达的是“程序如何启动”。

### `src/core/`

`src/core/` 当前主要承载跨层稳定资产：

- `src/core/config/`：配置、feature toggle、runtime constant、sanity
- `src/core/events/`：事件常量与事件边界
- `src/core/ports/`：runtime 访问、动作动画等稳定契约
- `src/core/runtime_facade/runtime_state.lua`：UI / board / anim / turn runtime 的状态 façade
- `src/core/utils/`：日志、dirty tracker、角色 ID、数值工具

需要特别说明的是：**`src/core/runtime_facade/` 不再承载 runtime_context / event_bridge façade。** 这些运行时真实实现已经统一收口到 `src/infrastructure/runtime/`。

### `src/game/`

`src/game/` 现在分成几块职责清晰的子层：

- `src/game/core/ai/`：AI 决策
- `src/game/core/player/`：玩家状态与状态操作
- `src/game/core/runtime/`：`Game` 聚合根、`composition_root`、`game_factory`
- `src/game/flow/`：回合推进、intent 分发、输出协同
- `src/game/ports/`：玩法层对外声明的 Port 契约
- `src/game/runtime/`：Port Adapter，目前保留贴近 gameplay 的 adapter
- `src/game/scheduler/`：协程调度
- `src/game/systems/`：主要玩法规则系统
- `src/game/turn_engine/`：deprecated/frozen 的历史执行器容器，仍存在但已明确不再扩展职责

### `src/infrastructure/runtime/`

这是当前 runtime 真实实现的集中区，已经成为宿主细节的唯一真实所有者，主要包含：

- `runtime_context.lua`
- `runtime_event_bridge.lua`
- `default_ports.lua`

所有新 runtime 能力都应优先落在这里，而不是回写到 `src/core` 或 `src/game/flow`。

### `src/presentation/`

展示层已经形成 adapter 风格组织：

- `adapter/`：展示侧 Port 与 host runtime 适配
- `canvas/`：页面级 UI 结构
- `canvas_runtime/`：Canvas 运行时桥接
- `interaction/`：UI 输入到 action/intent 的映射
- `read_model/`：UI 读模型
- `render/`：动画与可视反馈
- `state/`：UI 模型与状态结构
- `widgets/`：可复用组件

这里已经不再承担“补业务语义”的责任，而是消费上层显式给出的 choice / popup / market / countdown 等视图语义。

## 当前边界如何被落实

### 1. runtime 全局访问已经被集中收口

证据：
- `src/app/bootstrap/runtime_install.lua`
- `src/core/ports/runtime_ports.lua`
- `src/infrastructure/runtime/runtime_context.lua`
- `src/infrastructure/runtime/default_ports.lua`
- `tests/suites/runtime_ports_contract.lua`

当前策略：
- `runtime_install` 创建 context 并装配默认 ports
- `runtime_ports` 作为稳定访问入口
- 真实 runtime 实现统一位于 `src/infrastructure/runtime/`
- 原 façade 文件已删除，避免“双重所有权错觉”

### 2. flow 层承担用例编排与 Port 注入

证据：
- `src/game/flow/turn/gameplay_loop.lua`
- `src/game/flow/turn/gameplay_loop_ports.lua`
- `src/presentation/adapter/presentation_ports.lua`

`gameplay_loop.set_game()` 当前会把以下能力接到 `game` 上：
- `board_scene_port`
- `popup_port`
- `tile_feedback_port`
- `bankruptcy_feedback_port`
- `anim_gate_port`
- `intent_output_port`
- `auto_play_port`
- `bankruptcy_port`

与上一阶段不同的是，**`game.gameplay_loop_ports` 历史写入已删除**，systems 不再能绕过 port 直接接触 loop runtime 对象。

### 3. systems 与 loop runtime 对象已切断直连

证据：
- `src/game/ports/bankruptcy_feedback_port.lua`
- `src/game/runtime/bankruptcy_port_adapter.lua`
- `src/game/systems/endgame/bankruptcy.lua`
- `tests/internal/dep_rules.lua`

当前状态：
- `src/game/systems/endgame/bankruptcy.lua` 通过 `bankruptcy_feedback_port` 发出稳定语义
- `tests/internal/dep_rules.lua` 显式禁止 `src/game/systems/*` 读取 `game.gameplay_loop_ports`

这说明最危险的一类“对象级反向泄漏”已经被结构化切断。

### 4. UI runtime 已完成 root-state 迁移

证据：
- `src/core/runtime_facade/runtime_state.lua`
- `src/presentation/widgets/ui_modal_presenter.lua`
- `src/presentation/interaction/ui_modal_state_coordinator.lua`
- `tests/suites/ui_runtime_state_contract.lua`

当前状态：
- `runtime_state.ensure_ui_runtime()` 只负责确保新结构存在并给出默认值
- 不再从 `state.ui_dirty`、`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` seed 新结构
- `ui_runtime` 成为唯一真源；root UI 字段仅可能出现在测试夹具或历史兼容上下文中，不再是生产读路径

### 5. 宿主全局别名使用面已显著缩小

证据：
- `src/app/bootstrap/runtime_install/runtime_global_aliases.lua`
- `src/app/init.lua`
- `tests/internal/dep_rules.lua`

当前状态：
- `SetTimeOut` / `RegisterCustomEvent` / `TriggerCustomEvent` 的直接使用已经被压缩到 bootstrap 外壳与少量兼容点
- `presentation` 层事件注册已改走 `runtime_context` / `host_runtime_port`
- `ui_bootstrap` 延时调度已改走 `runtime_ports.schedule`
- `dep_rules` 已新增增长预算，防止使用面再次扩散

## 当前仍然存在的遗留点

### 1. `src/game/turn_engine/` 仍在主树中

当前状态：
- 文档已明确其为 deprecated/frozen 历史执行器容器
- 仍由 `src/game/core/runtime/composition_root.lua` 承接装配
- 它不再是新逻辑的推荐落点，但尚未完全退场

判断：
- 这是一笔**已冻结、可控、可观察**的历史债务
- 当前优先级低于“继续保持 runtime / systems / presentation 边界不回流”

### 2. `src/app/init.lua` 仍保留最后一层兼容调度

当前状态：
- `src/app/init.lua` 中仍保留对 `SetTimeOut` 的直接读取作为启动壳兼容点
- 该使用面已被 `dep_rules` 冻结，不再允许扩散

判断：
- 这是刻意保留在最外层的一小块兼容壳，而不是新的边界回流

## 已删除的兼容层 / 转发壳

以下对象已不再存在于当前仓库：

- `src/game/flow/output_adapters/legacy_output_mirror.lua`
- `src/game/systems/market/service/paid_purchase_gateway.lua`
- `src/core/runtime_facade/runtime_context.lua`
- `src/core/runtime_facade/runtime_event_bridge.lua`
- `src/core/runtime_ports/default_ports.lua`
- `tests/suites/legacy_output_mirror_contract.lua`

`tests/internal/dep_rules.lua` 已把这些文件列为 forbidden files，防止回流。

## 当前测试与护栏状态

### 回归状态

已验证：

- 运行 `lua tests/regression.lua`
- 预期结果为：
  - `All regression checks passed (377)`
  - `dep_rules ok`
  - `forbidden_globals ok`

### 边界护栏

当前护栏主要包括：

- `tests/internal/dep_rules.lua`
  - 禁止 systems 依赖 `src.game.flow.*`
  - 禁止 systems 依赖 `src.game.core.runtime.*`
  - 禁止 systems 读取 `game.gameplay_loop_ports`
  - 禁止已删除 façade / 兼容壳文件重新出现
  - 冻结 app/presentation 中宿主全局别名使用面的增长预算
- `tests/internal/forbidden_globals.lua`
- `tests/internal/gameplay_loop_no_ui.lua`

这说明仓库已经不仅有“文档约定”，还有持续执行的结构性守卫。

## 当前最重要的架构判断

### 1. 主架构已经稳定

目前 `app / core / game / infrastructure / presentation` 的职责边界已经比早期状态清晰得多，而且关键依赖方向有测试护栏托底。

### 2. runtime 真正所有权已经明确

方案 B 落地后，runtime 的真实实现统一位于 `src/infrastructure/runtime/`。这比 façade 并存阶段更直接，也减少了“到底哪里才是正式出口”的歧义。

### 3. 兼容债务已经从“失控”转为“冻结”

最噪音的 pure forwarder / legacy bridge 已经删除；剩余遗留点主要是：
- `src/game/turn_engine/`
- `src/app/init.lua` 的最后兼容调度点

它们已经被文档和 dep_rules 共同限定，不再处于继续扩散的状态。

## 下一阶段建议

基于当前快照，下一阶段高价值工作不再是继续大拆分，而是围绕稳定边界做精修：

1. **继续冻结 `src/game/turn_engine/`**
   - 统计剩余生产 import 面
   - 明确退出条件
   - 避免任何新职责进入该目录

2. **继续把 runtime 宿主细节限制在 outer shell**
   - 保持 `src/infrastructure/runtime/` 是唯一真实实现
   - 保持 `app/bootstrap` 是唯一允许安装 alias 的地方

3. **围绕 `ui_runtime` 真源继续删测试夹具中的 root-state 假设**
   - 当前生产代码已完成迁移
   - 后续可以继续清理测试辅助代码中的历史兼容形状

4. **维持 dep_rules 的 decay-only 治理**
   - 新 debt 只能更少，不能更多
   - 对少数保留兼容点继续用增长预算冻结

## 当前验收结论

从当前仓库快照可以得出以下结论：

1. **主架构已经基本稳定。** 目录职责、依赖方向和 port 注入关系都已较清晰。
2. **本轮兼容层清理已经完成。** 纯兼容壳、pure forwarder façade、legacy UI state seed 都已落地删除或收口。
3. **runtime 所有权已经明确到 `src/infrastructure/runtime/`。** 方案 B 已完成，不再存在 façade 与真实实现并存的双重所有权错觉。
4. **当前仓库已进入“边界稳定 + 债务冻结期”。** 接下来更适合做精修和继续冻结历史目录，而不是再次大范围重组。

换句话说，当前代码库已经从“架构重组期”正式进入“架构维护期”。
