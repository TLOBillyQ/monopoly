local constants = require("src.config.constants")
local logger = require("src.util.logger")

local StatusService = {}


function StatusService.has_angel(player)
  return player:has_deity("angel")
end


function StatusService.apply_deity(player, deity_type)
  player:set_deity(deity_type, constants.deity_duration_turns)
  logger.event(player.name .. " 获得附身：" .. deity_type)
end


function StatusService.tick_end_of_turn(player)
  player:tick_deity()
end


function StatusService.send_to_hospital(game, player, opts)
  opts = opts or {}
  local hospital_index = game.board:find_first_by_type("hospital")
  if hospital_index then
    game:update_player_position(player, hospital_index)
  end
  game:set_player_status(player, "stay_turns", constants.hospital_stay_turns)
  if not opts.skip_fee then
    local fee = constants.hospital_fee
    if player.cash < fee then
      local bankruptcy = game and game.services and game.services.bankruptcy
      if not bankruptcy then
        logger.warn("缺少 BankruptcyService，无法淘汰破产玩家")
        return
      end
      bankruptcy.eliminate(game, player)
      return
    end
    player:deduct_cash(fee)
    logger.event(player.name .. " 支付医药费 " .. fee)
  end
  logger.event(player.name .. " 住院，需停留 " .. player.status.stay_turns .. " 回合")
end


function StatusService.send_to_mountain(game, player)
  local idx = game.board:find_first_by_type("mountain")
  if idx then
    game:update_player_position(player, idx)
  end
  game:set_player_status(player, "stay_turns", constants.mountain_stay_turns)
  logger.event(player.name .. " 进入深山，停留 " .. player.status.stay_turns .. " 回合")
end


function StatusService.is_in_mountain(game, player)
  local tile = game.board:get_tile(player.position)
  return tile and tile.type == "mountain"
end

return StatusService
