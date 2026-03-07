# 清理兼容层与遗留债务

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件遵循仓库规范 `.agents/harness/PLANS.md` 维护。

## 目的 / 全局视角

当前代码库的主架构已经稳定，Clean Architecture 的核心约束已基本落实。上一轮边界收口已切断关键的对象级泄漏（`state → systems` 和 `systems → game.gameplay_loop_ports`）。现在的问题是**兼容层、转发壳和 legacy 债务仍然偏多**，导致代码所有权不够直接，新人难以判断"哪里是正式 API，哪里只是兼容桥"。

本计划的目标是：
1. 删除只剩名义价值的兼容壳，减少代码树噪音
2. 完成 UI runtime state 迁移，收掉 root-state seed
3. 收缩宿主全局别名使用面
4. 对 façade 层做明确取舍（正式承认或删除）
5. 同步更新架构文档

完成后，读者应能看到以下可见结果：
- 代码库中不再存在纯测试用兼容壳与导入别名壳
- `runtime_state.ensure_ui_runtime()` 不再从旧根级字段 seed 新结构
- 宿主全局别名被限制在 bootstrap 外壳内部
- 架构文档与实现保持一致

## 进度

- [x] (2026-03-07) 研究阶段：确认需要清理的兼容壳和遗留债务清单
- [x] 里程碑 1：删除"只剩名义价值"的兼容壳
  - [x] 删除 `src/game/flow/output_adapters/legacy_output_mirror.lua`
  - [x] 删除 `src/game/systems/market/service/paid_purchase_gateway.lua`
  - [x] 确认并删除 `game.gameplay_loop_ports` 写入（生产代码无读取）
- [x] 里程碑 2：完成 UI runtime state 迁移
  - [x] 清点仍读取 root 字段的模块与测试
  - [x] 迁移 `state.ui_dirty` 读路径到 `ui_runtime`
  - [x] 迁移 `state.ui_model` 读路径到 `ui_runtime`
  - [x] 迁移 `state.pending_choice*` 读路径到 `ui_runtime`
  - [x] 迁移 `state.ui_modal_*` 读路径到 `ui_runtime`
  - [x] 删除 `runtime_state.ensure_ui_runtime()` 中的 `_legacy_choice_seeded` 分支和 root-state seed 行为
- [x] 里程碑 3：收缩宿主全局别名使用面
  - [x] 审查 `app/` 与 `presentation/` 中直接读取 `SetTimeOut` / `RegisterCustomEvent` / `TriggerCustomEvent` 的模块
  - [x] 审查 `all_roles` / `ALLROLES` 全局的使用
  - [x] 将能走显式接口（`runtime_ports`、`host_runtime_port`、`runtime_context`）的调用改走显式接口
  - [x] 给 `tests/internal/dep_rules.lua` 增加增长预算，防止使用面再次扩散
- [x] 里程碑 4：对 façade 做明确取舍
  - [x] 决策：路线 B（统一改 import 到 `src/infrastructure/runtime/*` 后删除 pure façade）
  - [x] 统一改 import 到真实实现并删除 façade
- [x] 里程碑 5：同步架构文档
  - [x] 更新 `docs/architecture/boundaries.md` 增加 `bankruptcy_feedback_port` 说明
  - [x] 更新 `docs/architecture/layer-model.md` 增加 `core/player ↛ systems` 和 `systems ↛ game.gameplay_loop_ports` 规则
  - [x] 更新文档说明 `legacy_output_mirror` / `turn_engine` 的退休方向

## 意外与发现

- `src/presentation` 与 `tests/` 中已有较多用例假设 root UI 字段仍可作为真源；删除 seed 后，需要同步把测试夹具改成显式构造 `ui_runtime`。
- `game_startup_event_bridge` 改为走 `runtime_context.current().env.LuaAPI.global_register_custom_event` 后，测试环境的 runtime context 也要同步刷新 LuaAPI mock，不能只 patch 全局 `RegisterCustomEvent`。
- `src/app/init.lua` 仍保留对 `SetTimeOut` 的直接读取，作为 bootstrap 外壳中的最后兼容调度点；已通过 dep_rules 增长预算冻结，不再允许向 `presentation/` 扩散。

