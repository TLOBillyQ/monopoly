# src 重构审查：去兼容化与精简方案（进度版）

## 状态对齐
- ✅ UI 单通道：`UI.is_available` 仅看 `ui_port`，`ui_hooks` 兼容已清理；落地/道具/导弹等可选行为一律产出 choice intent，TurnManager 在无 UI 时自动选择。
- ✅ Store 单源：地块 owner/level 不再写回 tile 对象；覆盖物不再缓存 `game.overlays`，全部读写走 store + OverlayService。
- ✅ 依赖显式：Chance/TileService/Item post effects 等关键路径直接 `assert` 缺失服务；无“缺服务继续跑”分支。
- ✅ 测试基线：`scripts/regression.lua` 覆盖 UI/无 UI 情况，导弹/路障等通过 choice → resolver 流程。
- ✅ 渲染对齐 store：board/panel renderer 直接消费 presenter 提供的 view.state（tiles/overlays/players/turn），未再读取 `game.overlays` 或 tile 运行时缓存。
- ✅ Store schema 明示：board/turn/players/rng 结构已文档化；`GameState.tile_state` 去掉兜底返回，缺状态直接 assert 以暴露漏写。
- ✅ Choice 下沉：item/market/租税/遥控骰子/偷道具等 choice 处理下沉到对应服务，ChoiceResolver 仅保留落地可选效果分支；IntentDispatcher 单一入口。

## 现状洞察
- 无新风险已知。
## Store schema（当前）
- board: tiles[<tile_id>] = { owner_id, level }；overlays = { roadblocks = { [idx] = true }, mines = { [idx] = true } }。
- turn: { current_player_index, turn_count, phase, pending_choice, choice_seq }。
- players: keyed by id，字段包含 { id,name,role_id,is_ai,auto,cash,position,seat_id,eliminated,properties,status,inventory }；status 下有 pending_remote_dice/pending_dice_multiplier/pending_free_rent/pending_tax_free/deity。
- rng: rng:snapshot() 结果或 nil。

## 待办重点
（空）

## 已删除/合并
- `src/gameplay/domain/property.lua`（地块别名）。
- `src/util/error_handling.lua`（缺服务兼容日志）。
- Tile 对象上的 owner/level 双写，`game.overlays` 缓存。
