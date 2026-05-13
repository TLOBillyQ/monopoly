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

local function _has_pending_roadblock_trigger(game, player)
  if not (game and game.turn and player and player.id ~= nil) then
    return false
  end
  local current = game.turn.action_anim
  if current
      and current.kind == "roadblock_trigger"
      and current.player_id == player.id then
    return true
  end
  local queue = game.turn.action_anim_queue
  if type(queue) ~= "table" then
    return false
  end
  for _, entry in ipairs(queue) do
    if entry
        and entry.kind == "roadblock_trigger"
        and entry.player_id == player.id then
      return true
    end
  end
  return false
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

local function _is_player_detained_this_turn(game, player)
  if game == nil or player == nil then
    return false
  end
  local turn = game.turn
  if not turn then
    return false
  end
  local notice_active = turn.no_action_notice_active == true
  local detained_active = turn.detained_wait_active == true or turn.phase == "detained_wait"
  if not (notice_active or detained_active) then
    return false
  end
  local last_turn = game.last_turn
  if not last_turn then
    return false
  end
  if last_turn.player_id ~= player.id then
    return false
  end
  if last_turn.skipped ~= true then
    return false
  end
  if notice_active and turn.no_action_notice_player_id ~= player.id then
    return false
  end
  return last_turn.stay_turns ~= nil
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

local function _resolve_remaining_value(player, remaining_field)
  if remaining_field == "stay_turns" then
    return player.status and player.status.stay_turns or 0
  end
  if remaining_field == "deity_remaining" then
    local deity = player.status and player.status.deity
    if not deity then return 0 end
    local remaining = deity.remaining or 0
    local cap = player.deity_duration_turns
    if cap and remaining > cap then return cap end
    return remaining
  end
  return 0
end

local function _resolve_text_status_context(cache, player, status_key)
  local spec = specs.status_specs[status_key]
  if not (spec and spec.text_node_name) then
    return nil, nil
  end
  local remaining = _resolve_remaining_value(player, spec.remaining_field)
  local text_node = cache.text_nodes[player.id] and cache.text_nodes[player.id][status_key]
  if remaining <= 0 or text_node == nil then
    return nil, nil
  end
  return remaining, text_node
end

local function _sync_text_status(cache, player, status_key, roles)
  local remaining, text_node = _resolve_text_status_context(cache, player, status_key)
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

function M.sync_layer_status(cache, player, status_key, deps)
  local player_id = player.id
  local player_layers = cache.layers[player_id]
  if not player_layers then
    return
  end
  local roles = scene.resolve_observer_roles()
  if cache.last_status_key_by_player[player_id] == status_key then
    _sync_text_status(cache, player, status_key, roles)
    return
  end
  for _, key in ipairs(specs.status_priority) do
    local layer = player_layers[key]
    if layer then
      scene.set_layer_visible_for_roles(layer, roles, status_key == key, deps)
    end
  end
  _sync_text_status(cache, player, status_key, roles)
  cache.last_status_key_by_player[player_id] = status_key
end

M._M_test = {
  _has_pending_roadblock_trigger = _has_pending_roadblock_trigger,
}

return M
