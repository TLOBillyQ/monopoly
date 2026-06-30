-- Pure status resolution for the 3D player-status overlay: given a game/player,
-- decide which status key is active and the remaining-turn count to display.
-- Transient-state detection lives in status_signals; this module maps those
-- signals plus location/deity state onto a status key. Kept free of
-- scene/cache/specs dependencies so it stays unit-testable in isolation (the
-- scene-sync side lives in src.ui.render.status3d.status).
local signals = require("src.ui.render.status3d.status_signals")

local M = {}

local _deity_status_map = {
  poor = "poor",
  rich = "rich",
  angel = "angel",
}

local _location_effect_status = {
  hospital = "hospital",
  mountain = "mountain",
}

local function _location_effect_active(game, player, status)
  if (status.stay_turns or 0) > 0 or status.pending_location_effect ~= nil then
    return true
  end
  return signals.is_player_detained_this_turn(game, player)
end

local function _tile_location_status(board, position)
  if not board or not board.get_tile then
    return nil
  end
  local tile = board:get_tile(position)
  local tile_type = tile and tile.type or nil
  return _location_effect_status[tile_type]
end

local function _resolve_location_status(game, player, status)
  if not _location_effect_active(game, player, status) then
    return nil
  end
  local expected = _tile_location_status(game.board, player.position)
  if not expected then
    return nil
  end
  local pending = status.pending_location_effect
  if pending ~= nil and pending ~= expected then
    return nil
  end
  return expected
end

local function _resolve_deity_status(status)
  local deity = status.deity
  if not deity then
    return nil
  end
  if (deity.remaining or 0) <= 0 then
    return nil
  end
  return _deity_status_map[deity.type]
end

local function _resolve_stay_turns_remaining(game, player)
  local stay_turns = player.status and player.status.stay_turns or 0
  -- 扣留剩余回合 uses the 含当前回合 (inclusive) convention (ADR 0024). During the player's
  -- own frozen turn the stay_turns counter has already decremented at turn start, so the
  -- inclusive remaining is +1 - the same number the detention tip shows, and never 0 while
  -- detained. Between turns (and at landing) the raw counter already is the inclusive value.
  if signals.is_player_detained_this_turn(game, player) then
    return stay_turns + 1
  end
  return stay_turns
end

local function _resolve_deity_remaining(player)
  local deity = player.status and player.status.deity
  if not deity then
    return 0
  end
  local remaining = deity.remaining or 0
  local cap = player.deity_duration_turns
  if cap then
    return math.min(remaining, cap)
  end
  return remaining
end

local function _resolve_secondary_status_key(game, player, status, has_roadblock)
  local location = _resolve_location_status(game, player, status)
  if location then
    return location
  end
  if has_roadblock then
    return "roadblock"
  end
  return _resolve_deity_status(status)
end

function M.resolve_player_status_key(game, player)
  if player == nil or player.eliminated == true then
    return nil
  end
  local status = player.status or {}
  local last_turn = game and game.last_turn or nil
  local has_roadblock = signals.check_roadblock_status(last_turn, player)
  if has_roadblock and signals.has_pending_roadblock_trigger(game, player) then
    return "roadblock"
  end
  return _resolve_secondary_status_key(game, player, status, has_roadblock)
end

function M.resolve_remaining_value(game, player, remaining_field)
  if remaining_field == "stay_turns" then
    return _resolve_stay_turns_remaining(game, player)
  end
  if remaining_field == "deity_remaining" then
    return _resolve_deity_remaining(player)
  end
  return 0
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=187cb8b508efd4d0
scope.0.id=chunk:src/ui/render/status3d/status_resolve.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=124
scope.0.semanticHash=5f34e2b5b4878907
scope.0.lastMutatedAt=2026-06-30T13:47:48Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=6
scope.0.lastMutationKilled=6
scope.1.id=function:_location_effect_active:22
scope.1.kind=function
scope.1.startLine=22
scope.1.endLine=27
scope.1.semanticHash=c0bd827f75059ac3
scope.1.lastMutatedAt=2026-06-30T13:47:48Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=8
scope.1.lastMutationKilled=8
scope.2.id=function:_tile_location_status:29
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=36
scope.2.semanticHash=47e02db3fa1fe5db
scope.2.lastMutatedAt=2026-06-30T13:47:48Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:_resolve_location_status:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=51
scope.3.semanticHash=76e37b336fb83484
scope.3.lastMutatedAt=2026-06-30T13:47:48Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=7
scope.3.lastMutationKilled=7
scope.4.id=function:_resolve_deity_status:53
scope.4.kind=function
scope.4.startLine=53
scope.4.endLine=62
scope.4.semanticHash=866b8e93e36ca58c
scope.4.lastMutatedAt=2026-06-30T13:47:48Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=5
scope.4.lastMutationKilled=5
scope.5.id=function:_resolve_stay_turns_remaining:64
scope.5.kind=function
scope.5.startLine=64
scope.5.endLine=74
scope.5.semanticHash=4a63f43186389c5f
scope.5.lastMutatedAt=2026-06-30T13:47:48Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:_resolve_deity_remaining:76
scope.6.kind=function
scope.6.startLine=76
scope.6.endLine=87
scope.6.semanticHash=ee6de42734b468e6
scope.6.lastMutatedAt=2026-06-30T13:47:48Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=6
scope.6.lastMutationKilled=6
scope.7.id=function:_resolve_secondary_status_key:89
scope.7.kind=function
scope.7.startLine=89
scope.7.endLine=98
scope.7.semanticHash=4c997953cff78852
scope.7.lastMutatedAt=2026-06-30T13:47:48Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
scope.8.id=function:M.resolve_player_status_key:100
scope.8.kind=function
scope.8.startLine=100
scope.8.endLine=111
scope.8.semanticHash=8ac8c9b4d9d27179
scope.8.lastMutatedAt=2026-06-30T13:47:48Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=12
scope.8.lastMutationKilled=12
scope.9.id=function:M.resolve_remaining_value:113
scope.9.kind=function
scope.9.startLine=113
scope.9.endLine=121
scope.9.semanticHash=e71426e63b03aee6
scope.9.lastMutatedAt=2026-06-30T13:47:48Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
]]
