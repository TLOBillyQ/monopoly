# 代码库现状研究报告（2026-03-07）

> 本文档基于当前代码库快照，结论只描述仓库里现在已经存在的结构、兼容层、转发层与遗留债务，不追溯不可验证的历史过程。
>
> 主要证据来源：`docs/architecture/boundaries.md`、`docs/architecture/layer-model.md`、`src/app/`、`src/core/`、`src/game/`、`src/presentation/`、`tests/internal/dep_rules.lua`。

## 执行摘要

### 架构结论

当前代码库已经基本满足 Clean Architecture 的核心约束：

- `src/app/bootstrap/` 与 `src/infrastructure/runtime/` 负责启动与宿主细节
- `src/game/flow/` 负责用例编排与回合推进
- `src/game/systems/` 是主要玩法规则承载层；破产结算、胜负判定均已进入 `src/game/systems/endgame/`
- `src/presentation/` 通过 adapter / read_model / widget / canvas 承接展示

**最近一轮边界收口已切断两条关键泄漏**（见 `.agents/plan.md` 历史记录）：
- `src/game/core/player/state_ops/location_ops.lua` 不再直连 `systems/endgame/bankruptcy`，而是通过 `bankruptcy_port` 触发
- `src/game/systems/endgame/bankruptcy.lua` 不再直读 `game.gameplay_loop_ports`，而是走 `bankruptcy_feedback_port`

因此，当前代码库的主要问题已不再是"规则模块放错目录"，而是：

1. **兼容/转发层仍然偏多，真实所有权不够一眼可见**
2. **部分 legacy 迁移壳仍然存在，但价值已经下降**
3. **宿主全局别名与旧 state 迁移痕迹仍在，属于下一阶段应该主动收缩的范围**

**结论：当前仓库已进入"清兼容层、删转发壳、退 legacy 迁移桥"的阶段。**

## 项目概况

| 属性 | 当前值 |
|------|--------|
| 目标平台 | Eggy Game |
| 主要语言 | Lua 5.4 |
| `src/` Lua 文件数 | 298 |
| `tests/` Lua 文件数 | 47 |
| `src/` Lua 代码行数 | 24,948 |
| `tests/` Lua 代码行数 | 17,827 |

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

- `src/app/init.lua` 负责应用级启动
- `src/app/bootstrap/` 负责 runtime install、startup、UI bootstrap、runtime alias 安装
- `src/app/testing/` 负责测试 profile 和测试引导

这一层是"程序如何启动"的细节层，可以依赖其他层。

### `src/core/`

`src/core/` 当前主要承载跨层稳定资产：

- `src/core/config/`：配置校验、feature toggle、runtime constant
- `src/core/events/`：事件常量与事件边界
- `src/core/ports/`：runtime 访问与动作动画等稳定契约
- `src/core/runtime_facade/`：运行时 façade / state façade / role global façade
- `src/core/runtime_ports/`：默认 runtime ports 的 façade 出口
- `src/core/utils/`：日志、dirty tracker、角色 ID、数值工具

这里已经摆脱"业务代码直接摸宿主全局"的旧模式，但仍保留若干 façade 与迁移桥。

### `src/game/`

`src/game/` 现在分成几块相对稳定的子层：

- `src/game/core/ai/`：AI 决策
- `src/game/core/player/`：玩家状态与状态操作
- `src/game/core/runtime/`：`Game` 聚合根、`composition_root`、`game_factory` 等装配
- `src/game/flow/`：回合推进、intent 分发、输出适配
- `src/game/ports/`：玩法层对外声明的 Port 契约
- `src/game/runtime/`：Port Adapter，目前只保留少量 gameplay 适配器
- `src/game/scheduler/`：协程调度
- `src/game/systems/`：主要玩法规则系统
- `src/game/turn_engine/`：历史执行器容器，文档已标记为 deprecated/frozen

### `src/game/systems/`

当前主要规则位于：

