local constants = require("src.config.constants")
local Dice = require("src.core.dice")
local MovementService = require("src.services.movement_service")
local TileService = require("src.services.tile_service")
local StatusService = require("src.services.status_service")
local ItemService = require("src.services.item_service")
local logger = require("src.services.logger")

local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager.new(game)
  math.randomseed(os.time())
  local tm = {
    game = game,
  }
  return setmetatable(tm, TurnManager)
end

function TurnManager:run_turn()
  local player = self.game:current_player()
  if player.eliminated then
    return self:next_player()
  end

  -- 停留状态判定
  if player.status.stay_turns and player.status.stay_turns > 0 then
    player.status.stay_turns = player.status.stay_turns - 1
    logger.event(player.name .. " 被扣留，剩余回合:", player.status.stay_turns)
    return self:end_turn(player)
  end

  -- 行动前道具（自动）
  ItemService.auto_pre_action(self.game, player)

  -- 投骰子
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  local override = nil
  if player.status.pending_remote_dice then
    override = player.status.pending_remote_dice.values
  end
  local rolls, total = Dice.roll(dice_count, override)

  if player.status.pending_dice_multiplier and player.status.pending_dice_multiplier > 1 then
    total = total * player.status.pending_dice_multiplier
  end
  logger.event(player.name .. " 投骰: [" .. table.concat(rolls, ",") .. "] => " .. total)

  -- 移动
  local move_result = MovementService.move(self.game, player, total)

  -- 结算格子
  local tile = self.game.board:get_tile(player.position)
  TileService.resolve(self.game, player, tile, move_result)

  if player.eliminated then
    return self:next_player()
  end

  -- 回合结束处理
  return self:end_turn(player)
end

function TurnManager:end_turn(player)
  StatusService.tick_end_of_turn(player)
  player:clear_temporal_flags()
  self:next_player()
end

function TurnManager:next_player()
  local count = #self.game.players
  local next_index = self.game.current_player_index % count + 1
  self.game.current_player_index = next_index
end

return TurnManager
