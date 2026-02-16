local constants = require("cfg.Generated.Constants")
local logger = require("core.logger")
local player_state = require("game.state.player")

local hospital = {}

function hospital.player_apply_hospital_effects(self, player_obj)
  player_state.set_player_status(self, player_obj, "stay_turns", constants.hospital_stay_turns)
  local fee = constants.hospital_fee
  if player_state.player_balance(self, player_obj, "金币") < fee then
    logger.event(player_obj.name .. " 资金不足，无法支付医药费 " .. fee)
    local bankrupt = require("game.rule.bankrupt")
    bankrupt.eliminate(self, player_obj, { reason = player_obj.name .. " 医药费不足破产" })
    return
  end
  player_state.deduct_player_cash(self, player_obj, fee)
  logger.event(player_obj.name .. " 支付医药费 " .. fee)
  if player_state.player_balance(self, player_obj, "金币") <= 0 then
    local bankrupt = require("game.rule.bankrupt")
    bankrupt.eliminate(self, player_obj, { reason = player_obj.name .. " 支付医药费后破产" })
    return
  end
  logger.event(player_obj.name .. " 住院，需停留 " .. tostring(player_obj.status.stay_turns) .. " 回合")
end

function hospital.player_send_to_hospital(self, player_obj)
  local hospital_index = self.board:find_first_by_type("hospital")
  assert(hospital_index ~= nil, "missing hospital tile")
  player_state.update_player_position(self, player_obj, hospital_index)
  player_state.set_player_status(self, player_obj, "move_dir", nil)
  hospital.player_apply_hospital_effects(self, player_obj)
end

function hospital.player_apply_mountain_effects(self, player_obj)
  player_state.set_player_status(self, player_obj, "stay_turns", constants.mountain_stay_turns)
  logger.event(player_obj.name .. " 进入深山，停留 " .. tostring(player_obj.status.stay_turns) .. " 回合")
end

function hospital.player_send_to_mountain(self, player_obj)
  local idx = self.board:find_first_by_type("mountain")
  assert(idx ~= nil, "missing mountain tile")
  player_state.update_player_position(self, player_obj, idx)
  player_state.set_player_status(self, player_obj, "move_dir", nil)
  hospital.player_apply_mountain_effects(self, player_obj)
end

function hospital.player_is_in_mountain(self, player_obj)
  local tile = self.board:get_tile(player_obj.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(player_obj.position))
  return tile.type == "mountain"
end

return hospital