- `board/` - 游戏板相关逻辑
- `chance/` - 机会卡系统
- `choices/` - 选择系统
- `commerce/` - 交易系统
- `effects/` - 效果系统
- `endgame/` - 终局规则（破产、胜负判定）
- `items/` - 道具系统
- `land/` - 地块系统
- `market/` - 市场系统
- `movement/` - 移动系统
- `vehicle/` - 载具系统

其中 `src/game/systems/endgame/bankruptcy.lua` 负责破产结算，`src/game/systems/endgame/game_victory.lua` 负责胜负判定。

### `src/presentation/`

展示层现在已经形成 adapter 风格组织：

- `adapter/`：展示侧 Port 与 host runtime 适配
- `canvas/`：页面级 UI
- `canvas_runtime/`：Canvas 运行时桥接
- `interaction/`：UI 输入到 action/intent 的映射
- `read_model/`：UI 读模型
- `render/`：动画与可视反馈
- `state/`：UI runtime state / ui_model
- `widgets/`：可复用组件

这表明 presentation 已不再只是"节点脚本堆"，而是一个带稳定 adapter 边界的展示层。

## 当前边界如何被落实

### 1. runtime 全局访问已经被集中收口

证据：
- `src/app/bootstrap/runtime_install.lua`
- `src/core/ports/runtime_ports.lua`
- `src/core/runtime_facade/runtime_context.lua`
- `tests/suites/runtime_ports_contract.lua`

当前策略：
- `runtime_install` 创建 context 并装配默认 ports
- `runtime_ports` 作为业务侧的稳定访问入口
- runtime install 已明确拒绝 `context_policy = legacy` 和 `enable_legacy_helper_fallback = true` 这类旧选项

### 2. flow 层承担用例编排与运行时 Port 注入

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

这意味着 flow 已经是运行时边界注入中心，而不是直接承载业务规则本身。

### 3. state → systems 与 systems → gameplay_loop_ports 两条关键泄漏已被切断

证据：
- `src/game/core/player/state_ops/location_ops.lua`
- `src/game/systems/endgame/bankruptcy.lua`
- `src/game/ports/bankruptcy_feedback_port.lua`
- `tests/internal/dep_rules.lua`

当前状态：
- `location_ops.lua` 通过 `src/game/ports/bankruptcy_port.lua` 触发破产
- `bankruptcy.lua` 通过 `src/game/ports/bankruptcy_feedback_port.lua` 发地块清空反馈
- `dep_rules` 已新增 `core/player ↛ systems` 和 `systems ↛ game.gameplay_loop_ports`

这标志着本轮边界收口已经从"目录级整理"推进到了"对象级耦合切断"。

### 4. 兼容壳多数已经从"行为兼容"退化到"导入兼容"

证据：
- `src/core/runtime_facade/runtime_context.lua` - 单行转发
- `src/core/runtime_facade/runtime_event_bridge.lua` - 单行转发
- `src/core/runtime_ports/default_ports.lua` - 单行转发

这些文件已经不再自己承载复杂逻辑，而是单行转发到 `src/infrastructure/runtime/*` 的对应模块。说明它们的作用已经从"真正的兼容逻辑"退化为"稳定 import 路径壳"。

## 兼容 / 转发 / legacy 盘点

### A. 活跃但必要的桥接层

| 类型 | 路径 | 当前职责 | 结论 |
|------|------|----------|------|
| 宿主全局别名安装 | `src/app/bootstrap/runtime_install/runtime_global_aliases.lua` | 把 `LuaAPI` / `GameAPI` 能力映射到 `SetTimeOut`、`RegisterCustomEvent`、`TriggerCustomEvent` 等宿主全局名 | 仍然活跃；短期必要，但应该继续限制在 bootstrap/app 边界 |
| 角色全局安装 | `src/core/runtime_facade/ui_role_globals.lua` | 写入 `all_roles` / `ALLROLES` 给 UIManager 侧使用 | 仍然活跃；属于宿主/UI 兼容桥 |
| 展示侧 grouped ports | `src/presentation/adapter/presentation_ports.lua` | 组装 modal/anim/ui_sync/debug/clock/state 端口 | 不是 legacy，而是当前正式 adapter 边界 |
| gameplay loop grouped port resolver | `src/game/flow/turn/gameplay_loop_ports.lua` | 为 loop 解析 grouped override；拒绝 legacy flat override | 当前正式边界，但内部仍带一点兼容形态判断 |
| runtime state façade | `src/core/runtime_facade/runtime_state.lua` | 统一读写 `ui_runtime / board_runtime / anim_runtime / turn_runtime / debug_runtime` | 正在承载 state 迁移，但仍保留 legacy seed 逻辑 |

