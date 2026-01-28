# 棋盘锚点与回合按钮修复计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

仓库中存在 PLANS.md，路径为 `.agent/PLANS.md`，本文件必须遵循其中的所有要求维护。

## 目的 / 全局视角


完成后将同时解决五个问题：
1) 场景棋盘格子上的名称与价格能够正确显示；2) 起点地块对齐到 `t35`（与 `src/config/tiles.lua` 的 id 对应），不再错误落在 `t1`；3) 玩家点击“下一步”能推进回合；4) “下一步”具备防连点；5) 关键流程增加调试 `print` 覆盖，并在 `docs/*.md` 记录位置以便发布前统一删除。用户能通过进入 Eggy 场景、点击按钮、观察格子文本与回合推进来验证生效。

## 进度


- [x] (2026-01-28 17:52) 建立计划初版，完成相关文件定位与问题拆分。
- [ ] (2026-01-28 17:52) 明确棋盘锚点映射与 TileRenderer 的修复方案，补上初次渲染。
- [ ] (2026-01-28 17:52) 修复“下一步”按钮不推进与连点防护，并补齐调试 print。
- [ ] (2026-01-28 17:52) 记录调试 print 位置到 docs，并完成验证与回归检查。

## 意外与发现


当前尚未发现意外行为。若发现棋盘锚点命名与配置不一致、Eggy 场景缺少 `t<ID>`、或 UI 点击事件未注册，将在此记录并给出证据。

## 决策日志


决策：棋盘锚点以 `tiles.lua` 的 tile id 命名（`t<ID>`），并用棋盘路径顺序把 `t<ID>` 映射为“棋盘索引位”。
理由：玩家位置与移动动画使用棋盘索引，路径顺序必须稳定；同时 `t<ID>` 与配置 id 一一对应，符合用户要求且便于排错。
日期/作者：2026-01-28 / Codex。

决策：TileRenderer 继续负责名字/价格渲染，但在棋盘第一次同步时批量初始化一次；owner 变化时继续更新。
理由：当前仅在 owner 变化时调用会导致初始文本为空；初始化渲染可一次性解决显示缺失问题。
日期/作者：2026-01-28 / Codex。

决策：“下一步”防连点采用轻量节流（点击后锁定，直到回合阶段推进或最短时间到达）。
理由：不引入新抽象，避免重复触发回合逻辑，同时不阻塞自动运行。
日期/作者：2026-01-28 / Codex。

## 结果与复盘


尚未实施，完成后补充实际结果、缺口与复盘。

## 背景与导读


棋盘格子单位由 `src/adapters/eggy/eggy_runtime.lua` 初始化（`G.tiles = LuaAPI.query_units(...)`），位置读取在 `src/adapters/eggy/eggy_layer_board.lua`，移动动画在 `src/adapters/eggy/move_anim.lua`。格子文本渲染由 `src/adapters/eggy/tile_renderer.lua` 使用 `src/config/tiles.lua` 的配置（name/price）。棋盘路径由 `src/config/map.lua` 提供（`path` 为 tile id 列表，起点 id=35）。回合推进入口为 `EggyLayer:dispatch_action` -> `EggyLayer:step_turn` -> `Game:advance_turn`。UI 点击注册在 `src/adapters/eggy/eggy_runtime.lua` 的 `register_ui_manager_events`。

## 工作计划


先修正棋盘锚点与 TileRenderer。把棋盘“索引位”与场景锚点 `t<ID>` 做显式映射：基于 `src/config/map.lua` 的 `path`，生成按棋盘索引顺序的 `t<ID>` 列表并查询单位，保证 index=1 对应 `t35`。在 `EggyLayerBoard.refresh_board` 初始化 tile_positions 时，用棋盘索引驱动的位置表，但底层单位来自 `t<ID>`，同时在 tile_units 准备完成后批量调用 `TileRenderer.render_tile`，把 name/price 初始化写入。并将 TileRenderer 内对 tiles 配置的索引方式改为“按 id 查询”，避免 `tiles.lua` 数组导致 name/price 读空。

