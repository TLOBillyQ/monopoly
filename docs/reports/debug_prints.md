说明：以下为临时调试 print，发布前统一删除。

- `src/adapters/eggy/eggy_runtime.lua`：`btn_next` 点击回调触发日志。
- `src/adapters/eggy/eggy_layer.lua`：`dispatch_action` 接收到 `next` 按钮动作日志。
- `src/adapters/eggy/eggy_layer.lua`：`step_turn` 调用 `advance_turn` 的入口日志。
- `src/gameplay/turn_manager.lua`：`run_turn` 入口日志，用于确认回合推进链路。
