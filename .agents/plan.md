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
- 代码库中不再存在纯转发壳模块
- `runtime_state.ensure_ui_runtime()` 不再从旧根级字段 seed 新结构
- 宿主全局别名被限制在最外层 bootstrap 内部
- 架构文档与实现保持一致

## 进度

- [ ] (2026-03-07) 研究阶段：确认需要清理的兼容壳和遗留债务清单
- [ ] 里程碑 1：删除"只剩名义价值"的兼容壳
  - [ ] 删除 `src/game/flow/output_adapters/legacy_output_mirror.lua`
  - [ ] 删除 `src/game/systems/market/service/paid_purchase_gateway.lua`
  - [ ] 确认并删除 `game.gameplay_loop_ports` 写入（若生产无读取）
- [ ] 里程碑 2：完成 UI runtime state 迁移
  - [ ] 清点仍读取 root 字段的模块与测试
  - [ ] 迁移 `state.ui_dirty` 读路径到 `ui_runtime`
  - [ ] 迁移 `state.ui_model` 读路径到 `ui_runtime`
  - [ ] 迁移 `state.pending_choice*` 读路径到 `ui_runtime`
  - [ ] 迁移 `state.ui_modal_*` 读路径到 `ui_runtime`
  - [ ] 删除 `runtime_state.ensure_ui_runtime()` 中的 `_legacy_choice_seeded` 分支和 root-state seed 行为
- [ ] 里程碑 3：收缩宿主全局别名使用面
  - [ ] 审查 `app/` 与 `presentation/` 中直接读取 `SetTimeOut` / `RegisterCustomEvent` / `TriggerCustomEvent` 的模块
  - [ ] 审查 `all_roles` / `ALLROLES` 全局的使用
  - [ ] 将能走显式接口（`runtime_ports`、`host_runtime_port`、`runtime_context`）的调用改走显式接口
  - [ ] 给 `tests/internal/dep_rules.lua` 增加白名单，防止使用面再次扩散
- [ ] 里程碑 4：对 façade 做明确取舍
  - [ ] 决策：路线 A（正式承认 façade 为稳定 import 面）或 路线 B（统一改 import 后删除）
  - [ ] 若路线 A：更新文档明确 façade 是正式边界
  - [ ] 若路线 B：统一改 import 到 `src/infrastructure/runtime/*` 后删除纯转发壳
- [ ] 里程碑 5：同步架构文档
  - [ ] 更新 `docs/architecture/boundaries.md` 增加 `bankruptcy_feedback_port` 说明
  - [ ] 更新 `docs/architecture/layer-model.md` 增加 `core/player ↛ systems` 和 `systems ↛ game.gameplay_loop_ports` 规则
  - [ ] 更新文档说明 `legacy_output_mirror` / `turn_engine` 的退休方向

## 意外与发现

（实施过程中记录）

## 决策日志

（实施过程中记录）

## 结果与复盘

（里程碑完成或整体完成时总结）

## 背景与导读

### 关键兼容壳与遗留债务

| 路径 | 当前形态 | 问题 |
|------|----------|------|
| `src/game/flow/output_adapters/legacy_output_mirror.lua` | 仅做 output_ports 的薄包装；全仓生产代码没有引用 | 只剩测试使用，是"已经失去生产价值的兼容壳" |
| `src/game/systems/market/service/paid_purchase_gateway.lua` | 单行 `return require(...)` | 生产代码已直接依赖 `paid_purchase_port`，该壳只剩名义出口价值 |
| `game.gameplay_loop_ports` 字段 | 在 `gameplay_loop.lua` 中写入，但 `src/` 生产代码已无读取 | 历史兼容残留；当前真正活跃的是 `state.gameplay_loop_ports` |
| `src/core/runtime_facade/runtime_state.lua` | `ensure_ui_runtime()` 仍从旧根级字段 seed 新结构 | UI runtime 迁移尚未完全结束；新旧状态共存 |
| `src/core/runtime_facade/runtime_context.lua` | 单行 `return require(...)` | 纯转发壳；制造"双重所有权错觉" |
| `src/core/runtime_facade/runtime_event_bridge.lua` | 单行 `return require(...)` | 纯转发壳；制造"双重所有权错觉" |
| `src/core/runtime_ports/default_ports.lua` | 单行 `return require(...)` | 纯转发壳；制造"双重所有权错觉" |
| `src/game/turn_engine/` | 文档标记 deprecated/frozen，但仍在 `composition_root.lua` 中被使用 | 历史执行器容器，状态不明确 |

