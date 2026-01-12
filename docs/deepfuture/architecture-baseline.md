# Gameplay Architecture Baseline (Monopoly)

> Snapshot of current gameplay structure for migration phases. Keep behavior unchanged while tightening boundaries.

## Entry and Composition
- Entry: `main.lua` wires `package.path` then starts `src.adapters.love2d.love_layer` with a game factory.
- Factory: `src/app.lua` builds board, players, RNG, store, and service registry; `src/bootstrap/board_factory.lua` creates the default board.
- Runtime: `App.turn_manager` drives phases (`start`, `roll`, `move`, `land`, `end_turn`) via `src/gameplay/app/turn/*`.

## Layering (current)
- Domain data/rules: `src/core` (Board/Player/Inventory) + `src/gameplay/domain` (items, effects, lands, chance).
- Application/use cases: `src/gameplay/app` (turn phases, resolvers, services). Services mutate store and call domain helpers.
- Infrastructure: `src/gameplay/infra` (RNG, Store, sync helpers).
- Adapters/UI: `src/adapters/love2d` renders board and panels; reads game snapshots.
- Config: `src/config` holds tiles, items, roles, chance cards, constants.

## State and Persistence
- Single source of truth: `src/gameplay/infra/store.lua` holds board overlays, tile ownership/level, players, turn, RNG snapshot.
- Live objects (players, board) mirror store; helper setters in `App` keep store in sync.
- RNG: `src/gameplay/infra/rng.lua` provides deterministic `next`; state stored at `store.rng`.

## Interaction Flow
- Movement: `MovementService.move` advances players, handles roadblocks, pass-start bonus, and occupancy.
- Landing: `LandingResolver.resolve` dispatches mandatory/optional effects; opens choices when UI is enabled.
- Choices: `Choice`/`ChoiceResolver` manage pending choices, used by land optional flows and item interactions.
- Services: tile/status/market/chance/bankruptcy encapsulate side effects; injected via `game.services`.

## Guardrails (Phase 0)
- Dependency rules enforced by `scripts/deps_check.lua` (no cross-service requires, gameplay → adapters forbidden, domain → app forbidden).
- Regression script `scripts/regression.lua` exercises pass-start bonus, start reward, roadblocks, monster/missile items, land optional flows, and chance mandatory path.

## Known Gaps Before Migration
- Domain split: `core` vs `gameplay/domain` naming mismatch.
- App acts as god object (state + writes + orchestration) with sparse use-case boundaries.
- UI coupling: `ui_enabled` branches and direct access from adapters.
- Store/RNG lifecycle shared and updated in many places; services can call each other directly.

Use this as the reference baseline for subsequent phases; do not change gameplay semantics during refactors.