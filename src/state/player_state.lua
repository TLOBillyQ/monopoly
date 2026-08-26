-- Player state mixin source.
-- The actual player_state methods (status/balance/deity/location ops) are
-- now installed onto the Game class by `src/app/compose_game.lua` to honour the
-- Dependency Rule: state (L7) must not depend on player (L5).
--
-- This empty table is kept so `src/state/game_state.lua` can still `require` it
-- and call `_install_mixin(...)` as a no-op, preserving the existing wiring.
-- See docs/decisions.md ADR 0001.
return {}

--[[ mutate4lua-manifest
version=4
projectHash=01f77cc88a3345b0
scope.0.id=chunk:src/state/player_state.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=10
scope.0.semanticHash=ed54941aaa6f3996
]]