### 关键文件位置

- `src/core/runtime_facade/runtime_state.lua` - UI runtime state 迁移核心文件
- `src/core/runtime_facade/runtime_context.lua` - 纯转发壳候选
- `src/core/runtime_facade/runtime_event_bridge.lua` - 纯转发壳候选
- `src/core/runtime_ports/default_ports.lua` - 纯转发壳候选
- `src/game/flow/output_adapters/legacy_output_mirror.lua` - 待删除兼容壳
- `src/game/systems/market/service/paid_purchase_gateway.lua` - 待删除兼容壳
- `src/game/flow/turn/gameplay_loop.lua` - `game.gameplay_loop_ports` 写入点
- `src/app/bootstrap/runtime_install/runtime_global_aliases.lua` - 宿主全局别名安装
- `src/core/runtime_facade/ui_role_globals.lua` - 角色全局安装

### 术语说明

- **兼容壳**：为了保持向后兼容而存在的包装层，通常只转发调用
- **转发壳**：单行 `return require(...)` 的模块，仅提供稳定 import 路径
- **legacy seed**：在状态迁移期间，从旧结构向新结构复制数据的兼容逻辑
- **宿主全局别名**：把 Eggy 宿主 API 映射到全局变量（如 `SetTimeOut`、`RegisterCustomEvent`）
- **façade**：门面模式，此处指 `runtime_facade` 和 `runtime_ports` 目录下的模块

## 里程碑

### 里程碑 1：删除"只剩名义价值"的兼容壳

范围是删除三个已确认无生产价值的兼容壳：`legacy_output_mirror.lua`、`paid_purchase_gateway.lua`、以及 `game.gameplay_loop_ports` 写入（若确认生产无读取）。完成后，代码树中不再存在"仅为测试存在"或"仅为导入别名存在"的模块。实施时应先把相关测试改成直接验证正式接口，再删除壳模块。验收信号是：`src/` 中不再出现这三个兼容壳的引用，且所有测试仍然通过。

### 里程碑 2：完成 UI runtime state 迁移

范围是让 `runtime_state.ensure_ui_runtime()` 不再从旧根级字段 seed 新结构。完成后，state 形状的标准将变得单一，不再有"新旧状态共存"的隐性复杂度。实施时应先清点仍读取 root 字段的模块与测试，逐一切换到 `ui_runtime` / `runtime_state.*`，最后删除 `_legacy_choice_seeded` 分支和 root-state seed 行为。验收信号是：`runtime_state.lua` 中不再出现 `state.ui_dirty`、`state.ui_model`、`state.pending_choice*`、`state.ui_modal_*` 的读取，且 UI 选择态、modal timer、pending choice 相关测试仍然通过。

### 里程碑 3：收缩宿主全局别名使用面

范围是把 `SetTimeOut`、`RegisterCustomEvent`、`TriggerCustomEvent`、`all_roles` 等宿主全局的使用范围压缩到最外层。完成后，"宿主全局名"将从显式 API 退化成真正的内部兼容细节。实施时应审查 `app/` 与 `presentation/` 中的直接读取，优先改走显式接口，并给 `dep_rules` 增加白名单。验收信号是：`grep -r "SetTimeOut\|RegisterCustomEvent\|TriggerCustomEvent\|all_roles\|ALLROLES" src/` 的命中数显著下降，且功能测试仍然通过。

