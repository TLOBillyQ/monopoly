-- Player state mixin source.
-- The actual player_state methods (status/balance/deity/vehicle/location ops) are
-- now installed onto the Game class by `src/app/compose_game.lua` to honour the
-- Dependency Rule: state (L7) must not depend on player (L5).
--
-- This empty table is kept so `src/state/game_state.lua` can still `require` it
-- and call `_install_mixin(...)` as a no-op, preserving the existing wiring.
-- See ADR docs/decisions/0001-seven-layer-with-foundation.md (D6).
return {}