### B. 纯转发壳（import-stable shell）

| 路径 | 当前形态 | 使用状态 | 判断 |
|------|----------|----------|------|
| `src/core/runtime_facade/runtime_context.lua` | 单行 `return require(...)` | 被 `runtime_ports`、`runtime_install`、测试等广泛 import | 纯转发壳；要么保留为公开 API，要么未来统一改 import 后删除 |
| `src/core/runtime_facade/runtime_event_bridge.lua` | 单行 `return require(...)` | 被 `monopoly_events`、presentation、测试等使用 | 纯转发壳；问题同上 |
| `src/core/runtime_ports/default_ports.lua` | 单行 `return require(...)` | 被 `runtime_ports.lua` 使用 | 纯转发壳；低风险清理候选 |
| `src/game/systems/market/service/paid_purchase_gateway.lua` | 单行 `return require(...)` | 生产代码已直接依赖 `src.game.systems.market.ports.paid_purchase_port`，该壳当前只剩名义出口价值 | 高概率可删或标记为过渡别名 |

### C. 明确的 legacy 迁移壳 / 兼容残留

| 路径 | 现状 | 风险 |
|------|------|------|
| `src/core/runtime_facade/runtime_state.lua` | `ensure_ui_runtime()` 仍会把根级 `state.ui_dirty`、`state.ui_model`、`state.pending_choice`、`state.ui_modal_*` 等旧字段 seed 进 `ui_runtime`；还保留 `_legacy_choice_seeded` 分支 | 说明 UI runtime 迁移尚未完全结束；新代码虽然不应回写旧字段，但旧字段仍在被读取作为 seed 来源 |
| `src/game/flow/output_adapters/legacy_output_mirror.lua` | 仅做 output_ports 的薄包装；全仓生产代码没有引用，只剩 `tests/suites/legacy_output_mirror_contract.lua` 在验证它"不再回写 root legacy state" | 极像"已经失去生产价值的兼容壳"；可以优先清理 |
| `game.gameplay_loop_ports` 字段 | 仍在 `src/game/flow/turn/gameplay_loop.lua:163` 中写入（`game.gameplay_loop_ports = ports`），但当前 `src/` 生产代码已经不再读取该字段 | 很可能是历史兼容残留；当前真正活跃的是 `state.gameplay_loop_ports` |
| `src/game/turn_engine/` | 文档明确标记 deprecated/frozen，但仍在 `composition_root.lua` 中被使用 | 历史执行器容器，若长期保留，应进一步明确只读/不可新增代码 |

### D. 已被测试护栏冻结的 retired 路径与策略

证据集中在 `tests/internal/dep_rules.lua`：

- `src.core.runtime_compat` retired
- `src.game.core.runtime.TurnEngine` / `PhaseRegistry` retired（作为 core runtime 代理）
- `MonopolyEvents` 旧桥 retired
- `clock.now/diff_seconds` retired
- `legacy flat gameplay_loop_ports` retired
- `context_policy = legacy` retired
- `enable_legacy_helper_fallback = true` retired
- `core/player ↛ systems` 已禁止
- `systems ↛ game.gameplay_loop_ports` 已禁止

这些已经不是"活跃兼容层"，而是"测试明确禁止再复活的历史路径"。

## 主要问题（P0-P3）

### P0

当前没有发现新的 P0：核心业务没有再被外部框架直接反向控制，且最近两条关键对象级泄漏已经被切断。

