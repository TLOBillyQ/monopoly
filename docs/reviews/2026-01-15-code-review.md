# Code Review - Gameplay Land/AI/Items/Panel
Date: 2026-01-15

## Scope
- src/gameplay/domain/land.lua
- src/gameplay/ai/agent.lua
- src/gameplay/domain/item_post_effects.lua
- src/gameplay/domain/item_strategy.lua
- src/gameplay/app/choice_resolver.lua
- src/core/player.lua
- src/adapters/love2d/panel_renderer.lua
- src/adapters/love2d/presenter.lua

## Findings (ordered by severity)
1) Medium - Rent prompt skips free card if strong card is declined
- When the player has both strong (2009) and free (2001) cards, land effect prompts for the strong card first. If the player chooses "skip", the resolver immediately executes rent payment, and the free card is never offered.
- refs: src/gameplay/domain/land.lua:262, src/gameplay/app/choice_resolver.lua:144
- impact: player pays rent even though a free card exists.
- suggestion: on "skip" of strong, re-check free card or present a combined choice.

2) Low/Medium - Tax check card never triggers bankruptcy and differs from normal tax rules
- The tax-check effect (2014) checks `target.cash < 0` after deducting half the cash, so with non-negative cash this never triggers. Normal tax uses `<= 0`.
- refs: src/gameplay/domain/item_post_effects.lua:42-49, src/gameplay/domain/land.lua:163-166
- impact: players can end at 0 cash without elimination in this path, inconsistent with other money-loss flows.
- suggestion: align the condition (or document the rule difference explicitly).

3) Low - Tile detail panel never shows roadblock/mine status
- PanelRenderer reads overlays from store state, but overlays are runtime-only and are exposed via `view.board.overlays` in Presenter. The detail panel therefore always sees empty overlays.
- refs: src/adapters/love2d/panel_renderer.lua:88-97 and :220-226, src/adapters/love2d/presenter.lua:31-52
- impact: UI detail panel fails to show roadblock/mine presence for selected tiles.
- suggestion: use `view.board.overlays` (same approach as BoardRenderer).

4) Low - Obstacle-clear path uses fixed parity
- Item 2006 (clear obstacles ahead) uses parity=1 in both the effect and the AI pre-check. Movement path depends on parity in branch logic, so the cleared path can diverge from the actual movement path for even-parity moves.
- refs: src/gameplay/domain/item_post_effects.lua:152-160, src/gameplay/domain/item_strategy.lua:33-43
- impact: clear card may miss obstacles on the intended path or clear an unintended path.
- suggestion: pass the intended parity (e.g., pending move parity) or align with MovementService defaults.

## Questions / Assumptions
- Is the design intended to allow only one rent card prompt per landing (i.e., skipping strong implies no other cards)? If not, the current flow blocks free card usage.
- Should bankruptcy always trigger at `cash <= 0`, or are there exceptions for specific card effects?

## Optimization Roadmap (behavior-preserving)
Phase 1 (correctness first)
- Fix rent-card prompt flow so skipping strong can still offer free card (or combine prompts).
- Align tax-check elimination logic with the rest of the cash-loss rules.

Phase 2 (UI clarity)
- Pull overlays from `view.board.overlays` in PanelRenderer to make tile detail accurate.

Phase 3 (path consistency)
- Normalize path parity usage for obstacle-clearing and AI checks to match movement decisions.

## Tests / Coverage Gaps
- Add/extend tests for rent-card choice order (strong + free) and tax-check bankruptcy behavior.
- Add a UI-level test or snapshot check to confirm roadblock/mine detail visibility in the side panel.

# 代码评审 - Gameplay Land / AI / Items / Panel  
日期：2026-01-15

## 范围
- src/gameplay/domain/land.lua  
- src/gameplay/ai/agent.lua  
- src/gameplay/domain/item_post_effects.lua  
- src/gameplay/domain/item_strategy.lua  
- src/gameplay/app/choice_resolver.lua  
- src/core/player.lua  
- src/adapters/love2d/panel_renderer.lua  
- src/adapters/love2d/presenter.lua  

## 发现问题（按严重程度排序）
1) 中等 —— 拒绝强卡后未再提供免租卡  
- 当玩家同时持有强卡（2009）和免租卡（2001）时，地块效果会优先提示使用强卡。如果玩家选择“跳过”，解析器会立刻执行支付租金，免租卡将不会再被提供。  
- 参考：src/gameplay/domain/land.lua:262，src/gameplay/app/choice_resolver.lua:144  
- 影响：尽管存在免租卡，玩家仍然会支付租金。  
- 建议：在跳过强卡后重新检查免租卡，或合并为一个统一的选择提示。

2) 低/中 —— 查税卡不会触发破产，且与常规税收规则不一致  
- 查税效果（2014）在扣除一半现金后检查条件为 `target.cash < 0`，因此在现金非负的情况下永远不会触发。普通税收使用的是 `<= 0`。  
- 参考：src/gameplay/domain/item_post_effects.lua:42-49，src/gameplay/domain/land.lua:163-166  
- 影响：在该路径下，玩家可能以 0 现金结束而未被淘汰，与其他扣钱流程不一致。  
- 建议：统一判定条件（或明确文档说明该规则差异）。

3) 低 —— 地块详情面板不会显示路障/地雷状态  
- PanelRenderer 从 store state 读取 overlays，但 overlays 仅在运行时存在，并通过 Presenter 暴露在 `view.board.overlays` 中。因此详情面板始终看到的是空 overlays。  
- 参考：src/adapters/love2d/panel_renderer.lua:88-97 及 :220-226，src/adapters/love2d/presenter.lua:31-52  
- 影响：UI 详情面板无法显示所选地块是否存在路障或地雷。  
- 建议：与 BoardRenderer 一致，改用 `view.board.overlays`。

4) 低 —— 清除障碍的路径使用固定奇偶性  
- 道具 2006（清除前方障碍）在效果和 AI 预判中都使用了 `parity=1`。但移动路径在分支逻辑中依赖 parity，因此在偶数 parity 的移动情况下，清除路径可能与真实移动路径不一致。  
- 参考：src/gameplay/domain/item_post_effects.lua:152-160，src/gameplay/domain/item_strategy.lua:33-43  
- 影响：清障卡可能错过目标路径上的障碍，或清除了非预期路径。  
- 建议：传入预期的 parity（例如当前待执行移动的 parity），或与 MovementService 的默认逻辑保持一致。

## 问题 / 假设
- 设计上是否只允许每次落地提示一次租金卡（即跳过强卡就不再允许使用其他卡）？如果不是，当前流程会阻断免租卡的使用。  
- 破产是否应始终在 `cash <= 0` 时触发，还是某些特定卡牌效果存在例外？

## 优化路线图（保持行为不变）
**阶段 1（优先保证正确性）**  
- 修复租金卡提示流程，使跳过强卡后仍可提供免租卡（或合并提示）。  
- 统一查税卡的淘汰判定逻辑，使其与其他扣钱规则一致。

**阶段 2（UI 清晰度）**  
- 在 PanelRenderer 中从 `view.board.overlays` 拉取 overlays，确保地块详情显示准确。

**阶段 3（路径一致性）**  
- 规范清障与 AI 预判中 parity 的使用方式，使其与实际移动决策保持一致。

## 测试 / 覆盖缺口
- 新增或扩展测试：验证租金卡（强卡 + 免租卡）的选择顺序，以及查税卡的破产行为。  
- 新增 UI 层测试或快照校验，确认侧边面板中路障/地雷信息可见。
