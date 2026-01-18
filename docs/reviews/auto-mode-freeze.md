# 自动模式卡死定位与修复方案

## 现象复现
- 用例：运行游戏，选择自动模式（UI 自动播放）。
- 日志停在：玩家1 经过黑市后继续移动，最后记录为“玩家1 从 黑市 移动到 北京路”，无后续回合日志。

## 结论（定位）
卡死发生在“落地处理 -> 可选效果选择”阶段。日志停止在移动结束之后，未出现“购买北京路/缴税/付租”等落地日志，符合进入 `wait_choice` 但无人完成选择的表现。

关键路径：
- `src/gameplay/turn_move.lua`：黑市中断后返回 `wait_choice`，选择结束后恢复移动。
- `src/gameplay/turn_land.lua` + `src/gameplay/effect_pipeline.lua`：落地时生成可选效果（如 `buy_land`）并派发 `need_choice`，进入 `wait_choice`。
- `src/gameplay/turn_manager.lua`：若 `pending_choice` 存在且无自动动作，则停在 `wait_choice`。

推断卡死原因：
- UI 自动模式仅自动点击“下一步”和弹窗按钮（`src/adapters/love2d/auto_runner.lua`）。
- `pending_choice` 需要被选择/取消才能继续；当自动模式开启但当前玩家不是 AI/auto 时，`Agent.auto_action_for_choice` 不会返回动作（`src/gameplay/agent.lua`）。
- 若弹窗未被自动操作（或 UI 自动切换时机导致错过 modal），流程停在 `wait_choice`，表现为卡死。

## 修复思路
目标：不改变原有规则，只补齐自动模式下对 `pending_choice` 的处理，避免死等。

方案 A（推荐，最小侵入）：
1) 在 UI 自动模式启用时，将当前玩家临时视为 auto（仅用于 choice 处理）。
2) 由 `turn_manager.decide_choice_action` 走 `Agent.auto_action_for_choice` 分支，自动选择/取消。

实现位置建议：
- `src/adapters/love2d/love_layer.lua`：在 `handle_ui_button("auto")`/`keypressed('a')` 切换时设置一个 UI 标记（如 `ui.auto_play`），并在游戏执行前把当前玩家的 `auto` 状态临时同步，或直接向 `game:dispatch_action` 传入自动选择动作。
- 或在 `src/gameplay/turn_manager.lua` 的 `decide_choice_action` 中，当 `game.ui_port` 存在且 `ui.auto_play` 开启时，允许走自动选择逻辑（不依赖 `player.auto`）。

方案 B（兜底）：
- 在 `LoveLayer:update` 中检测 `pending_choice` 且自动模式开启时，直接 dispatch `choice_select/choice_cancel`（优先 `Agent.auto_action_for_choice`，否则默认选择第一项/取消）。

## 风险与验证
- 风险：自动模式可能替代玩家做出选择；但自动模式本意即自动推进，且只在自动模式开启时触发。
- 验证：复现用例，确认在黑市中断+落地购买时能自动完成选择并继续到下一回合。

## 建议测试
- 运行 `lua -p` 语法检查。
- `lua tests/deps_check.lua`
- `lua tests/regression.lua`
