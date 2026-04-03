local specs = require("src.ui.render.status3d.specs")
local scene = require("src.ui.render.status3d.scene")
local host_runtime_bridge = require("src.ui.host_bridge")

local M = {}

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

local function _resolve_role(player_id, deps)
  local host_runtime = deps and deps.host_runtime or host_runtime_bridge
  assert(host_runtime ~= nil, "missing deps.host_runtime")
  return host_runtime.resolve_role_with(player_id, function(role)
    return role.set_label_text ~= nil
  end)
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
  if _check_roadblock_status(last_turn, player) and _has_pending_roadblock_trigger(game, player) then
    return "roadblock"
  end
  local location = _resolve_location_status(game, player, status)
  if location then
    return location
  end
  if _check_roadblock_status(last_turn, player) then
    return "roadblock"
  end
  return _resolve_deity_status(status)
end

local function _resolve_text_status_context(cache, player, status_key)
  if not specs.text_statuses[status_key] then
    return nil, nil
  end
  local stay_turns = player.status and player.status.stay_turns or 0
  local text_node = cache.text_nodes[player.id] and cache.text_nodes[player.id][status_key]
  if stay_turns <= 0 or text_node == nil then
    return nil, nil
  end
  return stay_turns, text_node
end

local function _sync_text_status(cache, player, status_key, deps)
  local stay_turns, text_node = _resolve_text_status_context(cache, player, status_key)
  if stay_turns == nil then
    return
  end
  local role = _resolve_role(player.id, deps)
  if role and role.set_label_text then
    local text = "当前回合无法行动\n剩余停留回合数：" .. tostring(stay_turns)
    pcall(role.set_label_text, text_node, text)
  end
end

function M.sync_layer_status(cache, player, status_key, deps)
  local player_id = player.id
  local player_layers = cache.layers[player_id]
  if not player_layers then
    return
  end
  if cache.last_status_key_by_player[player_id] == status_key then
    _sync_text_status(cache, player, status_key, deps)
    return
  end
  local roles = scene.resolve_observer_roles()
  for _, key in ipairs(specs.status_priority) do
    local layer = player_layers[key]
    if layer then
      scene.set_layer_visible_for_roles(layer, roles, status_key == key, deps, {
        player_id = player_id,
        status_key = key,
      })
    end
  end
  _sync_text_status(cache, player, status_key, deps)
  cache.last_status_key_by_player[player_id] = status_key
end

M._M_test = {
  _has_pending_roadblock_trigger = _has_pending_roadblock_trigger,
}

return M
