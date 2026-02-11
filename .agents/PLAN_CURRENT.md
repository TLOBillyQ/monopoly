# 接入状态3DUI与玩家状态显隐同步

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本计划遵循 `.agents/PLANS.md`，实施过程中需要保持本文件自洽且完整。

## 目的 / 全局视角

在现有回合循环中新增“状态3DUI同步链路”，把玩家状态（医院/深山/路障当回合/财神/穷神/天使）映射到玩家头顶3DUI，并对所有玩家客户端统一显隐。完成后可观察到状态变化时头顶标识即时切换，无状态时隐藏。

## 进度

- [x] (2026-02-11 00:00Z) 清空并重写 `.agents/PLAN_CURRENT.md`
- [x] (2026-02-11 00:10Z) 新增 `src/ui/UIStatus3DLayer.lua` 并完成状态判定与显隐同步
- [x] (2026-02-11 00:12Z) 接入 `TickUISync` / `GameplayLoopPorts` / `GameplayLoop`
- [x] (2026-02-11 00:18Z) 补充 `.agents/tests/suites/ui.lua` 的4个状态3D用例
- [x] (2026-02-11 00:20Z) 运行 `lua .agents/tests/regression.lua` 并记录结果

## 意外与发现

- 观察：状态3D层节点ID可直接从 `Data/UIManagerNodes.lua` 的 `prefix|node` 解析，`prefix` 可作为 layer key，`node` 可用于 `get_eui_node_at_scene_ui`。
  证据：新增模块 `src/ui/UIStatus3DLayer.lua` 中 `_split_export_node_id` 与 `_build_meta` 已完成解析并通过回归。
- 观察：路障“仅当回合显示”可稳定通过 `game.last_turn.player_id + move_result.stopped_on_roadblock` 判定，不需要新增状态字段。
  证据：`_test_status3d_roadblock_only_current_turn` 回归用例通过。

## 决策日志

- 决策：单状态优先级显示，优先级为医院>深山>路障当回合>穷神>财神>天使。
  理由：避免同屏重叠，且优先展示扣留类状态。
  日期/作者：2026-02-11 / Codex

- 决策：路障状态仅在触发当回合显示，不跟随 `stay_turns` 持续显示。
  理由：按需求锁定规则，避免与医院/深山冲突。
  日期/作者：2026-02-11 / Codex

- 决策：状态3D层 key 从 `Data/UIManagerNodes.lua` 的状态节点导出ID前缀自动推导。
  理由：仓库当前无独立 layout 导出文件，且该方式可直接复用现有导出数据。
  日期/作者：2026-02-11 / Codex

## 结果与复盘

已完成状态3DUI全链路接入：创建、缓存、判定、显隐、重置销毁、回归测试。  
本次改动覆盖了你锁定的三个规则（单状态优先级、全玩家可见、路障仅当回合）。  
全量回归通过：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (104)`。

## 背景与导读

当前项目已有2D UI 管线（`UIView`、`TickUISync`、`GameplayLoopPorts`、`GameplayLoop`）和玩家状态源（`player.status.stay_turns`、`player.status.deity`、`game.last_turn.move_result`），但尚未有任何 `SceneUI` 的3D状态层创建和显隐逻辑。`Data/UIManagerNodes.lua` 已新增“医院/深山/路障/财神/穷神/天使”状态节点，可用于3D状态层节点定位。

## 工作计划

先实现独立模块 `UIStatus3DLayer`，负责：解析状态节点与layer key、按玩家创建3D层、计算当前状态、按状态切换节点显隐并控制整层可见。然后通过 `TickUISync` 暴露桥接函数，在 `GameplayLoopPorts` 注册默认端口，并在 `GameplayLoop.set_game/tick` 中接入 reset+sync 调用。最后补充UI回归测试并跑全量回归。

## 具体步骤

1. 新增 `src/ui/UIStatus3DLayer.lua`：
   - 解析 `Data/UIManagerNodes.lua` 中6类状态节点。
   - 每玩家创建 `create_scene_ui_bind_unit(layer_key, Enums.ModelSocket.socket_head, math.Vector3(0, 3, 0), -1.0, true, true)`。
   - 按优先级判定状态并同步显隐。
   - 缺失API或节点时 warn once 并降级禁用。
2. 修改 `src/game/turn/TickUISync.lua`，新增 `reset_status_3d` 与 `sync_status_3d` 转调。
3. 修改 `src/game/turn/GameplayLoopPorts.lua`，新增默认端口并导出。
4. 修改 `src/game/turn/GameplayLoop.lua`：
   - `set_game` 调用 `ports.reset_status_3d(state)`。
   - `tick` 在 `refresh_from_dirty` 后调用 `ports.sync_status_3d(game, state, dirty)`。
5. 修改 `.agents/tests/suites/ui.lua`，新增4个状态3D用例并加入 suite 返回列表。

## 验证与验收

在仓库根目录运行：

    lua .agents/tests/regression.lua

预期：全部测试通过，无新增失败；并可在编辑器中观察状态3DUI随玩家状态切换。

## 可重复性与恢复

该变更为纯代码增量。若需回滚，删除 `UIStatus3DLayer` 接入点与新增测试即可，不涉及存档或迁移。

## 产物与备注

核心产物：
- `src/ui/UIStatus3DLayer.lua`
- `src/game/turn/TickUISync.lua`
- `src/game/turn/GameplayLoopPorts.lua`
- `src/game/turn/GameplayLoop.lua`
- `.agents/tests/suites/ui.lua`

## 接口与依赖

- 新增接口：
  - `tick_ui_sync.reset_status_3d(state)`
  - `tick_ui_sync.sync_status_3d(game, state, dirty)`
- 新增端口：
  - `gameplay_loop_ports.resolve(...).reset_status_3d(state)`
  - `gameplay_loop_ports.resolve(...).sync_status_3d(game, state, dirty)`
- 依赖API：
  - `Unit.create_scene_ui_bind_unit`
  - `GameAPI.get_eui_node_at_scene_ui`
  - `GameAPI.set_scene_ui_visible`
  - `GameAPI.destroy_scene_ui`

(2026-02-11) 更新说明：完成实现与测试，回填进度、发现与结果，保证计划文档可复盘与可接续。
