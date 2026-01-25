# Eggy 适配层渲染玩家位置（Unit.set_position）

本 ExecPlan 是一个活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，在 Eggy 运行环境中，玩家棋子会实时移动到棋盘格子的 3D 位置。验证方式是启动 Eggy 运行时，等待入口脚本里的自动移动（`move.start_to_finish(1, 35, 2)`）触发，观察玩家单位沿棋盘移动，并且多人同格时能正确错位显示。

## Progress

- [ ] (2026-01-25 00:00Z) 读取 Eggy 适配层与最新入口脚本的场景单位命名约定，确认棋盘单位与玩家单位来源。
- [ ] (2026-01-25 00:00Z) 在 Eggy 适配层实现棋盘索引 -> 世界坐标映射与玩家单位缓存。
- [ ] (2026-01-25 00:00Z) 在刷新流程中调用 Unit.set_position，完成玩家位置渲染。
- [ ] (2026-01-25 00:00Z) 进行 Lua 自测与 Eggy 手动验证，记录结果。

## Surprises & Discoveries

暂无。

## Decision Log

- Decision: 优先复用入口脚本生成的 `G.tiles` 作为棋盘格子锚点；若不存在则回退到 `LuaAPI.query_units` 查询 `t1..tN`。
  Rationale: 最新 `LuaSource_大富翁/init.lua` 已建立 `G.tiles = LuaAPI.query_units(tile_names)`，复用可减少重复查询并符合“优先复用代码”的规范。
  Date/Author: 2026-01-25 / Codex
- Decision: 玩家单位优先使用 `Role.get_ctrl_unit()` 获取并移动。
  Rationale: Eggy 平台已有角色控制单位，避免额外创建棋子单位与额外资源依赖。
  Date/Author: 2026-01-25 / Codex

## Outcomes & Retrospective

未开始。

## Context and Orientation

当前 Eggy 适配层主要逻辑位于 `src/adapters/eggy/eggy_layer.lua`，刷新面板和棋盘文本，但没有渲染玩家位置。界面与状态由 `src/adapters/core/presenter.lua` 生成，`view.state.players[i].position` 表示玩家棋盘索引。  
Eggy 平台的单位移动 API 在 `docs/eggy/movement_api.md` 与 `docs/eggy/api/07_unit_entities.md` 中给出，`Unit.set_position(pos)` 可直接设置单位坐标。  
最新入口脚本 `LuaSource_大富翁/init.lua` 在启动时创建全局 `G` 并填充 `G.tiles` 与 `G.buildings`，其中 `G.tiles[i]` 就是场景中名为 `t1..t45` 的棋盘格子单位；它们的 `get_position()` 可作为棋盘锚点。入口脚本还在 2 秒后执行 `move.start_to_finish(1, 35, 2)`，可以用作移动渲染的验证触发。  
注意：按项目约定，不直接读取 `docs/eggy/EggyAPI.lua`；如需接口确认，使用 `docs/eggy/api/` 下拆分文档。

## Plan of Work

在 `src/adapters/eggy/eggy_layer.lua` 中扩展刷新逻辑，增加“棋盘锚点缓存”和“玩家单位缓存”，并在每次刷新视图时按玩家当前棋盘索引更新单位位置。  
具体做法是：  
1) 读取棋盘锚点。优先使用全局 `G.tiles`（若存在且长度足够），否则使用 `LuaAPI.query_units` 按 `t1..tN` 查询棋盘单位并读取位置，建立 `index -> Vector3` 的缓存表，只在首次或缓存缺失时重建。  
2) 通过 `GameAPI.get_all_valid_roles()` 获取角色列表，结合 `Role.get_name()` 与 `view.state.players[i].name` 进行匹配，得到 `player_id -> Unit` 映射；若匹配失败则回退到顺序匹配并写日志。  
3) 在 `refresh_board(view)` 或 `refresh_view()` 中，根据 `view.state.players` 构建格子占用列表，计算同格偏移，并对每个玩家单位调用 `unit.set_position(pos)`。偏移建议从棋盘相邻格子间距推导，避免硬编码世界单位。  
4) 对缺失单位或缺失格子坐标进行安全跳过，并记录一次性日志，避免刷屏。  
5) 若玩家已淘汰，可选择不更新位置或将其移至棋盘外位置；此决定需在实现时明确并记录在 Decision Log。

