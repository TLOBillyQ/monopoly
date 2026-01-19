local constants = require("src.config.constants")
local logger = require("src.util.logger")

local Effects = {}

local function get_bankruptcy(game)
  local bankruptcy = game and game.get_service and game:get_service("bankruptcy")
  if not bankruptcy then
    logger.warn("缺少 BankruptcyService，无法淘汰破产玩家")
    return nil
  end
  return bankruptcy
end

function Effects:apply_hospital_effects(game)
  game:set_player_status(self, "stay_turns", constants.hospital_stay_turns)

  local fee = constants.hospital_fee
  if self.cash < fee then
    logger.event(self.name .. " 资金不足，无法支付医药费 " .. fee)
    local bankruptcy = get_bankruptcy(game)
    if not bankruptcy then return end
    bankruptcy.eliminate(game, self)
    return
  end
  self:deduct_cash(fee)
  logger.event(self.name .. " 支付医药费 " .. fee)
  if self.cash <= 0 then
    local bankruptcy = get_bankruptcy(game)
    if not bankruptcy then return end
    bankruptcy.eliminate(game, self)
    return
  end

  logger.event(self.name .. " 住院，需停留 " .. self.status.stay_turns .. " 回合")
end

function Effects:send_to_hospital(game)
  local hospital_index = game.board:find_first_by_type("hospital")
  if hospital_index then
    game:update_player_position(self, hospital_index)
  end
  game:set_player_status(self, "move_dir", nil)
  self:apply_hospital_effects(game)
end

function Effects:apply_mountain_effects(game)
  game:set_player_status(self, "stay_turns", constants.mountain_stay_turns)
  logger.event(self.name .. " 进入深山，停留 " .. self.status.stay_turns .. " 回合")
end

function Effects:send_to_mountain(game)
  local idx = game.board:find_first_by_type("mountain")
  if idx then
    game:update_player_position(self, idx)
  end
  game:set_player_status(self, "move_dir", nil)
  self:apply_mountain_effects(game)
end

function Effects:is_in_mountain(game)
  local tile = game.board:get_tile(self.position)
  return tile and tile.type == "mountain"
end

return Effects
