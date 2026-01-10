local constants = require("src.config.constants")
local items_cfg = require("src.config.items")
local random = require("src.util.random")
local StatusService = require("src.services.status_service")
local BankruptcyService = require("src.services.bankruptcy_service")
local logger = require("src.services.logger")

local ItemService = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local function find_item_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

local function consume(player, item_id)
  local idx = find_item_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

function ItemService.draw_random_item()
  return random.weighted_choice(items_cfg, "weight")
end

function ItemService.give_item(player, item_id)
  if player.inventory:is_full() then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    return false
  end
  player.inventory:add({ id = item_id })
  logger.event(player.name .. " 获得道具 " .. (cfg_by_id[item_id] and cfg_by_id[item_id].name or tostring(item_id)))
  return true
end

function ItemService.draw_and_give(player)
  local cfg = ItemService.draw_random_item()
  if not cfg then
    return
  end
  ItemService.give_item(player, cfg.id)
end

function ItemService.auto_pre_action(game, player)
  -- 清障卡：若前方 12 格有障碍则使用
  if find_item_index(player, 2006) then
    if ItemService.has_obstacles_ahead(game, player, 12) then
      ItemService.use_item(game, player, 2006)
    end
  end

  -- 遥控骰子：自动设为最高点数
  if find_item_index(player, 2002) then
    ItemService.use_item(game, player, 2002)
  end

  -- 骰子加倍：有就用
  if find_item_index(player, 2003) then
    ItemService.use_item(game, player, 2003)
  end

  -- 路障：自动放置前方 3 格内最近空位
  if find_item_index(player, 2004) then
    ItemService.use_item(game, player, 2004)
  end

  -- 财神/天使/穷神：优先自用财神/天使
  if find_item_index(player, 2017) then
    ItemService.use_item(game, player, 2017)
  elseif find_item_index(player, 2019) then
    ItemService.use_item(game, player, 2019)
  end
end

function ItemService.has_obstacles_ahead(game, player, distance)
  local board = game.board
  local parity = 1
  local current = player.position
  for _ = 1, distance do
    local next_index = board:advance(current, 1, parity)
    current = next_index
    if game.overlays.roadblocks[current] or game.overlays.mines[current] then
      return true
    end
  end
  return false
end

function ItemService.use_item(game, player, item_id, context)
  local cfg = cfg_by_id[item_id]
  if not cfg then
    return false
  end
  local ok = consume(player, item_id)
  if not ok then
    return false
  end

  if item_id == 2001 then
    player.status.pending_free_rent = true
    logger.event(player.name .. " 使用免费卡，下一次租金免除")
  elseif item_id == 2002 then
    local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
    local values = {}
    for i = 1, dice_count do
      values[i] = 6
    end
    player.status.pending_remote_dice = { values = values }
    logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  elseif item_id == 2003 then
    player.status.pending_dice_multiplier = 2
    logger.event(player.name .. " 使用骰子加倍卡，本次步数翻倍")
  elseif item_id == 2004 then
    ItemService.place_roadblock(game, player)
  elseif item_id == 2005 then
    game.overlays.mines[player.position] = true
    logger.event(player.name .. " 在脚下埋设地雷")
  elseif item_id == 2006 then
    ItemService.clear_obstacles(game, player, 12)
  elseif item_id == 2007 then
    -- 偷窃在经过时处理
    logger.event(player.name .. " 准备偷窃（将在经过玩家时触发）")
  elseif item_id == 2008 then
    logger.warn("怪兽卡效果尚未实现")
  elseif item_id == 2009 then
    logger.event(player.name .. " 准备使用强征卡（踩他人地块时触发）")
  elseif item_id == 2010 then
    player.status.pending_tax_free = true
    logger.event(player.name .. " 使用免税卡，本次征税免除")
  elseif item_id == 2011 then
    ItemService.use_wealth_share(game, player)
  elseif item_id == 2012 then
    ItemService.use_exile(game, player)
  elseif item_id == 2013 then
    logger.warn("导弹卡效果尚未实现")
  elseif item_id == 2014 then
    ItemService.use_audit(game, player)
  elseif item_id == 2015 then
    ItemService.use_invite_god(game, player)
  elseif item_id == 2016 then
    ItemService.use_send_poor_god(game, player)
  elseif item_id == 2017 then
    StatusService.apply_deity(player, "rich")
  elseif item_id == 2018 then
    ItemService.use_poor_god(game, player)
  elseif item_id == 2019 then
    StatusService.apply_deity(player, "angel")
  end
  return true
