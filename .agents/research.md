# Monopoly 代码清理调研（兼容层/遗留/转发）

本文件是调研备忘，不是可执行计划。P1 的可执行细节见 `.agents/plan.md`。

更新时间：2026-03-02

## 本轮已完成的实际清理

1. 删除协程引擎中的冗余 mode 兼容字段
- `src/game/runtime/TurnEngine.lua`
- 删除 `self.mode = "coroutine"`
- 删除传入 `session_factory.new` 的 `mode = "coroutine"`

2. 删除协程 session 中已无行为价值的 legacy mode 字段
- `src/game/runtime_coroutine/Session.lua`
- 删除 `mode = opts.mode or "legacy"`
- 删除 `snapshot()` 的 `mode` 输出

3. 清理历史文案噪音
- `tests/suites/gameplay_coroutine.lua`
- 注释 `legacy mode default` -> `coroutine mode default`

结论：这部分属于“兼容遗留字段清理”，不影响运行时语义，减少了无效状态面与误导性术语。

## 回归验证

已执行：
- `lua tests/regression.lua`

结果：
- `All regression checks passed (209)`
- `dep_rules ok`
- `tick ok`
- `forbidden_globals ok`

说明：单文件 suite 直接执行会因 Lua 路径未注入 `tests/` 出现 `require("TestSupport")` 失败；全量回归通过，覆盖了对应模块行为。

## 深度盘点：当前仍存在的兼容/转发层

### A. 运行时 legacy 兜底（可控但仍在）

核心位置：
- `src/core/RuntimePorts.lua`
- `src/app/bootstrap/RuntimeInstall.lua`
- `tests/TestSupport.lua`
- `tests/suites/runtime_ports_contract.lua`

现状：
- `RuntimeInstall.lua:9-12` 接收 `context_policy` 参数（默认 `"strict"`，可选 `"legacy"`），据此调用 `RuntimePorts.set_legacy_global_fallback_enabled`。
- `RuntimePorts.lua` 在 legacy 模式下回退读取全局 `all_roles/ALLROLES`、`vehicle_helper`、`camera_helper` 与 `GameAPI.get_role`（见 `_resolve_roles_from_legacy_globals` 及 `_default_resolve_role`）。

结论：这是当前最大的“兼容层主体”，不是死代码，测试也在显式覆盖，不能一次性删除。

### B. 载具事件 forward_* 转发层（命名与职责有历史包袱）

核心位置：
- `src/core/RuntimeContext.lua`（`forward_eca_event_enter/exit/move/stop/set_position`）
- `src/presentation/render/MoveAnim.lua`
- `src/game/core/runtime/player_state/StatusOps.lua`
- `src/presentation/render/board_runtime/placement.lua`

现状：
- 该层在“逻辑动作 -> ECA 自定义事件”之间承担转发。
- 调用点分布在 runtime/game/presentation，多模块依赖。

代码证据（调用分布）：
- `src/game/core/runtime/player_state/StatusOps.lua:25,28,79`
- `src/presentation/render/MoveAnim.lua:117,122`
- `src/presentation/render/board_runtime/placement.lua:123`

结论：是可重构对象，但不是可直接删对象。应先做接口收敛，再统一改名/替换。

### C. 事件桥接链（必要桥接，但层次偏多）

核心位置：
- `src/core/RuntimeEventBridge.lua`
- `src/core/events/MonopolyEvents.lua`
- `src/app/bootstrap/GameStartupEventBridge.lua`
- `src/presentation/api/HostRuntimePort.lua`

现状：
- `MonopolyEvents` 作为事件名目录 + 发射入口。
- `RuntimeEventBridge` 负责 TriggerCustomEvent 安全预检和熔断。
- 启动和表现层又各自套一层 bridge/port。

结论：有明确价值，但命名“bridge”较多，认知成本高。建议后续做“单一入口 + 薄包装”归并。

### D. 表现层角色解析 fallback（仍有双轨）

核心位置：
- `src/presentation/api/HostRuntimePort.lua`
- `src/presentation/render/status3d_service/scene.lua`
- `src/presentation/render/status3d_service/status.lua`

现状：
- `host_runtime.resolve_role` 已包含 fallback 到 `resolve_game_role`。
- status3d 内部仍手动再 fallback 一次（带方法能力校验）。

