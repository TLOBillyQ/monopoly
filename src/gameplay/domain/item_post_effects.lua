local constants = require("src.config.constants")
local logger = require("src.util.logger")
local UI = require("src.gameplay.ports.ui_port")
local Services = require("src.util.services")

local PostEffects = {}

local function ensure_status(game, action)
  local status = Services.status(game)
  if not status then
    logger.warn("缺少 StatusService，无法" .. action)
  end
  return status
end



local EFFECTS = {
  
  [2001] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [2002] = { type = "remote_dice_max" },
  [2003] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [2010] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },

  
  [2004] = { type = "place_roadblock_ahead", distance = 3 },
  [2005] = { type = "place_mine_here" },
  [2006] = { type = "clear_obstacles_ahead", distance = 12 },

  
  [2007] = { type = "log", message = " 准备偷窃（将在经过玩家时触发）" },
  [2009] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },

  
  [2017] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [2019] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
}

local handlers = {}

handlers.set_status = function(game, player, cfg, _context)
  local value = cfg.value
  if value == nil then
    value = true
  end
  game:set_player_status(player, cfg.key, value)
  if cfg.message then
    logger.event(player.name .. cfg.message)
  end
  return true
end

handlers.remote_dice_max = function(game, player, _cfg, _context)
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  local values = {}
  for i = 1, dice_count do
    values[i] = 6
  end
  game:set_player_status(player, "pending_remote_dice", { values = values })
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

handlers.deity = function(game, player, cfg, _context)
  local status = ensure_status(game, cfg.warn or "附身")
  if not status then
    return false
  end
  status.apply_deity(player, cfg.deity)
  if cfg.log then
    logger.event(player.name .. cfg.log)
  end
  return true
end

handlers.log = function(_, player, cfg, _context)
  if cfg.message then
    logger.event(player.name .. cfg.message)
  end
  return true
end

handlers.place_roadblock_ahead = function(game, player, cfg, _context)
  local board = game.board
  local current = player.position
  local parity = 1
  local facing = player.status and player.status.move_dir or nil
  local distance = cfg.distance or 3
  for _ = 1, distance do
    local next_index, _passed, step_dir = board:step_forward_by_facing(current, facing, parity)
    current = next_index
    facing = step_dir or facing
    if not game.overlays.roadblocks[current] and not game.overlays.mines[current] then
      game.overlays.roadblocks[current] = true
      logger.event(player.name .. " 放置路障在 " .. board:get_tile(current).name)
      UI.push_popup(game, { title = "放置路障", body = player.name .. " 在 " .. board:get_tile(current).name .. " 设置了路障" })
      return true
    end
  end
  logger.warn("未找到可放置路障的位置")
  return false
end

handlers.place_mine_here = function(game, player, _cfg, _context)
  game.overlays.mines[player.position] = true
  logger.event(player.name .. " 在脚下埋设地雷")
  UI.push_popup(game, { title = "埋设地雷", body = player.name .. " 在脚下埋设了地雷" })
  return true
end

handlers.clear_obstacles_ahead = function(game, player, cfg, _context)
  local board = game.board
  local cleared = 0
  local current = player.position
  local parity = 1
  local facing = player.status and player.status.move_dir or nil
  local distance = cfg.distance or 12
  for _ = 1, distance do
    local next_index, _passed, step_dir = board:step_forward_by_facing(current, facing, parity)
    current = next_index
    facing = step_dir or facing
    if game.overlays.roadblocks[current] then
      game.overlays.roadblocks[current] = nil
      cleared = cleared + 1
    end
    if game.overlays.mines[current] then
      game.overlays.mines[current] = nil
      cleared = cleared + 1
    end
  end
  logger.event(player.name .. " 清除前方障碍数：" .. cleared)
  return true
end

function PostEffects.apply(game, player, item_id, context)
  local cfg = EFFECTS[item_id]
  if not cfg then
    return nil
  end
  local handler = handlers[cfg.type]
  if not handler then
    logger.warn("未实现的道具后置效果类型:" .. tostring(cfg.type) .. " item=" .. tostring(item_id))
    return false
  end
  return handler(game, player, cfg, context)
end

return PostEffects