### P1：宿主全局别名兼容层仍然活跃，且范围不小

**现状**

- `runtime_global_aliases.install()` 仍会写入 `SetTimeOut`、`RegisterCustomEvent`、`TriggerCustomEvent` 等宿主全局名
- `ui_role_globals.install()` 仍会写入 `all_roles` / `ALLROLES`
- `app/bootstrap/ui_bootstrap.lua`、`presentation/adapter/host_runtime_port.lua`、`game_startup_event_bridge.lua` 等外层模块仍直接依赖这些全局名

**为什么这是问题**

这不是分层错误，但说明"strict-only runtime install"并不等于"全局名已经退休"。当前只是把全局写入限制到了更外层；它们仍是活跃兼容机制。

**影响**

- 宿主接入边界不够单一，既有 `runtime_ports/context`，又有宿主全局别名
- 新代码稍不注意就可能在 app/presentation 层继续扩大对全局的依赖面
- 测试里需要持续 patch 这些全局，维护成本偏高

### P1：UI runtime 迁移尚未完全完成，`runtime_state` 仍在 seed 旧字段

**现状**

`src/core/runtime_facade/runtime_state.lua` 的 `ensure_ui_runtime()` 仍会把旧根级字段 seed 到 `ui_runtime`：

- `state.ui_dirty`
- `state.ui_model`
- `state.pending_choice`
- `state.pending_choice_id`
- `state.pending_choice_elapsed`
- `state.ui_modal_elapsed`
- `state.ui_modal_ref`
- 以及 `_legacy_choice_seeded` 相关字段

**为什么这是问题**

这说明虽然写路径大多已迁到 `ui_runtime`，但读路径仍在兼容旧结构。也就是说，状态模型已经"新结构主导"，但还没有彻底摆脱旧 state 形状。

**影响**

- state 形状的真实标准不够单一
- 读者很难一眼判断"哪些根字段还允许存在"
- 后续如果有人继续补旧根字段，兼容 seed 会默默接住，降低问题暴露速度

### P2：多处纯转发壳继续存在，所有权表达不够直接

**现状**

当前至少有 4 个明显的纯转发壳：

- `src/core/runtime_facade/runtime_context.lua`
- `src/core/runtime_facade/runtime_event_bridge.lua`
- `src/core/runtime_ports/default_ports.lua`
- `src/game/systems/market/service/paid_purchase_gateway.lua`

其中前三个仍有稳定 import 价值，第四个则连生产代码都已基本不再使用。

**为什么这是问题**

转发壳本身不危险，但会制造"双重所有权错觉"：

- 读者可能误以为逻辑属于 `src/core/runtime_facade/*`，实际上真正实现已在 `src/infrastructure/runtime/*`
- 市场支付网关的 service 路径别名则会继续模糊"port 在哪、service 在哪"

**影响**

- 代码导航成本增加
- 新人更难判断"应该改 façade 还是改实现"
- 某些壳如果长期只剩单行 `return require(...)`，维护价值会低于认知负担

### P2：`game.gameplay_loop_ports` 很可能已经退化为历史兼容字段

**现状**

当前 `src/game/flow/turn/gameplay_loop.lua:163` 仍会写 `game.gameplay_loop_ports = ports`，但在当前 `src/` 生产代码里，`game.gameplay_loop_ports` 已不再有正常消费方（只有 `state.gameplay_loop_ports` 读取）。

**为什么这是问题**

这意味着 `game.gameplay_loop_ports` 很可能已经从"活跃接口"退化成"历史兼容写入"。

**影响**

- 增加对象图噪音
- 让读者误以为 `game` 仍应该感知 loop port 组
- 如果未来有人再次读取它，会把刚切断的对象级耦合重新引回来

### P3：部分 legacy 模块已接近"仅为测试存在"

**现状**

- `src/game/flow/output_adapters/legacy_output_mirror.lua` 当前只有测试使用
- `src/game/systems/market/service/paid_purchase_gateway.lua` 目前更像历史导入别名
- `src/game/turn_engine/` 虽然有文档说明，但仍作为目录实体留在主代码树里

