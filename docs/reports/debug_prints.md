说明：以下为临时调试 print，发布前统一删除。

- `Manager/Adapter/Eggy/EggyRuntime.lua`：`btn_next` 点击回调触发日志。
- `Manager/Adapter/Eggy/EggyLayer.lua`：`dispatch_action` 接收到 `next` 按钮动作日志。
- `Manager/Adapter/Eggy/EggyLayer.lua`：`step_turn` 调用 `advance_turn` 的入口日志。
- `Manager/GameManager/Turn/TurnManager.lua`：`run_turn` 入口日志，用于确认回合推进链路。
