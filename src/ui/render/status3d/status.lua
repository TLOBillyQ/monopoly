local specs = require("src.ui.render.status3d.specs")
local scene = require("src.ui.render.status3d.scene")

local M = {}

local _remaining_text_cache = {}
local _remaining_text_prefix = "剩余回合："

local function _get_remaining_text(remaining)
  local text = _remaining_text_cache[remaining]
  if text == nil then
    text = _remaining_text_prefix .. tostring(remaining)
    _remaining_text_cache[remaining] = text
  end
  return text
end

local function _is_roadblock_trigger_for_player(anim, player_id)
  return anim
      and anim.kind == "roadblock_trigger"
      and anim.player_id == player_id
end

local function _queued_roadblock_trigger_for_player(queue, player_id)
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if _is_roadblock_trigger_for_player(entry, player_id) then
      return true
    end
  end
  return false
end

local function _has_pending_roadblock_trigger(game, player)
  if not (game and game.turn and player and player.id ~= nil) then
    return false
  end
  if _is_roadblock_trigger_for_player(game.turn.action_anim, player.id) then
    return true
  end
  return _queued_roadblock_trigger_for_player(game.turn.action_anim_queue, player.id)
end

local _deity_status_map = {
  poor = "poor",
  rich = "rich",
  angel = "angel",
}

local _location_effect_status = {
  hospital = "hospital",
  mountain = "mountain",
}

local function _has_detention_wait(turn)
  if not turn then
    return false
  end
  local notice_active = turn.no_action_notice_active == true
  local detained_active = turn.detained_wait_active == true or turn.phase == "detained_wait"
  return notice_active or detained_active, notice_active
end

local function _last_turn_matches_player(last_turn, player)
  return last_turn
      and last_turn.player_id == player.id
      and last_turn.skipped == true
      and last_turn.stay_turns ~= nil
end

local function _notice_matches_player(turn, player, notice_active)
  return not notice_active or turn.no_action_notice_player_id == player.id
end

local function _is_player_detained_this_turn(game, player)
  if game == nil or player == nil then
    return false
  end
  local wait_active, notice_active = _has_detention_wait(game.turn)
  if not wait_active then
    return false
  end
  if not _last_turn_matches_player(game.last_turn, player) then
    return false
  end
  return _notice_matches_player(game.turn, player, notice_active)
end

local function _check_roadblock_status(last_turn, player)
  if not last_turn then
    return false
  end
  if last_turn.player_id ~= player.id then
    return false
  end
  local move_result = last_turn.move_result
  return move_result ~= nil and move_result.stopped_on_roadblock == true
end

local function _resolve_location_status(game, player, status)
  local stay_turns = status.stay_turns or 0
  local detained = _is_player_detained_this_turn(game, player)
  local pending = status.pending_location_effect
  if stay_turns <= 0 and not detained and pending == nil then
    return nil
  end
  local board = game.board
  if not board or not board.get_tile then
    return nil
  end
  local tile = board:get_tile(player.position)
  local tile_type = tile and tile.type or nil
  local expected = _location_effect_status[tile_type]
  if not expected then
    return nil
  end
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
  if _is_player_detained_this_turn(game, player) then
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

function M.resolve_player_status_key(game, player)
  if player == nil or player.eliminated == true then
    return nil
  end
  local status = player.status or {}
  local last_turn = game and game.last_turn or nil
  local has_roadblock = _check_roadblock_status(last_turn, player)
  if has_roadblock and _has_pending_roadblock_trigger(game, player) then
    return "roadblock"
  end
  local location = _resolve_location_status(game, player, status)
  if location then
    return location
  end
  if has_roadblock then
    return "roadblock"
  end
  return _resolve_deity_status(status)
end

local function _resolve_remaining_value(game, player, remaining_field)
  if remaining_field == "stay_turns" then
    return _resolve_stay_turns_remaining(game, player)
  end
  if remaining_field == "deity_remaining" then
    return _resolve_deity_remaining(player)
  end
  return 0
end

local function _resolve_text_status_context(cache, player, status_key, game)
  local spec = specs.status_specs[status_key]
  if not (spec and spec.text_node_name) then
    return nil, nil
  end
  local remaining = _resolve_remaining_value(game, player, spec.remaining_field)
  local text_node = cache.text_nodes[player.id] and cache.text_nodes[player.id][status_key]
  if remaining <= 0 or text_node == nil then
    return nil, nil
  end
  return remaining, text_node