然后修复“下一步”按钮流程。通过在 `register_ui_manager_events` 与 `EggyLayer:dispatch_action/step_turn` 加 `print` 覆盖，确认点击事件确实触发并推进到 `Game:advance_turn`。若确认触发但回合不前进，继续在 `src/gameplay/turn_manager.lua` 入口加 print 追踪阶段变化。完成后加入防连点逻辑：在 EggyLayer 里维护一次点击锁，只有当锁解除才允许新的 “next”，锁解除的条件使用“回合阶段已变化”或“最短时间间隔已满足”，并确保自动运行不受影响。

最后统一补充调试 print 的位置清单，写入 `docs/debug_prints.md`（或同等命名的 docs 文件），列出文件路径与简短说明，用于后续发布前集中删除。

## 具体步骤


确认锚点、TileRenderer 与按钮入口的现状：

    rg -n "tile_renderer|render_tile|t\\d+|btn_next|dispatch_action" src
    rg -n "path|start_id" src/config/map.lua

修改 `src/adapters/eggy/eggy_runtime.lua`，用 `src/config/map.lua` 的 `path` 生成 `t<ID>` 列表查询单位，保证 `G.tiles[board_index]` 对应 `t<tile_id>`。注意 `board_index=1` 对应 `tile_id=35`。

修改 `src/adapters/eggy/eggy_layer_board.lua`：
- 在 tile_units/positions 初始化完成后，按棋盘索引逐个调用 `TileRenderer.render_tile(unit, tile_id, owner_id)`，补齐 name/price 的初次渲染；owner_id 从 `view.state.board.tiles[tile_id]` 读取。
- 继续保持玩家位置计算使用棋盘索引（避免破坏移动逻辑）。

修改 `src/adapters/eggy/tile_renderer.lua`：预先构建 `id -> cfg` 映射，改用映射查询，避免 `tiles.lua` 数组按下标读取失败。

修复“下一步”与连点：
- 在 `src/adapters/eggy/eggy_runtime.lua` 的 `register_node_click` 里对 `btn_next` 增加 `print`，确认点击事件触发。
- 在 `src/adapters/eggy/eggy_layer.lua` 的 `dispatch_action` 与 `step_turn` 增加 `print`，并加入节流锁逻辑（记录点击时刻与最近回合阶段变化）。
- 在 `src/gameplay/turn_manager.lua` 的 `run_turn` 或 `advance` 入口添加 `print`，用于确认回合推进链路。

新增 `docs/debug_prints.md`，记录上述 print 的位置与用途，明确“发布前删除”的备注。

## 验证与验收


运行回归脚本：

    lua tests/regression.lua

在 Eggy 场景中验证：
1) 起点格子位于 `t35`，玩家初始位置在起点。
2) 任意格子显示 name 与 price 文本（地块类显示价格，非地块可为空）。
3) 点击“下一步”后回合推进，日志/print 显示点击与推进链路；连续快速点击不会多次推进。
4) `docs/debug_prints.md` 中列出的 print 均存在，且易于定位删除。

## 可重复性与恢复


修改集中在 Eggy 适配层与配置读取，重复执行不会造成破坏。若需回退，使用版本控制恢复 `src/adapters/eggy/` 与 `docs/debug_prints.md` 的变更，再运行回归脚本确认状态恢复。

## 产物与备注


预计出现的关键片段示例：

    local map_cfg = require("src.config.map")
    tile_names[i] = "t" .. tostring(map_cfg.path[i])

以及 TileRenderer 的 id 映射初始化片段。调试 print 的位置应完整列在 `docs/debug_prints.md`。

## 接口与依赖


仍使用 `src/config/map.lua` 的 `path` 作为棋盘索引顺序来源，仍使用 `TileRenderer.render_tile(unit, tile_id, owner_id)` 作为渲染入口。按钮事件沿用 `register_ui_manager_events` 与 `EggyLayer:dispatch_action`。不新增新的中间层或通用工具函数。

本次更新说明：首次创建计划，覆盖棋盘锚点/文本、回合按钮与调试 print 的修复需求，尚未实施。
