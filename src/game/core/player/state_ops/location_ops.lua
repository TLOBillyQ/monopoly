local logger = require("src.core.utils.logger")
local bankruptcy_port = require("src.game.ports.bankruptcy_port")
local common = require("src.game.core.player.state_ops.common")
local number_utils = require("src.core.utils.number_utils")
local role_id_utils = require("src.core.utils.role_id")
local monopoly_event = require("src.core.events.monopoly_events")

local location_ops = {}

local function _emit_status_feedback(self, player, status_type, cue_name)
  local board = self and self.board or nil
  local tile = board and board.get_tile and board:get_tile(player.position) or nil
  monopoly_event.emit(monopoly_event.feedback.status_applied, {
    player = player,
    player_id = player and player.id or nil,
    status_type = status_type,
    cue_name = cue_name,
    tile_id = tile and tile.id or nil,
    tile_index = player and player.position or nil,
  })
end

function location_ops.player_apply_hospital_effects(self, player)
  self:set_player_status(player, "stay_turns", common.constants.hospital_stay_turns)
  local fee = common.constants.hospital_fee
  if self:player_balance(player, "金币") < fee then
    logger.event(player.name .. " 资金不足，无法支付医药费 " .. number_utils.format_integer_part(fee))
    bankruptcy_port.eliminate(self, player, { reason = player.name .. " 医药费不足破产" })
    return
  end
  self:deduct_player_cash(player, fee)
  logger.event(player.name .. " 支付医药费 " .. number_utils.format_integer_part(fee))
  if self:player_balance(player, "金币") <= 0 then
    bankruptcy_port.eliminate(self, player, { reason = player.name .. " 支付医药费后破产" })
    return
  end
  _emit_status_feedback(self, player, "hospital", "hospital_shock")
  logger.event(player.name .. " 住院，需停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function location_ops.player_send_to_hospital(self, player)
  local hospital_index = self.board:find_first_by_type("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  self:update_player_position(player, hospital_index)
  self:set_player_status(player, "move_dir", nil)
  self:player_apply_hospital_effects(player)
end

function location_ops.player_apply_mountain_effects(self, player)
  self:set_player_status(player, "stay_turns", common.constants.mountain_stay_turns)
  _emit_status_feedback(self, player, "mountain", "mountain_stun")
  logger.event(player.name .. " 进入深山，停留 " .. tostring(player.status.stay_turns) .. " 回合")
end

function location_ops.player_send_to_mountain(self, player)
  local idx = self.board:find_first_by_type("mountain")
  assert(idx ~= nil, "missing mountain tile")
  self:update_player_position(player, idx)
  self:set_player_status(player, "move_dir", nil)
  self:player_apply_mountain_effects(player)
end

function location_ops.player_is_in_mountain(self, player)
  local tile = self.board:get_tile(player.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(player.position))
  return tile.type == "mountain"
end

function location_ops.alive_players(self)
  local alive = {}
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      alive[#alive + 1] = player
    end
  end
  return alive
end

function location_ops.find_player_by_id(self, player_id)
  if player_id == nil then
    return nil
  end
  local normalized_id = role_id_utils.normalize(player_id)
  local by_id = self.player_by_id
  if type(by_id) == "table" then
    local cached = by_id[player_id]
    if not cached and normalized_id ~= nil then
      cached = by_id[normalized_id] or by_id[tostring(normalized_id)]
    end
    if cached then
      if normalized_id ~= nil then
        by_id[normalized_id] = cached
      end
      by_id[player_id] = cached
      return cached
    end
  end
  for _, player in ipairs(self.players or {}) do
    if player and role_id_utils.equals(player.id, normalized_id) then
      if type(by_id) == "table" then
        if normalized_id ~= nil then
          by_id[normalized_id] = player
        end
        by_id[player_id] = player
      end
      return player
    end
  end
  return nil
end

function location_ops.current_player(self)
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function location_ops.update_player_position(self, player, new_index)
  local old_index = player.position
  if old_index and self.occupants and self.occupants[old_index] then
    local list = self.occupants[old_index]
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  common.mark_players(self)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

return location_ops
