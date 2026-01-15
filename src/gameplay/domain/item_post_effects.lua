local logger = require("src.util.logger")
local constants = require("src.config.constants")

local ItemEffects = {}

local TARGET_EFFECTS = {
  [2011] = {
    apply = function(_, user, target, _context)
      local total = user.cash + target.cash
      local half = math.floor(total / 2)
      user:set_cash(half)
      target:set_cash(total - half)
      logger.event(user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
      return true
    end,
  },
  [2012] = {
    apply = function(game, user, target, context)
      local idx = game.board:find_first_by_type("mountain")
      if idx then
        game:update_player_position(target, idx)
      end
      game:set_player_status(target, "move_dir", nil)
      game:set_player_status(target, "stay_turns", constants.mountain_stay_turns)
      logger.event(target.name .. " 进入深山，停留 " .. target.status.stay_turns .. " 回合")
      logger.event(user.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
      return true
    end,
  },
  [2014] = {
    apply = function(game, user, target, context)
      if target:has_deity("angel") then
        logger.event(target.name .. " 有天使，查税无效")
        return true
      end
      local tax_free = target.inventory:find_index(function(it) return it.id == 2010 end)
      if tax_free then
        target.inventory:remove_by_index(tax_free)
        logger.event(target.name .. " 使用免税卡抵消查税")
        return true
      end
      local fee = math.floor(target.cash * 0.5)
      target:deduct_cash(fee)
      logger.event(user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
      if target.cash < 0 then
        local bankruptcy = (game.services and game.services.bankruptcy)
        if bankruptcy then
          bankruptcy.eliminate(game, target)
        end
      end
      return true
    end,
  },
  [2015] = {
    filter_target = function(_, _, target)
      return target.status.deity ~= nil
    end,
    apply = function(_, user, target, _context)
      if not target.status.deity then
        logger.warn("没有可请的神")
        return false
      end
      local deity = target.status.deity
      target:set_deity(nil)
      user:set_deity(deity.type, deity.remaining)
      logger.event(user.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
      return true
    end,
  },
  [2016] = {
    require_user = function(user)
      if not user:has_deity("poor") then
        return false
      end
      return true
    end,
    apply = function(_, user, target, _context)
      local remaining = user.status.deity and user.status.deity.remaining or nil
      target:set_deity("poor", remaining)
      user:set_deity(nil)
      logger.event(user.name .. " 使用送神卡，将穷神送给 " .. target.name)
      return true
    end,
  },
  [2018] = {
    apply = function(_, user, target, _context)
      target:set_deity("poor")
      logger.event(user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
      return true
    end,
  },
}

local POST_EFFECTS = {
  
  [2001] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [2003] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [2010] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },

  
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

handlers.deity = function(game, player, cfg, context)
  player:set_deity(cfg.deity, constants.deity_duration_turns)
  logger.event(player.name .. " 获得附身：" .. cfg.deity)
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

handlers.place_mine_here = function(game, player, _cfg, context)
  game.board:place_mine(player.position)
  logger.event(player.name .. " 在脚下埋设地雷")
  return {
    ok = true,
    intent = { kind = "push_popup", payload = { title = "埋设地雷", body = player.name .. " 在脚下埋设了地雷" } },
  }
end

handlers.clear_obstacles_ahead = function(game, player, cfg, context)
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
    if board:has_roadblock(current) then
      board:clear_roadblock(current)
      cleared = cleared + 1
    end
    if board:has_mine(current) then
      board:clear_mine(current)
      cleared = cleared + 1
    end
  end
  logger.event(player.name .. " 清除前方障碍数：" .. cleared)
  return true
end

function ItemEffects.get_target_spec(item_id)
  return TARGET_EFFECTS[item_id]
end

function ItemEffects.apply_target(game, user, item_id, target, context)
  local spec = TARGET_EFFECTS[item_id]
  if not spec or not spec.apply then
    return false
  end
  return spec.apply(game, user, target, context)
end

function ItemEffects.apply_post(game, player, item_id, context)
  context = context or {}
  context.services = context.services or (game and game.services)
  local cfg = POST_EFFECTS[item_id]
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

return ItemEffects