### 里程碑 4：对 façade 做明确取舍

范围是解决 `src/core/runtime_facade/*` / `src/core/runtime_ports/*` 到底是长期公开 API 还是过渡壳的问题。有两种可选路线：

- **路线 A**：正式承认 façade 为稳定 import 面，保留现有转发壳，并在文档中明确它们是唯一推荐入口。
- **路线 B**：统一改 import 到真实实现后删除 façade，把调用方直接切到 `src/infrastructure/runtime/*`。

决策应考虑"是否仍希望保持内层不 import infrastructure"。验收信号是：文档明确说明路线选择，代码与文档一致。

### 里程碑 5：同步架构文档

范围是更新 `docs/architecture/boundaries.md` 和 `docs/architecture/layer-model.md`，使其反映最新的边界约定。完成后，下一位开发者不需要只靠 grep 推断当前边界。验收信号是：文档中包含 `bankruptcy_feedback_port` 说明、`core/player ↛ systems` 和 `systems ↛ game.gameplay_loop_ports` 规则、以及 `legacy_output_mirror` / `turn_engine` 的退休方向。

## 工作计划

从风险最低、收益最直接的步骤开始：先删死壳，再收紧活桥，最后决定 façade 的取舍。

第一步，删除 `legacy_output_mirror.lua` 和 `paid_purchase_gateway.lua`。先把相关测试改成直接验证正式接口，而不是验证 legacy 包装壳。然后直接删除这两个文件。

第二步，处理 `game.gameplay_loop_ports`。先在全仓 grep 确认生产代码无读取，然后删除 `gameplay_loop.lua` 中的写入语句。

第三步，完成 UI runtime state 迁移。清点仍读取 root 字段的模块与测试，逐一切换到 `ui_runtime`。这是一个渐进过程，需要保证每一步测试都通过。最后删除 `_legacy_choice_seeded` 分支。

第四步，收缩宿主全局别名使用面。审查 `app/` 和 `presentation/` 中的直接全局读取，改为显式接口调用。给 `dep_rules` 增加白名单防止扩散。

第五步，对 façade 做取舍。根据"是否希望内层不 import infrastructure"决定路线 A 或 B，然后执行。

第六步，同步更新架构文档。

## 具体步骤

以下命令默认在仓库根目录 `/Users/gangan/Dev/repo/monopoly` 执行。

1. 验证兼容壳的生产引用状态。

       rg -l "legacy_output_mirror" src/
       rg -l "paid_purchase_gateway" src/
       rg -l "game\.gameplay_loop_ports" src/

   预期：前两条命令无输出；第三条命令应只命中写入点（`gameplay_loop.lua`），无读取点。

2. 删除兼容壳并更新相关测试。

       rm src/game/flow/output_adapters/legacy_output_mirror.lua
       rm src/game/systems/market/service/paid_purchase_gateway.lua
       # 编辑相关测试文件，移除对这两个模块的引用

3. 清点 UI runtime 旧字段读取。

       rg -n "state\.ui_dirty|state\.ui_model|state\.pending_choice|state\.ui_modal" src/ tests/

   预期：能看到仍读取 root 字段的模块清单。

4. 逐一切换读路径到 `ui_runtime`。

       # 编辑相关文件，把 state.xxx 改为 runtime_state.get_xxx(state)

5. 删除 `_legacy_choice_seeded` 分支和 root-state seed 行为。

       # 编辑 src/core/runtime_facade/runtime_state.lua
       # 移除 _legacy_choice_seeded 相关逻辑
       # 移除从 state.xxx 到 ui_runtime 的 seed 行为

6. 清点宿主全局别名使用面。

       rg -n "SetTimeOut|RegisterCustomEvent|TriggerCustomEvent|all_roles|ALLROLES" src/ --type lua

   预期：命中数集中在 `app/bootstrap/` 和少量 `presentation/adapter/` 文件。