end

local function _sync_text_status(cache, player, status_key, roles, game)
  local remaining, text_node = _resolve_text_status_context(cache, player, status_key, game)
  if remaining == nil then
    return
  end
  local text = _get_remaining_text(remaining)
  for _, role in ipairs(roles) do
    if role and role.set_label_text then
      pcall(role.set_label_text, text_node, text)
    end
  end
end

function M.sync_layer_status(cache, player, status_key, deps, game)
  local player_id = player.id
  local player_layers = cache.layers[player_id]
  if not player_layers then
    return
  end
  local roles = scene.resolve_observer_roles()
  if cache.last_status_key_by_player[player_id] == status_key then
    _sync_text_status(cache, player, status_key, roles, game)
    return
  end
  for _, key in ipairs(specs.status_priority) do
    local layer = player_layers[key]
    if layer then
      scene.set_layer_visible_for_roles(layer, roles, status_key == key, deps)
    end
  end
  _sync_text_status(cache, player, status_key, roles, game)
  cache.last_status_key_by_player[player_id] = status_key
end

M._M_test = {
  _has_pending_roadblock_trigger = _has_pending_roadblock_trigger,
}

return M

--[[ mutate4lua-manifest
version=2
projectHash=7e5ecd7824058fac
scope.0.id=chunk:src/ui/render/status3d/status.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=235
scope.0.semanticHash=7de98f9fe9fdcf32
scope.1.id=function:_get_remaining_text:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=16
scope.1.semanticHash=265d86e3382fb223
scope.2.id=function:_is_roadblock_trigger_for_player:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=22
scope.2.semanticHash=e4c1d2f457417c4a
scope.3.id=function:_has_pending_roadblock_trigger:36
scope.3.kind=function
scope.3.startLine=36
scope.3.endLine=44
scope.3.semanticHash=bc7ac1d3378bcfaf
scope.4.id=function:_has_detention_wait:57
scope.4.kind=function
scope.4.startLine=57
scope.4.endLine=64
scope.4.semanticHash=45493966fde6e2da
scope.5.id=function:_last_turn_matches_player:66
scope.5.kind=function
scope.5.startLine=66
scope.5.endLine=71
scope.5.semanticHash=2d672133ee98c32b
scope.6.id=function:_notice_matches_player:73
scope.6.kind=function
scope.6.startLine=73
scope.6.endLine=75
scope.6.semanticHash=6e8016f64087a4ce
scope.7.id=function:_is_player_detained_this_turn:77
scope.7.kind=function
scope.7.startLine=77
scope.7.endLine=89
scope.7.semanticHash=3dad47680dac1cec
scope.8.id=function:_check_roadblock_status:91
scope.8.kind=function
scope.8.startLine=91
scope.8.endLine=100
scope.8.semanticHash=386e7705d39d2d3d
scope.9.id=function:_resolve_location_status:102
scope.9.kind=function
scope.9.startLine=102
scope.9.endLine=123
scope.9.semanticHash=ade397ddfe7c51c7
scope.10.id=function:_resolve_deity_status:125
scope.10.kind=function
scope.10.startLine=125
scope.10.endLine=134
scope.10.semanticHash=866b8e93e36ca58c
scope.11.id=function:_resolve_stay_turns_remaining:136
scope.11.kind=function
scope.11.startLine=136
scope.11.endLine=138
scope.11.semanticHash=40d58c056e45bd41
scope.12.id=function:_resolve_deity_remaining:140
scope.12.kind=function
scope.12.startLine=140
scope.12.endLine=151
scope.12.semanticHash=ee6de42734b468e6
scope.13.id=function:M.resolve_player_status_key:153
scope.13.kind=function
scope.13.startLine=153
scope.13.endLine=171
scope.13.semanticHash=107521a26c1f0ce5
scope.14.id=function:_resolve_remaining_value:173
scope.14.kind=function
scope.14.startLine=173
scope.14.endLine=181
scope.14.semanticHash=5b4f7a2f1ce89f5c
scope.15.id=function:_resolve_text_status_context:183
scope.15.kind=function
scope.15.startLine=183
scope.15.endLine=194
scope.15.semanticHash=4d52d1147716713d
]]