## 决策日志

- (2026-03-07) 选择路线 B：统一改 import 到 `src/infrastructure/runtime/*` 真实实现，并删除 `src/core/runtime_facade/*` / `src/core/runtime_ports/default_ports.lua` 纯转发壳。原因是这些壳已经不再承载独立语义，只会制造双重所有权错觉。
- (2026-03-07) UI runtime 状态以 `state.ui_runtime` 为唯一真源；root UI 字段只允许存在于测试兼容夹具里，生产代码不再读取它们。
- (2026-03-07) `legacy_output_mirror.lua` 与 `paid_purchase_gateway.lua` 已确认为无生产价值壳，直接删除，并由 dep_rules 把文件路径列为 forbidden files 防回流。

## 结果与复盘

- 已删除两个纯兼容壳文件，并清掉 `game.gameplay_loop_ports` 的历史写入点。
- `runtime_state.ensure_ui_runtime()` 已去除 root-state seed 与 `_legacy_choice_seeded` 分支；相关 presentation 写路径改为统一通过 `runtime_state` / `ui_runtime`。
- `game_startup_event_bridge`、`host_runtime_port`、`ui_bootstrap`、`runtime_port_defaults` 已收敛到显式 runtime 接口，宿主全局别名使用面缩到 bootstrap 外壳。
- `tests/internal/dep_rules.lua` 已新增 forbidden files 与 app/presentation 宿主全局增长预算；`lua tests/regression.lua` 全量通过。

## 背景与导读

### 关键兼容壳与遗留债务

| 路径 | 当前形态 | 问题 |
|------|----------|------|
| `src/game/flow/output_adapters/legacy_output_mirror.lua` | 已删除 | 纯测试兼容壳已退休 |
| `src/game/systems/market/service/paid_purchase_gateway.lua` | 已删除 | 纯导入别名已退休 |
| `game.gameplay_loop_ports` 字段 | 写入已删除 | 历史兼容残留已移除；当前真正活跃的是 `state.gameplay_loop_ports` |
| `src/core/runtime_facade/runtime_state.lua` | 已移除 root-state seed | UI runtime 迁移完成，`ui_runtime` 成为唯一真源 |
| `src/core/runtime_facade/runtime_context.lua` | 已删除 | 调用方统一直接引用 `src/infrastructure/runtime/runtime_context.lua` |
| `src/core/runtime_facade/runtime_event_bridge.lua` | 已删除 | 调用方统一直接引用 `src/infrastructure/runtime/runtime_event_bridge.lua` |
| `src/core/runtime_ports/default_ports.lua` | 已删除 | 调用方统一直接引用 `src/infrastructure/runtime/default_ports.lua` |
| `src/game/turn_engine/` | deprecated/frozen，仍被装配引用 | 保持冻结，仅做替换式退休，不再扩展职责 |

### 关键文件位置

- `src/core/runtime_facade/runtime_state.lua` - UI runtime state 唯一真源
- `src/game/flow/turn/gameplay_loop.lua` - 已删除 `game.gameplay_loop_ports` 写入
- `src/app/bootstrap/game_startup_event_bridge.lua` - 改走 `runtime_context` 注册事件
- `src/presentation/adapter/host_runtime_port.lua` - 改走 `runtime_context` 注册宿主事件
- `src/app/bootstrap/ui_bootstrap.lua` - 改走 `runtime_ports.schedule`
- `tests/internal/dep_rules.lua` - 增加 forbidden files 与宿主全局增长预算

### 术语说明

- **兼容壳**：为了保持向后兼容而存在的包装层，通常只转发调用
- **转发壳**：单行 `return require(...)` 的模块，仅提供稳定 import 路径
- **legacy seed**：在状态迁移期间，从旧结构向新结构复制数据的兼容逻辑
- **宿主全局别名**：把 Eggy 宿主 API 映射到全局变量（如 `SetTimeOut`、`RegisterCustomEvent`）