7. 审查并收缩宿主全局使用。

       # 编辑相关文件，优先改走 runtime_ports / host_runtime_port / runtime_context

8. 给 dep_rules 增加白名单。

       # 编辑 tests/internal/dep_rules.lua
       # 增加宿主全局别名使用面的白名单或增长预算

9. 决策并执行 façade 取舍。

       # 若路线 B：统一改 import 后删除转发壳
       # rm src/core/runtime_facade/runtime_context.lua
       # rm src/core/runtime_facade/runtime_event_bridge.lua
       # rm src/core/runtime_ports/default_ports.lua

10. 同步更新架构文档。

        # 编辑 docs/architecture/boundaries.md
        # 编辑 docs/architecture/layer-model.md

11. 运行全量回归。

        lua tests/regression.lua

    预期：全量回归通过；若出现失败，记录到"意外与发现"。

## 验证与验收

验收必须覆盖以下结果：

1. **兼容壳删除**
   - `src/game/flow/output_adapters/legacy_output_mirror.lua` 不存在
   - `src/game/systems/market/service/paid_purchase_gateway.lua` 不存在
   - `game.gameplay_loop_ports` 写入已删除（若确认生产无读取）

2. **UI runtime 迁移完成**
   - `runtime_state.ensure_ui_runtime()` 不再从旧根级字段 seed
   - 所有读路径已切到 `ui_runtime` / `runtime_state.*`

3. **宿主全局别名收缩**
   - 宿主全局使用面显著压缩
   - `dep_rules` 有白名单防止扩散

4. **façade 取舍明确**
   - 文档明确说明路线选择（A 或 B）
   - 代码与文档一致

5. **架构文档同步**
   - `docs/architecture/boundaries.md` 反映最新边界
   - `docs/architecture/layer-model.md` 反映最新边界

建议采用以下验收表述：

- 运行 `lua tests/regression.lua`，预期全量回归通过。
- 运行 `rg` 命令验证兼容壳已删除、宿主全局使用面已收缩。
- 运行 `rg` 命令验证 `runtime_state.lua` 中无 root-state seed 行为。

## 可重复性与恢复

本计划适合按里程碑重复执行。推荐顺序是"先删死壳，再收紧活桥，最后决定 façade 取舍"。

若某一步失败，按以下原则恢复：

- 兼容壳删除失败：回退删除操作，保留原文件。
- UI runtime 迁移失败：仅回退当前正在迁移的字段，不回退已完成的字段。
- 宿主全局收缩失败：保留已收缩的部分，仅回退当前正在收缩的调用点。
- façade 取舍失败：保留现有转发壳，在决策日志中记录原因。

完成后应保持工作区整洁，避免把分析脚本、统计产物或无关文档混入同一提交。

## 产物与备注

本计划实施完成后，预期最小产物如下：

（待里程碑完成后补充）

## 接口与依赖

### 允许变更

- 删除 `legacy_output_mirror.lua` 和 `paid_purchase_gateway.lua`
- 修改 `runtime_state.lua` 移除 seed 行为
- 修改各模块从 `state.xxx` 改为 `runtime_state.get_xxx(state)`
- 修改各模块从宿主全局改为显式接口
- 更新 `dep_rules.lua` 增加白名单
- 更新架构文档

### 禁止变更

- 不改变任何业务规则的行为
- 不修改 `turn_engine/` 功能（仍在使用）
- 不修改 Port 契约的函数签名（只改内部实现）

---

更新说明：2026-03-07 基于 `.agents/research.md` 重写本计划，废弃旧的边界收口内容。原因是上一轮边界收口已完成，当前代码库已从"架构重组期"进入"技术债精修期"，需要一份围绕清理兼容层、转发壳、legacy 债务的可执行计划。
