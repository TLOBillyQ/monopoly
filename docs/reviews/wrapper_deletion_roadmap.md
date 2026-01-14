# Wrapper Deletion Roadmap

This report identifies "wrapper" code patterns in the `src` directory to align with `AGENTS.md` ("Delete wrappers that only forward calls") and tracks the progress of their removal.

## 1. Identified Wrappers & Status

### A. High Priority (Redundant Layers)

#### 1. `src/gameplay/app/services/item_service.lua`
*   **Type:** Full Module Wrapper / Facade.
*   **Why:** Almost all functions were aliases to Domain modules (`Inventory`, `Executor`, `Strategy`).
*   **Status:** ✅ **DELETED**
*   **Resolution:**
    *   Callers (`landing.lua`, `start.lua`, `market_service.lua`, etc.) refactored to use `src/gameplay/domain/*` directly.
    *   `handle_choice` logic moved to `src/gameplay/app/choice_resolver.lua`.
    *   Removed from `App` service registry.

#### 2. `IntentDispatcher.dispatch_from_result` (in `src/gameplay/app/intent_dispatcher.lua`)
*   **Type:** Function Alias.
*   **Why:** Redundant alias for `.dispatch`.
*   **Status:** ✅ **DELETED**
*   **Resolution:** All 11+ usages replaced with `dispatch`. Alias removed.

### B. Medium Priority (Convenience Helpers)

#### 3. `ChanceService.draw_card` (in `src/gameplay/app/services/chance_service.lua`)
*   **Type:** Function Wrapper.
*   **Why:** Forwarded to `random.weighted_choice`.
*   **Status:** ✅ **DELETED**
*   **Resolution:** Callers now use `random.weighted_choice(chance_cfg, ...)` directly.

#### 4. `GameState.tile_state` (in `src/util/game_state.lua`)
*   **Type:** Data Access Wrapper.
*   **Why:** Wraps `game.store:get(...)`.
*   **Status:** ✅ **DELETED**
*   **Resolution:**
    *   Moved logic to `src/core/tile.lua` as static `Tile.get_state(game, tile)`.
    *   Refactored 6+ callers in Domain and Tests to use `Tile.get_state`.
    *   Deleted `src/util/game_state.lua`.

### C. Low Priority (Data Access / Necessary Abstraction)

#### 5. `src/gameplay/app/services/overlay_service.lua`
*   **Type:** Repository Wrapper.
*   **Why:** Encapsulates `game.store` paths for overlays.
*   **Status:** ⏸️ **Kept**
*   **Justification:** While thin, it centralizes the schema path `{"board", "overlays"}`. Removing it requires deciding where this schema knowledge belongs (likely `Board` domain).

---

## 2. Completed Actions (Log)

| Component | Action | Result |
| :--- | :--- | :--- |
| `IntentDispatcher` | Remove Alias | Alias `dispatch_from_result` removed, callers updated. |
| `ChanceService` | Inline | `draw_card` removed, direct random access used. |
| `ItemService` | **DELETE** | File deleted (-293 lines). Callers decoupled. |
| `GameState` | **DELETE** | Logic moved to `Tile.get_state`. File deleted. |
| **Total** | **Cleanup** | **~100+ lines net reduction** |

## 3. Next Steps
1.  **Evaluate `OverlayService`**:
    *   Consider moving overlay state directly onto `Board` object in memory, synced to store, to remove the "Service" layer entirely.
