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
