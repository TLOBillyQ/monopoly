local logger = require("src.core.Logger")
local constants = require("Config.Generated.Constants")
local board_utils = require("src.game.land.LandBoardUtils")
local inventory = require("src.game.item.ItemInventory")
local gameplay_rules = require("Config.GameplayRules")
local bankruptcy = require("src.game.game.Bankruptcy")

local item_effects = {}
local item_ids = gameplay_rules.item_ids

local target_item_order = {
  item_ids.share_wealth,
  item_ids.exile,
  item_ids.tax,
  item_ids.invite_deity,
  item_ids.send_poor,
  item_ids.poor,
}

local target_effects = {
  [item_ids.share_wealth] = {
    apply = function(game, user, target, _context)
      local total = game:player_balance(user, "金币") + game:player_balance(target, "金币")
      local half = math.floor(total / 2)
      game:set_player_cash(user, half)
      game:set_player_cash(target, total - half)
      logger.event(user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
      return true
    end,
  },
  [item_ids.exile] = {
    apply = function(game, user, target, context)
      local idx = game.board:find_first_by_type("mountain")
      local from_index = target.position
      if idx then
        game:update_player_position(target, idx)
        local ui_port = game.ui_port
        if ui_port and ui_port.wait_action_anim then
          game:queue_action_anim({
            kind = "move_effect",
            player_id = target.id,
            from_index = from_index,
            to_index = idx,
            focus_target_tile_index = idx,
          })
        end
      end
      game:set_player_status(target, "move_dir", nil)
      game:set_player_status(target, "stay_turns", constants.mountain_stay_turns)
      logger.event(target.name .. " 进入深山，停留 " .. target.status.stay_turns .. " 回合")
      logger.event(user.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
      return true
    end,
  },
  [item_ids.tax] = {
    apply = function(game, user, target, context)
      if game:player_has_deity(target, "angel") then
        logger.event(target.name .. " 有天使，查税无效")
        return true
      end
      local tax_free_idx = inventory.find_index(target, item_ids.tax_free)
      if tax_free_idx then
        inventory.remove_by_index(target, tax_free_idx)
        logger.event(target.name .. " 使用免税卡抵消查税")
        return true
      end
      local fee = math.floor(game:player_balance(target, "金币") * 0.5)
      game:deduct_player_cash(target, fee)
      logger.event(user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
      if game:player_balance(target, "金币") <= 0 then
        bankruptcy.eliminate(game, target)
      end
      return true
    end,
  },
  [item_ids.invite_deity] = {
    filter_target = function(_, _, target)
      return target.status.deity and true or false
    end,
    apply = function(game, user, target, _context)
      local deity = assert(target.status.deity, "missing target deity")
      game:clear_player_deity(target)
      game:set_player_deity(user, deity.type, deity.remaining)
      logger.event(user.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
      return true
    end,
  },
  [item_ids.send_poor] = {
    require_user = function(game, user)
      if not game:player_has_deity(user, "poor") then
        return false
      end
      return true
    end,
    apply = function(game, user, target, _context)
      local remaining = assert(user.status.deity, "missing user deity").remaining
      game:set_player_deity(target, "poor", remaining)
      game:clear_player_deity(user)
      logger.event(user.name .. " 使用送神卡，将穷神送给 " .. target.name)
      return true
    end,
  },
  [item_ids.poor] = {
    apply = function(game, user, target, _context)
      game:set_player_deity(target, "poor")
      logger.event(user.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
      return true
    end,
  },
}

local post_effects = {

  [item_ids.free_rent] = { type = "set_status", key = "pending_free_rent", value = true, message = " 使用免费卡，下一次租金免除" },
  [item_ids.dice_multiplier] = { type = "set_status", key = "pending_dice_multiplier", value = 2, message = " 使用骰子加倍卡，本次步数翻倍" },
  [item_ids.tax_free] = { type = "set_status", key = "pending_tax_free", value = true, message = " 使用免税卡，本次征税免除" },


  [item_ids.mine] = { type = "place_mine_here" },
  [item_ids.clear_obstacles] = { type = "clear_obstacles_ahead", distance = 12 },


  [item_ids.steal] = { type = "log", message = " 准备偷窃（将在经过玩家时触发）" },
  [item_ids.strong] = { type = "log", message = " 准备使用强征卡（踩他人地块时触发）" },


  [item_ids.rich] = { type = "deity", deity = "rich", warn = "附身财神", log = " 使用财神卡，财神附身" },
  [item_ids.angel] = { type = "deity", deity = "angel", warn = "附身天使", log = " 使用天使卡，天使附身" },
}

local handlers = {}

local function _handle_set_status(game, player, cfg, _context)
  local value = assert(cfg.value, "missing status value")
  game:set_player_status(player, cfg.key, value)
  if cfg.message then
    logger.event(player.name .. cfg.message)
  end
  return true
end

local function _handle_deity(game, player, cfg, context)
  game:set_player_deity(player, cfg.deity, constants.deity_duration_turns)
  logger.event(player.name .. " 获得附身：" .. cfg.deity)
  if cfg.log then
    logger.event(player.name .. cfg.log)
  end
  return true
end

local function _handle_log(_, player, cfg, _context)
  assert(cfg.message ~= nil, "missing log message")
  logger.event(player.name .. cfg.message)
  return true
end

local function _handle_place_mine_here(game, player, _cfg, context)
  game.board:place_mine(player.position)
  logger.event(player.name .. " 在脚下埋设地雷")
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "mine",
      player_id = player.id,
      tile_index = player.position,
      focus_target_tile_index = player.position,
    })
    return { ok = true, action_anim = true }
  end
  return true
end

local function _handle_clear_obstacles_ahead(game, player, cfg, context)
  local board = game.board
  local cleared = 0
  local cleared_indices = {}
  local cleared_map = {}
  local current = player.position
  local distance = cfg.distance or 12
  assert(context ~= nil, "missing context")
  local parity = context.branch_parity or distance
  local facing = player.status.move_dir
  local map = assert(board.map, "missing board.map")
  local neighbors = assert(map.neighbors, "missing board.map.neighbors")
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local start_tile = assert(board:get_tile(current), "missing start tile")
  local start_id = assert(start_tile.id, "missing start tile id")
  local queue = {}
  local visited = {}
  local function _mark(tile_id, dir, depth)
    visited[tile_id] = visited[tile_id] or {}
    local key = dir or ""
    local prev = visited[tile_id][key]
    if prev and prev <= depth then
      return false
    end
    visited[tile_id][key] = depth
    return true
  end
  _mark(start_id, facing, 0)
  table.insert(queue, { tile_id = start_id, facing = facing, depth = 0 })
  board_utils.queue_walk(queue, function(node, push)
    if node.depth < distance then
      local neigh = assert(neighbors[node.tile_id], "missing neighbors: " .. tostring(node.tile_id))
      local back = opposite[node.facing]
      for dir, next_id in pairs(neigh) do
        if not back or dir ~= back then
          local next_index = assert(board:index_of_tile_id(next_id), "missing tile index: " .. tostring(next_id))
          if board:has_roadblock(next_index) then
            board:clear_roadblock(next_index)
            cleared = cleared + 1
            if not cleared_map[next_index] then
              cleared_map[next_index] = true
              cleared_indices[#cleared_indices + 1] = next_index
            end
          end
          if board:has_mine(next_index) then
            board:clear_mine(next_index)
            cleared = cleared + 1
            if not cleared_map[next_index] then
              cleared_map[next_index] = true
              cleared_indices[#cleared_indices + 1] = next_index
            end
          end
          if _mark(next_id, dir, node.depth + 1) then
            push({ tile_id = next_id, facing = dir, depth = node.depth + 1 })
          end
        end
      end
    end
  end)
  logger.event(player.name .. " 清除前方障碍数：" .. cleared)
  assert(game.ui_port ~= nil, "missing ui_port")
  if game.ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = "clear_obstacles",
      player_id = player.id,
      cleared_indices = cleared_indices,
      focus_target_player_id = player.id,
    })
    return { ok = true, action_anim = true }
  end
  return true
end

handlers.set_status = _handle_set_status
handlers.deity = _handle_deity
handlers.log = _handle_log
handlers.place_mine_here = _handle_place_mine_here
handlers.clear_obstacles_ahead = _handle_clear_obstacles_ahead

function item_effects.get_target_spec(item_id)
  return target_effects[item_id]
end

function item_effects.target_item_ids()
  return target_item_order
end

function item_effects.apply_target(game, user, item_id, target, context)
  local spec = target_effects[item_id]
  assert(spec ~= nil and spec.apply ~= nil, "missing target spec: " .. tostring(item_id))
  return spec.apply(game, user, target, context)
end

function item_effects.apply_post(game, player, item_id, context)
  context = context or {}
  local cfg = assert(post_effects[item_id], "missing post effect: " .. tostring(item_id))
  local handler = assert(handlers[cfg.type], "missing post effect handler: " .. tostring(cfg.type))
  return handler(game, player, cfg, context)
end

return item_effects
