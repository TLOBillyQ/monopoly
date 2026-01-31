# Store 状态树写入点（Writers）

本文列出 Store 状态树的写入点与路径模式，方便快速定位“状态从哪里写入”。

Store 的路径是一个数组，例如：

    { "players", 1, "cash" }

含义是 `state.players[1].cash`。

## Manager/GameManager/GameState.lua

此模块通过 `_store_set` 与 `store:get` 读写 Store，是当前最核心的写入点。

写入（`store:set`）：

- 玩家：
  - `{ "players", <player.id>, "status", <key> }`：玩家状态字典（如 buff、标记等）。
  - `{ "players", <player.id>, "seat_id" }`：座位号。
  - `{ "players", <player.id>, "eliminated" }`：是否出局（boolean）。
  - `{ "players", <player.id>, "properties", <tile_id> }`：是否拥有某地块（拥有写 `true`，取消拥有写 `nil`）。
  - `{ "players", <player.id>, "inventory" }`：背包快照（由 `CompositionRoot.snapshot_inventory()` 生成）。
  - `{ "players", <player.id>, "position" }`：当前位置索引（棋盘格 index）。

- 棋盘地块（仅 land）：
  - `{ "board", "tiles", <tile.id>, "owner_id" }`：地块归属（`nil` 表示无主）。
  - `{ "board", "tiles", <tile.id>, "level" }`：地块等级（`reset_tile` 会写 0）。

- 回合/动画：
  - `{ "turn", "action_anim_seq" }`：动作动画序号（自增）。
  - `{ "turn", "action_anim" }`：动作动画 payload（包含 `seq`）。

读取（`store:get`）：

- `{ "turn", "current_player_index" }`：当前玩家下标（默认 1）。
- `{ "turn", "pending_choice" }`：当前待处理的选择（choice）。