代码证据（`scene.lua:8-18`）：

    local function _resolve_role(player_id)
      local role = host_runtime.resolve_role(player_id)
      if role ~= nil and type(role.get_ctrl_unit) == "function" then
        return role
      end
      role = host_runtime.resolve_game_role(player_id)
      if role ~= nil and type(role.get_ctrl_unit) == "function" then
        return role
      end
      return nil
    end

`status.lua:7-17` 结构相同，谓词换为 `role.set_label_text ~= nil`。

结论：可进一步统一为“带谓词的角色解析接口”，减少重复 fallback 逻辑。

### E. UI 节点别名层（UIAliases）

核心位置：
- `src/presentation/shared/UIAliases.lua`
- `src/presentation/api/UIRuntimePort.lua`

现状：
- 别名映射仍被 `query_nodes` 使用，服务于 Canvas 节点中文名与代码键名对齐。

结论：当前是“在役适配层”，应保留；未来仅在全量节点规范完成后考虑下线。

## 不建议现在直接删除的项

1. `RuntimePorts` legacy fallback 开关与路径
- 原因：有契约测试覆盖，且测试/降级路径仍依赖。

2. `RuntimeEventBridge`
- 原因：承担 TriggerCustomEvent 的安全预检与熔断，直接删除会丢失安全行为。

3. `MonopolyEvents`
- 原因：业务事件名集中定义被广泛引用，删掉会导致全局散乱字符串。

4. `UIAliases`
- 原因：UI 查询链条仍显式依赖，尚未完成节点命名一体化。

## 下一阶段清理路线（建议）

### P1（低风险，建议先做）

P1 可执行计划已交付至 `.agents/plan.md`，范围包含：
1. 在 `HostRuntimePort` 引入带谓词能力校验的统一角色解析接口，并收敛 `status3d_service/*` 的重复 fallback。
2. 对 `forward_eca_event_*` 做语义化命名迁移（先别名兼容，后逐步替换调用点）。
3. 清理 tests/docs 中仅注释层遗留词（如 `legacy mode`、`compatibility wrappers`）。

#### P1 执行回填（2026-03-02）

已完成：
1. 统一角色解析入口
- `src/presentation/api/HostRuntimePort.lua` 新增 `resolve_role_with(player_id, predicate)`。
- `src/presentation/render/status3d_service/scene.lua` 与 `status.lua` 改为调用统一入口并以内联谓词做能力校验。

2. 载具事件语义化命名迁移（兼容保留）
- `src/core/RuntimeContext.lua` 新增 `emit_vehicle_enter/exit/move/stop/set_position`。
- 保留 `forward_eca_event_*` 作为别名转调，避免现有调用和测试桩断裂。
- `StatusOps.lua`、`MoveAnim.lua`、`placement.lua` 已迁移为“优先新名，回退旧名”。

3. 注释噪音清理
- `tests/suites/runtime_ports_contract.lua`：`legacy mode` -> `legacy policy`。
- `docs/architecture/presentation_canvas_first.md`：`compatibility wrappers/mapping` -> `temporary wrappers/mapping`。

验证证据：
- `rg "resolve_game_role\\(" src/presentation/render/status3d_service -n` -> No matches found
- `rg "legacy mode|compatibility wrappers|legacy bridge" tests docs -n -i` -> No matches found
- `lua tests/regression.lua` -> All regression checks passed (209), dep_rules ok, tick ok, forbidden_globals ok

### P2（中风险，需要分批）

1. 收缩 `RuntimeInstall` legacy 能力面
- 保留开关，但将 fallback 读取能力限定在最小集合（仅测试/特定入口）。

2. 载具转发层接口收敛
- 先在 `RuntimeContext` 内聚为统一 dispatcher，再替换外层调用。

### P3（高风险，最后做）

1. 逐步移除 runtime legacy 模式
- 前提：所有入口都走 context strict，且 regression + contract 全绿。
- 完成后再删除 `set_legacy_global_fallback_enabled` 及关联测试。

## 风险与边界

1. 当前仓库对“可控降级（legacy）”有明确测试契约，不能在本轮直接硬删。
2. 事件桥与载具 forward 层跨越 app/core/game/presentation，需按调用链分批迁移。
3. 本轮已经完成一组“零行为改动”的实质清理，适合作为后续大项重构的起点。