**为什么这是问题**

这类模块不是立刻有害，但会不断制造"是不是还活着"的认知成本。

**影响**

- 代码树噪音增大
- 清理意愿被拖延，久而久之又会变成"没人敢动"的历史包袱

### P3：架构文档略滞后于最新 Port 收口

**现状**

`docs/architecture/boundaries.md` 与 `docs/architecture/layer-model.md` 现在已经正确描述了 `endgame` 规则从 `core/runtime` 移出，但还没有明确写出：

- `bankruptcy_feedback_port` 的存在
- `core/player ↛ systems`
- `systems ↛ game.gameplay_loop_ports`

**影响**

实现已比文档更先进，下一位开发者只能从代码和测试推断最新边界。

## 清理方案

下面给出按风险与收益排序的清理路径。核心原则是：**先删死壳，再收紧活桥，最后决定 façade 是公开 API 还是过渡路径。**

### 步骤 1：先删"只剩名义价值"的兼容壳

**目标**

优先去掉对运行行为没有实质贡献、但会增加认知噪音的模块。

**建议目标**

- `src/game/flow/output_adapters/legacy_output_mirror.lua`
- `src/game/systems/market/service/paid_purchase_gateway.lua`
- `game.gameplay_loop_ports` 写入（前提是确认 `src/` 无生产读取）

**实施方式**

- 先把相关测试改成直接验证正式接口，而不是验证 legacy 包装壳
- 对 `game.gameplay_loop_ports`，先加回归/grep 验证，再删写入

**预期收益**

最低风险地减少代码树噪音，立刻提高"现在谁是正式接口"的可见性。

**回归风险**

低。

### 步骤 2：完成 UI runtime state 迁移，收掉 root-state seed

**目标**

让 `runtime_state.ensure_ui_runtime()` 不再从旧根级字段 seed 新结构。

**建议动作**

- 清点仍读取 root 字段的模块与测试
- 把剩余读路径全部切到 `ui_runtime` / `runtime_state.*`
- 最后删除 `_legacy_choice_seeded` 分支和 root-state seed 行为

**重点文件**

- `src/core/runtime_facade/runtime_state.lua`
- `src/game/flow/output_adapters/use_case_output_port.lua`
- `src/presentation/state/` / `src/presentation/widgets/` / `tests/suites/*ui*_contract.lua`

**预期收益**

统一 state 形状，降低"新旧状态共存"的隐性复杂度。

**回归风险**

中等。UI 选择态、modal timer、pending choice 很容易因为历史字段漏迁移而出问题。

### 步骤 3：收缩宿主全局别名使用面

**目标**

把 `SetTimeOut`、`RegisterCustomEvent`、`TriggerCustomEvent`、`all_roles` 等宿主全局的使用范围继续压缩到最外层。

**建议动作**

- 保留 `runtime_global_aliases.install()` 和 `ui_role_globals.install()` 作为 bootstrap 内部实现细节
- 审查 `app/` 与 `presentation/` 中直接读取这些全局的模块；凡是能走 `runtime_ports`、`host_runtime_port`、`runtime_context` 的，优先改走显式接口
- 给 `tests/internal/dep_rules.lua` 增加更细的白名单或增长预算，防止使用面再次扩散

**预期收益**

让"宿主全局名"从显式 API 退化成真正的内部兼容细节。

**回归风险**

中等。因为 UI bootstrap、事件绑定和 tick 循环都与宿主全局有交互。

### 步骤 4：对 façade 做一次明确取舍

**目标**

解决"`src/core/runtime_facade/*` / `src/core/runtime_ports/*` 到底是长期公开 API，还是过渡壳"这个问题。

**两种可选路线**

- **路线 A：正式承认 façade 为稳定 import 面**
  - 保留 `src/core/runtime_facade/runtime_context.lua`
  - 保留 `src/core/runtime_facade/runtime_event_bridge.lua`
  - 保留 `src/core/runtime_ports/default_ports.lua`
  - 在文档中明确它们是唯一推荐入口
