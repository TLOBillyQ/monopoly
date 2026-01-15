# Code Review - AI Agent / AutoRunner
Date: 2026-01-15

## Scope
- src/gameplay/ai/agent.lua
- src/adapters/love2d/auto_runner.lua

## Findings (ordered by severity)
1) Medium - AI target-choice ignores "no target" signal and forces item use
- Agent.pick_target_player returns nil for items like 2011 (player already richest) and 2016 (player lacks poor god), but auto_action_for_choice still falls back to first option.
- refs: src/gameplay/ai/agent.lua:125-155, src/gameplay/ai/agent.lua:216-223
- impact: AI may use disadvantageous items that its own strategy intended to skip.

2) Low/Medium - Remote dice simulation ignores movement interrupts and obstacles
- simulate_landing only advances by facing and does not account for roadblocks/mines or market interrupt logic, so predicted landing tiles can be unreachable.
- refs: src/gameplay/ai/agent.lua:20-29 (contrast with src/gameplay/app/services/movement_service.lua:43-70)
- impact: AI can choose a dice value that does not lead to the intended tile in real movement, reducing decision correctness.

3) Low - AutoRunner assumes choices are always cancellable when options are empty
- When pending_choice has no options, AutoRunner emits choice_cancel without checking allow_cancel. If a future choice forbids cancel, auto-play will send an invalid action.
- refs: src/adapters/love2d/auto_runner.lua:46-53
- impact: auto-play could stall or clear a required choice in edge cases.

## Questions / Assumptions
- Are there any choice types that can present zero options with allow_cancel=false? If not, AutoRunner's current behavior may be acceptable.
- Is the AI expected to avoid using target items when its own heuristic returns nil, or should it still pick a target by default?

## Future: 托管/AI/AutoRunner 合并思考
- 三者关注点不同：AI = 决策策略，AutoRunner = UI层自动点击，托管 = “替玩家做决定”的产品功能。完全合并会让 UI 自动化与策略耦合，反而难维护。
- 更现实的合并点是“自动行动入口”：托管可以复用 TurnManager 的自动选择路径（Agent.auto_action_for_choice + Strategy.auto_pre_action），而 AutoRunner 继续只负责 Love2D UI 自动按键。
- 若要统一，建议在应用层引入单一“auto_action 生产器”入口（返回 action 或 nil），托管与 AI 共享该入口，AutoRunner 仅在 UI 层模拟按钮，不直接参与策略。
- 如果托管需求主要是“玩家离线自动跑”，优先把托管接到游戏内的 Choice/Turn 流程，避免依赖 UI 点击顺序（否则不同前端会出现不一致）。

## Optimization Roadmap (behavior-preserving)
Phase 1 (correctness)
- Let item_target_player honor pick_target_player=nil by cancelling rather than forcing the first option.
- Align remote dice simulation with MovementService rules for roadblocks/mines/market interrupts when evaluating landing tiles.

Phase 2 (robustness)
- Guard AutoRunner choice cancellation with allow_cancel checks; if not cancellable, wait or pick a safe default only when options exist.

Phase 3 (AI quality)
- Extend remote_priority to handle new/unknown tile types explicitly or add a conservative fallback rule.

## Tests / Coverage Gaps
- Add an AI regression test where player is richest and has 2011 to ensure auto_action cancels (or does not use item).
- Add a test to confirm remote dice evaluation respects roadblocks/market interrupts.
- Add an auto-run test for empty-option choices to ensure behavior is defined.


# 代码评审 - AI Agent / AutoRunner  
日期：2026-01-15

## 范围
- src/gameplay/ai/agent.lua  
- src/adapters/love2d/auto_runner.lua  

## 发现问题（按严重程度排序）
1) 中等 —— AI 目标选择忽略“无目标”信号并强制使用道具  
- 对于 2011（玩家已是最富）和 2016（玩家没有穷神）等道具，`Agent.pick_target_player` 会返回 `nil`，但 `auto_action_for_choice` 仍会回退选择第一个选项。  
- 参考：src/gameplay/ai/agent.lua:125-155，src/gameplay/ai/agent.lua:216-223  
- 影响：AI 可能会使用其自身策略本应跳过的不利道具。

2) 低/中 —— 远程骰子模拟忽略移动中断与障碍  
- `simulate_landing` 仅按朝向推进，不考虑路障/地雷或市场中断逻辑，导致预测落点在真实移动中可能不可达。  
- 参考：src/gameplay/ai/agent.lua:20-29（对比 src/gameplay/app/services/movement_service.lua:43-70）  
- 影响：AI 可能选择一个在真实移动中无法到达预期格子的骰子点数，降低决策正确性。

3) 低 —— AutoRunner 在选项为空时假设总是可取消  
- 当 `pending_choice` 没有选项时，AutoRunner 会直接发送 `choice_cancel`，但未检查 `allow_cancel`。若未来某些选择不允许取消，自动流程将发送无效操作。  
- 参考：src/adapters/love2d/auto_runner.lua:46-53  
- 影响：在边缘情况下，自动游玩可能卡住或清空一个必须完成的选择。

## 问题 / 假设
- 是否存在 `allow_cancel=false` 且选项数量为 0 的选择类型？若不存在，AutoRunner 当前行为可能是可接受的。  
- 当 AI 的启发式返回 `nil` 时，是否期望 AI 避免使用目标型道具，还是仍应默认选择一个目标？

## Future: 托管/AI/AutoRunner 合并思考
- 三者关注点不同：AI = 决策策略，AutoRunner = UI层自动点击，托管 = “替玩家做决定”的产品功能。完全合并会让 UI 自动化与策略耦合，反而难维护。
- 更现实的合并点是“自动行动入口”：托管可以复用 TurnManager 的自动选择路径（Agent.auto_action_for_choice + Strategy.auto_pre_action），而 AutoRunner 继续只负责 Love2D UI 自动按键。
- 若要统一，建议在应用层引入单一“auto_action 生产器”入口（返回 action 或 nil），托管与 AI 共享该入口，AutoRunner 仅在 UI 层模拟按钮，不直接参与策略。
- 如果托管需求主要是“玩家离线自动跑”，优先把托管接到游戏内的 Choice/Turn 流程，避免依赖 UI 点击顺序（否则不同前端会出现不一致）。

## 优化路线图（保持行为不变）
**阶段 1（正确性）**  
- 当 `pick_target_player=nil` 时，`item_target_player` 应选择取消，而不是强制选择第一个选项。  
- 在评估落点时，使远程骰子模拟与 `MovementService` 的路障/地雷/市场中断规则对齐。

**阶段 2（健壮性）**  
- 在 AutoRunner 中对选择取消进行 `allow_cancel` 校验；若不可取消，则等待，或仅在存在选项时选择一个安全默认值。

**阶段 3（AI 质量）**  
- 扩展 `remote_priority`，显式处理新增/未知的格子类型，或增加保守的兜底规则。

## 测试 / 覆盖缺口
- 新增 AI 回归测试：当玩家已是最富且持有 2011 时，确保自动行为会取消（或不使用道具）。  
- 新增测试：确认远程骰子评估遵循路障/市场中断规则。  
- 新增自动流程测试：针对“无选项”的选择，确保行为有明确定义。
