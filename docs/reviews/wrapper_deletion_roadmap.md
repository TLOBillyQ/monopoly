# Wrapper Deletion Roadmap

This report identifies "wrapper" code patterns in the `src` directory to align with `AGENTS.md` ("Delete wrappers that only forward calls").

## 1. Identified Wrappers

### A. High Priority (Redundant Layers)

#### 1. `src/gameplay/app/services/item_service.lua`
*   **Type:** Full Module Wrapper / Facade.
*   **Why:** Almost all functions are aliases to Domain modules (`Inventory`, `Executor`, `Strategy`) or thin dependency-injection wrappers. e.g., `ItemEffects.item_name = Inventory.item_name`.
*   **Usages:** Used via `game.services.item`.
*   **Action:** **Delete**.
*   **Safety:** The domain modules (`src/gameplay/domain/item_*.lua`) are stateless or operate on passed objects. App-layer logic can require them directly.

#### 2. `IntentDispatcher.dispatch_from_result` (in `src/gameplay/app/intent_dispatcher.lua`)
*   **Type:** Function Alias.
*   **Why:** `IntentDispatcher.dispatch_from_result = IntentDispatcher.dispatch`. Adds no value.
*   **Usages:** ~9 calls in codebase.
*   **Action:** **Delete** (replace with `.dispatch`).

### B. Medium Priority (Convenience Helpers)

#### 3. `ChanceService.draw_card` (in `src/gameplay/app/services/chance_service.lua`)
*   **Type:** Function Wrapper.
*   **Why:** Forwards to `random.weighted_choice(chance_cfg, ...)`.
*   **Action:** **Inline**. Callers should use `random.weighted_choice` directly with the config. This removes the "Service" dependency for a simple math operation.

#### 4. `GameState.tile_state` (in `src/util/game_state.lua`)
*   **Type:** Data Access Wrapper.
*   **Why:** Wraps `game.store:get(...)`.
*   **Action:** **Refactor/Inline**. If used frequently, it could be a method on `Board` or `Tile` entity, or kept as a util but strictly for `Love2D` adapter usage if that's the only consumer.
*   *Note:* Currently seems used by Presenter or debugging tools.

### C. Low Priority (Data Access / Necessary Abstraction)

#### 5. `src/gameplay/app/services/overlay_service.lua`
*   **Type:** Repository Wrapper.
*   **Why:** Encapsulates `game.store` paths for overlays (roadblocks/mines).
*   **Action:** **Keep** for now. While it "only updates the store", it centralizes the schema path `{"board", "overlays"}`. If we switch to a simpler state model (e.g. `game.board.overlays` table), this service becomes obsolete.

---

## 2. Execution Plan

### Step 1: Remove `IntentDispatcher` Alias
1.  Search `IntentDispatcher.dispatch_from_result`.
2.  Replace all occurrences with `IntentDispatcher.dispatch`.
3.  Remove the alias line in `src/gameplay/app/intent_dispatcher.lua`.

### Step 2: Dissolve `ChanceService.draw_card`
1.  Find caller (likely `src/gameplay/domain/landing.lua` or `services`).
2.  Replace `game.services.chance.draw_card()` with `random.weighted_choice(chance_cfg, ...)` (requires importing config).
3.  Remove `draw_card` from `ChanceService`.

### Step 3: Deconstruct `ItemService`
This is the largest task. `ItemService` is injected into `game.services.item`.
1.  **Refactor Callers:** Identify files using `game.services.item`.
    *   `src/gameplay/domain/landing.lua`
    *   `src/gameplay/domain/chance.lua`
    *   `src/gameplay/app/turn/start.lua`
    *   `src/gameplay/app/services/market_service.lua`
    *   `src/gameplay/app/services/tile_service.lua`
2.  **Replace with Domain Imports:**
    *   Instead of `item.give_item(...)`, use `require("src.gameplay.domain.item_inventory").give(...)`.
    *   For `handle_pass_players`, use `Executor.handle_pass_players` and pass `game.services` in the context table.
3.  **Remove Injection:** Remove `ItemService` from `src/app.lua` service registry.
4.  **Delete File:** Delete `src/gameplay/app/services/item_service.lua`.

### Step 4: Verification
1.  Run `scripts/deps_check.lua` to ensure no broken requires.
2.  Run `scripts/regression.lua` (if available) or manual test to ensure gameplay (items, chance cards) still works.

---

## 3. Summary

Deleting `ItemService` and `IntentDispatcher` alias will significantly reduce "code noise" and indirection, adhering to **Coding Rule #3 (Delete wrappers)** and **Rule #4 (Keep Lua simple)**.
