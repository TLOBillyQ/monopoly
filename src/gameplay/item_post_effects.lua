local logger = require("src.util.logger")
local constants = require("src.config.constants")
local BoardUtils = require("src.gameplay.item_board_utils")
local Inventory = require("src.gameplay.item_inventory")
local gameplay_constants = require("src.gameplay.constants")

local ItemEffects = {}
local ITEM_IDS = gameplay_constants.item_ids

local TARGET_ITEM_ORDER = {
  ITEM_IDS.share_wealth,
  ITEM_IDS.exile,
  ITEM_IDS.tax,
  ITEM_IDS.invite_deity,
  ITEM_IDS.send_poor,
  ITEM_IDS.poor,
}

local TARGET_EFFECTS = {
  [ITEM_IDS.share_wealth] = {
    apply = function(_, user, target, _context)
      local total = user.cash + target.cash
      local half = math.floor(total / 2)
      user:set_cash(half)
      target:set_cash(total - half)
      logger.event(user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
      return true
    end,
  },
  [ITEM_IDS.exile] = {
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
  [ITEM_IDS.tax] = {
    apply = function(game, user, target, context)
      if target:has_deity("angel") then
        logger.event(target.name .. " 有天使，查税无效")
        return true
      end
      if Inventory.consume(target, ITEM_IDS.tax_free) then
        logger.event(target.name .. " 使用免税卡抵消查税")
        return true
      end
      local fee = math.floor(target.cash * 0.5)
      target:deduct_cash(fee)
      logger.event(user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
      if target.cash <= 0 then
        local bankruptcy = game and game.get_service and game:get_service("bankruptcy")
        if bankruptcy then
          bankruptcy.eliminate(game, target)
        end
      end
      return true
    end,
  },
  [ITEM_IDS.invite_deity] = {
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
  [ITEM_IDS.send_poor] = {
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
  [ITEM_IDS.poor] = {
    apply = function(_, user, target, _context)
      target:set_deity("poor")
      logger.event(user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
      return true
    end,
  },
}

local POST_EFFECTS = {

  [ITEM_IDS.free_rent] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [ITEM_IDS.dice_multiplier] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [ITEM_IDS.tax_free] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },


  [ITEM_IDS.mine] = { type = "place_mine_here" },
  [ITEM_IDS.clear_obstacles] = { type = "clear_obstacles_ahead", distance = 12 },


  [ITEM_IDS.steal] = { type = "log", message = " 准备偷窃（将在经过玩家时触发）" },
  [ITEM_IDS.strong] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },


  [ITEM_IDS.rich] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [ITEM_IDS.angel] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
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
  local distance = cfg.distance or 12
  local parity = (context and context.branch_parity) or distance
  local facing = player.status and player.status.move_dir or nil
  local map = board.map
  if not map or not map.neighbors then
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
  else
    local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }
    local start_tile = board:get_tile(current)
    local start_id = start_tile and start_tile.id
    local queue = {}
    local visited = {}
    local function mark(tile_id, dir, depth)
      visited[tile_id] = visited[tile_id] or {}
      local key = dir or ""
      local prev = visited[tile_id][key]
      if prev and prev <= depth then
        return false
      end
      visited[tile_id][key] = depth
      return true
    end
    if start_id then
      mark(start_id, facing, 0)
      table.insert(queue, { tile_id = start_id, facing = facing, depth = 0 })
    end
    BoardUtils.queue_walk(queue, function(node, push)
      if node.depth < distance then
        local neigh = map.neighbors[node.tile_id] or {}
        local back = node.facing and OPPOSITE[node.facing] or nil
        for dir, next_id in pairs(neigh) do
          if not back or dir ~= back then
            local next_index = board:index_of_tile_id(next_id)
            if next_index then
              if board:has_roadblock(next_index) then
                board:clear_roadblock(next_index)
                cleared = cleared + 1
              end
              if board:has_mine(next_index) then
                board:clear_mine(next_index)
                cleared = cleared + 1
              end
              if mark(next_id, dir, node.depth + 1) then
                push({ tile_id = next_id, facing = dir, depth = node.depth + 1 })
              end
            end
          end
        end
      end
    end)
  end
  logger.event(player.name .. " 清除前方障碍数：" .. cleared)
  return true
end

function ItemEffects.get_target_spec(item_id)
  return TARGET_EFFECTS[item_id]
end

function ItemEffects.target_item_ids()
  return TARGET_ITEM_ORDER
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
  context.services = context.services or (game and game.get_services and game:get_services())
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