## Concrete Steps

在仓库根目录 `C:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly` 执行以下步骤：

1) 定位棋盘单位命名与现有 Eggy 刷新逻辑：
   - 打开 `LuaSource_大富翁/init.lua`，确认 `G.tiles` 的初始化来源与 `t1..tN` 的单位命名。
   - 打开 `src/adapters/eggy/eggy_layer.lua`，定位 `refresh_board(view)` 与 `refresh_view()`。

2) 在 `src/adapters/eggy/eggy_layer.lua` 内添加本地函数与缓存字段：
   - 本地函数：构建棋盘单位列表（优先 `G.tiles`）、构建玩家单位映射、构建格子占用与偏移。
   - 在 `EggyLayer.new()` 初始化缓存表，例如 `self.tile_units`、`self.tile_positions`、`self.player_units`。

3) 在 `refresh_board(view)` 末尾加入位置渲染调用，流程如下：
   - 若 `self.tile_positions` 不足，调用棋盘单位构建函数。
   - 若 `self.player_units` 缺失，调用玩家单位构建函数。
   - 遍历 `view.state.players`，按 `player.position` 计算目标坐标与错位偏移后调用 `unit.set_position(pos)`。

4) 记录一次性日志（使用 `src.util.logger`）输出映射结果与缺失情况，便于 Eggy 运行时确认。

示例（缩进展示，真实实现需保持现有代码风格）：

    [EggyAdapter] tile anchors ready: 45
    [EggyAdapter] player->unit mapped: 4 (missing: 0)

## Validation and Acceptance

基础脚本自测（无 Eggy 环境依赖）：
- 运行 `lua tests/deps_check.lua`，期望无报错。
- 运行 `lua tests/regression.lua`，期望全部通过。

Eggy 环境验证：
1) 在 Eggy 编辑器/运行器中启动该地图与脚本。
2) 进入游戏后等待 2 秒，入口脚本应触发 `move.start_to_finish(1, 35, 2)`，观察玩家单位沿棋盘移动。
3) 当多个玩家落在同一格时，玩家单位应在格子附近错位排列而非完全重叠。
4) 观察日志中是否出现“缺失 tile unit / 缺失 player unit”的提示，若有则按日志修复映射。

验收标准：
- 每次玩家 `position` 变化后，其对应单位在 3D 场景中移动到正确格子位置。
- 未出现 Lua 报错或持续刷屏日志。

## Idempotence and Recovery

本改动只读取场景单位并移动玩家单位，不更改配置或生成文件，可重复执行。若出现异常，只需恢复 `src/adapters/eggy/eggy_layer.lua` 的改动即可回到当前行为。

## Artifacts and Notes

- 关键锚点来源：`LuaSource_大富翁/init.lua` 中 `G.tiles = LuaAPI.query_units({"t1"...})`
- 关键接口说明：`docs/eggy/movement_api.md` 的 `Unit.set_position(pos)`；`docs/eggy/api/06_lua_api.md` 的 `LuaAPI.query_units`；`docs/eggy/api/05_game_api.md` 的 `GameAPI.get_all_valid_roles`

## Interfaces and Dependencies

必须存在并使用的接口与字段：
- `Unit.set_position(pos)`：用于设置玩家单位位置。
- `Unit.get_position()`：用于读取格子锚点单位的坐标。
- `LuaAPI.query_units(name_list)`：批量获取单位实例（当 `G.tiles` 不可用时）。
- `GameAPI.get_all_valid_roles()`、`Role.get_name()`、`Role.get_ctrl_unit()`：用于定位玩家单位。
- `view.state.players[i].position`：玩家棋盘索引（1-based）。

建议新增的局部函数（放在 `src/adapters/eggy/eggy_layer.lua` 内部，避免新增文件）：
- `build_tile_positions(view)`：返回 `index -> Vector3`。
- `resolve_player_units(view)`：返回 `player_id -> Unit`。
- `build_occupants(players)`：返回 `tile_index -> {player_id,...}`。
- `offset_for_slot(count, slot, step)`：返回 `Vector3` 偏移量。

变更说明：本次更新补充了 `LuaSource_大富翁/init.lua` 中 `G.tiles` 与 `move.start_to_finish` 的最新信息，并将锚点来源改为优先复用 `G.tiles`，以减少重复查询与符合 CodingDiscipline。
