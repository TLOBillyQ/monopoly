# Design vs Code Gaps (Design/蛋仔策划案--大富翁.docx)

This list captures behaviors that are missing or inconsistent with the design doc.

- Win condition: no time-limit win by highest assets (tie winners) is implemented; game ends only when <=1 player remains. (`src/game.lua`)
- Action timeout: 10s auto-confirm is not implemented; `action_timeout_seconds` is unused. (`src/config/constants.lua`)
- Chance card count: design says 34 cards; config defines 37 (extra 3035-3037). (`src/config/chance_cards.lua`)
- Roadblock effect: design says stop for 1 full turn; code only stops movement and clears the roadblock, no stay turn applied. (`src/gameplay/movement_service.lua`)
- Mine timing: design says check mine after event resolution; pipeline triggers mine before land buy/upgrade/rent/tax. (`src/config/landing_effects.lua`)
- Clear-obstacle card: design says robot splits at branches to clear all paths; code only clears one forward path. (`src/gameplay/item_post_effects.lua`)
- Chance-card forced move to market: design expects market UI; code auto-buys for human and skips for AI. (`src/gameplay/chance.lua`, `src/gameplay/market_service.lua`)
- Land buy/upgrade prompt on insufficient cash: design shows prompt and fails on confirm; code hides the option when cash is insufficient. (`src/gameplay/land.lua`)
- Item discard: design allows discarding items from inventory; no discard flow exists. (`src/gameplay/item_phase.lua`, `src/gameplay/choice_handlers/item_choice_handler.lua`)
- AI item usage: design says AI uses any usable item; AI never uses mine card (2005) and only uses a curated subset. (`src/gameplay/item_strategy.lua`)
- Rich/Poor deity effects: design says bonus/fine doubling; code only doubles rent and some transfers, not general chance add/pay cash. (`src/gameplay/land_actions.lua`, `src/gameplay/chance.lua`)
- Bankruptcy trigger: design says eliminate at cash == 0; code only eliminates when cash < 0 (chance/tax) or when rent/hospital forces bankruptcy. (`src/gameplay/chance.lua`, `src/gameplay/item_post_effects.lua`)
- Steal card timing: design triggers mid-move and then continues remaining steps; code processes steal after movement with no mid-move resume. (`src/gameplay/landing.lua`, `src/gameplay/movement_service.lua`)
- Max 4 players per road tile: design limits occupancy; code has no enforcement. (`src/game.lua`)
- Inventory full messaging: design shows a user prompt; code only logs a warning on item draw failure. (`src/gameplay/item_inventory.lua`)