end

function ItemService.place_roadblock(game, player)
  local board = game.board
  local current = player.position
  local parity = 1
  for _ = 1, 3 do
    local next_index = board:advance(current, 1, parity)
    current = next_index
    if not game.overlays.roadblocks[current] and not game.overlays.mines[current] then
      game.overlays.roadblocks[current] = true
      logger.event(player.name .. " 放置路障在 " .. board:get_tile(current).name)
      return
    end
  end
  logger.warn("未找到可放置路障的位置")
end

function ItemService.clear_obstacles(game, player, distance)
  local board = game.board
  local cleared = 0
  local current = player.position
  local parity = 1
  for _ = 1, distance do
    local next_index = board:advance(current, 1, parity)
    current = next_index
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
end

function ItemService.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  local has_steal = find_item_index(player, 2007)
  if not has_steal then
    return
  end
  for _, target_id in ipairs(encountered_ids) do
    local target = game.players[target_id]
    if target and not StatusService.has_angel(target) then
      local stolen = ItemService.steal_first_item(player, target)
      if stolen then
        consume(player, 2007)
        logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. (cfg_by_id[stolen.id] and cfg_by_id[stolen.id].name or stolen.id))
        break
      end
    end
  end
end

function ItemService.steal_first_item(player, target)
  if target.inventory:count() == 0 then
    logger.warn(target.name .. " 没有可偷道具")
    return nil
  end
  local stolen = target.inventory:remove_by_index(1)
  if player.inventory:is_full() then
    logger.warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  player.inventory:add(stolen)
  return stolen
end

function ItemService.use_wealth_share(game, player)
  local target = ItemService.richest_other(game, player)
  if not target then
    return
  end
  local total = player.cash + target.cash
  local half = math.floor(total / 2)
  player.cash = half
  target.cash = total - half
  logger.event(player.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
end

function ItemService.use_exile(game, player)
  local target = ItemService.richest_other(game, player)
  if not target then
    return
  end
  StatusService.send_to_mountain(game, target)
  logger.event(player.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
end

function ItemService.use_audit(game, player)
  local target = ItemService.richest_other(game, player)
  if not target then
    return
  end
  if StatusService.has_angel(target) then
    logger.event(target.name .. " 有天使，查税无效")
    return
  end
  local tax_free = find_item_index(target, 2010)
  if tax_free then
    target.inventory:remove_by_index(tax_free)
    logger.event(target.name .. " 使用免税卡抵消查税")
    return
  end
  local fee = math.floor(target.cash * 0.5)
  target:deduct_cash(fee)
  logger.event(player.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
  if target.cash < 0 then
    BankruptcyService.eliminate(game, target)
  end
end

function ItemService.use_invite_god(game, player)
  local target = ItemService.richest_other(game, player)
  if not target or not target.status.deity then
    logger.warn("没有可请的神")
    return
  end
  local deity = target.status.deity
  target:set_deity(nil)
  player:set_deity(deity.type, deity.remaining)
  logger.event(player.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
end

function ItemService.use_send_poor_god(game, player)
  if not player:has_deity("poor") then
    logger.warn("未附身穷神，无法送神")
    return
  end
  local target = ItemService.richest_other(game, player)
  if not target then
    return
  end
  target:set_deity("poor", player.status.deity.remaining)
  player:set_deity(nil)
  logger.event(player.name .. " 使用送神卡，将穷神送给 " .. target.name)
end

function ItemService.use_poor_god(game, player)
  local target = ItemService.richest_other(game, player)
  if not target then
    return
  end
  target:set_deity("poor")
  logger.event(player.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
end

function ItemService.richest_other(game, player)
  local richest = nil
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated then
      if not richest or p.cash > richest.cash then
        richest = p
      end
    end
  end
  return richest
end

return ItemService