- **路线 B：统一改 import 到真实实现后删除 façade**
  - 把调用方直接切到 `src/infrastructure/runtime/*`
  - 删除纯转发壳

**建议**

如果仍希望保持"内层不 import infrastructure"，就采用路线 A，并把这些 façade 明确记为正式边界；否则就采用路线 B，一次性删掉单行壳。

**预期收益**

消除所有权歧义。

**回归风险**

低到中等，主要取决于 import 面是否广。

### 步骤 5：继续冻结并最终清理 `src/game/turn_engine/`

**目标**

让历史执行器从"代码树里还活着的旧容器"进一步退化为真正的历史归档。

**建议动作**

- 统计 `src/game/turn_engine/` 的生产 import 面（当前仅在 `composition_root.lua` 中使用）
- 若仍有活跃 import，先记录用途与退出条件
- 若 import 已降到零，考虑迁到 `deprecated/`、`archive/` 或移出主路径树

**预期收益**

减少"旧执行器是否还能继续加代码"的歧义。

**回归风险**

低，前提是 import 面已经清楚。

### 步骤 6：同步文档，让"实现 > 文档"的差距收口

**建议同步项**

- 在 `docs/architecture/boundaries.md` 增加 `bankruptcy_feedback_port` 作为"systems 不直接感知 loop 对象"的例子
- 在 `docs/architecture/layer-model.md` 增加：
  - `core/player ↛ systems`
  - `systems ↛ game.gameplay_loop_ports`
  - `legacy_output_mirror` / `turn_engine` 的退休方向（如决定了的话）

**预期收益**

避免下一位开发者只能靠 grep 猜当前边界。

## 测试建议

清理兼容层时，建议按以下顺序补和跑测试：

### 1. 用例级回归

- 破产后地块清空、库存清空、淘汰、反馈事件
- 医院扣费失败触发破产
- 市场支付、载具开关、状态同步不受清理兼容层影响

### 2. 契约测试

- `runtime_ports_contract`
- `usecase_boundary_contract`
- `legacy_output_mirror_contract`（若决定删除该模块，则应一并删除或替换为正式接口测试）

### 3. 边界守卫测试

- `tests/internal/dep_rules.lua`
- `tests/internal/forbidden_globals.lua`
- `tests/internal/gameplay_loop_no_ui.lua`

### 4. 全量回归

- 运行 `lua tests/regression.lua`
- 预期：`All regression checks passed (...)`、`dep_rules ok`、`forbidden_globals ok`

## 权衡说明

### 短期成本

- 清兼容层会碰到不少测试，因为很多 contract 本身就是为迁移期留的
- 删除纯转发壳虽然代码少，但需要先统一 import 面，否则会引发"大量小改"
- UI runtime state 迁移完成前，删 legacy seed 风险不低

### 长期收益

- 新人可以更快判断"哪里是正式 API，哪里只是兼容桥"
- 生产代码路径会更短，真实所有权更清楚
- 兼容层被压缩后，边界回流更难发生，测试护栏也更有针对性

## 当前验收结论

从当前仓库快照可以得出以下结论：

1. **主架构已经基本稳定。** `app / core / game / infrastructure / presentation` 的职责划分比早期状态清晰得多。
2. **最近一轮边界收口已经切断关键对象级泄漏。** 这让代码库从"纠正分层方向错误"进入了"清理迁移残留"的阶段。
3. **当前最值得继续做的，不是再搬目录，而是清兼容层。** 特别是：
   - pure forwarder 壳
   - runtime_state legacy seed
   - 宿主全局别名使用面
   - `turn_engine` 这类冻结历史目录
4. **兼容/转发/legacy 现在已经是有序债务，而不是失控债务。** 这意味着它们适合被阶段性删除，而不是继续被动保留。

换句话说，当前代码库已经从"架构重组期"进入了"技术债精修期"。下一阶段的高价值工作，是把兼容桥从"还在现场"逐步变成"被正式退休"。
