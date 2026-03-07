local specs = require("src.presentation.render.status3d_service.specs")
local scene = require("src.presentation.render.status3d_service.scene")
local host_runtime = require("src.presentation.adapter.HostRuntimePort")

local M = {}

local function _resolve_role(player_id)
  return host_runtime.resolve_role_with(player_id, function(role)
    return role.set_label_text ~= nil
  end)
end

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

function M.resolve_player_status_key(game, player)
  if player == nil or player.eliminated == true then
    return nil
  end
  local status = player.status or {}
  local stay_turns = status.stay_turns or 0
  local detained_this_turn = _is_player_detained_this_turn(game, player)
  if (stay_turns > 0 or detained_this_turn) and game.board and game.board.get_tile then
    local tile = game.board:get_tile(player.position)
    local tile_type = tile and tile.type or nil
    if tile_type == "hospital" then
      return "hospital"
    end
    if tile_type == "mountain" then
      return "mountain"
    end
  end
  local last_turn = game.last_turn
  if last_turn and last_turn.player_id == player.id then
    local move_result = last_turn.move_result
    if move_result and move_result.stopped_on_roadblock == true then
      return "roadblock"
    end
  end
  local deity = status.deity
  if deity and (deity.remaining or 0) > 0 then
    if deity.type == "poor" then
      return "poor"
    end
    if deity.type == "rich" then
      return "rich"
    end
    if deity.type == "angel" then
      return "angel"
    end
  end
  return nil
end

function M.sync_layer_status(cache, player, status_key)
  local player_id = player.id
  local player_layers = cache.layers[player_id]
  if not player_layers then
    return
  end
  if cache.last_status_key_by_player[player_id] == status_key then
    if specs.text_statuses[status_key] then
      local stay_turns = player.status and player.status.stay_turns or 0
      local text_node = cache.text_nodes[player_id] and cache.text_nodes[player_id][status_key]
      if stay_turns > 0 and text_node then
        local role = _resolve_role(player_id)
        if role and role.set_label_text then
          local text = "当前回合无法行动\n剩余停留回合数：" .. tostring(stay_turns)
          pcall(role.set_label_text, text_node, text)
        end
      end
    end
    return
  end
  local roles = scene.resolve_observer_roles()
  for _, key in ipairs(specs.status_priority) do
    local layer = player_layers[key]
    if layer then
      scene.set_layer_visible_for_roles(layer, roles, status_key == key)
    end
  end
  if specs.text_statuses[status_key] then
    local stay_turns = player.status and player.status.stay_turns or 0
    local text_node = cache.text_nodes[player_id] and cache.text_nodes[player_id][status_key]
    if stay_turns > 0 and text_node then
      local role = _resolve_role(player_id)
      if role and role.set_label_text then
        local text = "当前回合无法行动\n剩余停留回合数：" .. tostring(stay_turns)
        pcall(role.set_label_text, text_node, text)
      end
    end
  end
  cache.last_status_key_by_player[player_id] = status_key
end

return M
