local constants = require("src.config.constants")
local items_cfg = require("src.config.items")
local random = require("src.util.random")
local Choice = require("src.gameplay.choice")
local StatusService = require("src.gameplay.services.status_service")
local BankruptcyService = require("src.gameplay.services.bankruptcy_service")
local logger = require("src.gameplay.services.logger")

local ItemService = {}
local find_missile_target -- forward declare

local function push_popup(game, title, body)
  if game and game.ui_hooks and game.ui_hooks.push_popup then
    game.ui_hooks.push_popup({ title = title, body = body })
  end
end

local function request_choice(game, title, candidates, on_select, body_lines)
  if not game or not game.ui_hooks or not game.ui_hooks.request_choice then
    return nil
  end
  game.ui_hooks.request_choice({
    title = title,
    candidates = candidates,
    body_lines = body_lines,
    on_select = on_select,
  })
  return true
end

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

function ItemService.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  return (cfg and cfg.name) or tostring(item_id)
end

local function find_item_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

local function consume_item(player, item_id)
  local idx = find_item_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

ItemService.consume_item = consume_item

function ItemService.draw_random_item(rng)
  return random.weighted_choice(items_cfg, "weight", rng)
end

function ItemService.give_item(player, item_id)
  if player.inventory:is_full() then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    return false
  end
  player.inventory:add({ id = item_id })
  logger.event(player.name .. " 获得道具 " .. ItemService.item_name(item_id))
  return true
end

function ItemService.draw_and_give(player, rng)
  local cfg = ItemService.draw_random_item(rng)
  if not cfg then
    return
  end
  ItemService.give_item(player, cfg.id)
end

function ItemService.auto_pre_action(game, player)
  -- 清障卡：若前方 12 格有障碍则使用
  if find_item_index(player, 2006) then
    if ItemService.has_obstacles_ahead(game, player, 12) then
      local res = ItemService.use_item(game, player, 2006)
      if res and res.waiting then
        return res
      end
    end
  end

  -- 遥控骰子：自动设为最高点数
  if find_item_index(player, 2002) then
    local res = ItemService.use_item(game, player, 2002)
    if res and res.waiting then
      return res
    end
  end

  -- 骰子加倍：有就用
  if find_item_index(player, 2003) then
    local res = ItemService.use_item(game, player, 2003)
    if res and res.waiting then
      return res
    end
  end

  -- 路障：自动放置前方 3 格内最近空位
  if find_item_index(player, 2004) then
    local res = ItemService.use_item(game, player, 2004)
    if res and res.waiting then
      return res
    end
  end

  -- 怪兽卡：若前后 3 格内有他人建筑则使用
  if find_item_index(player, 2008) and ItemService.find_monster_target(game, player, 3) then
    local res = ItemService.use_item(game, player, 2008)
    if res and res.waiting then
      return res
    end
  end

  -- 导弹卡：若前后 3 格有可轰炸目标则使用
  if find_item_index(player, 2013) and find_missile_target(game, player, 3) then
    local res = ItemService.use_item(game, player, 2013)
    if res and res.waiting then
      return res
    end
  end

  -- 财神/天使/穷神：优先自用财神/天使
  if find_item_index(player, 2017) then
    local res = ItemService.use_item(game, player, 2017)
    if res and res.waiting then
      return res
    end
  elseif find_item_index(player, 2019) then
    local res = ItemService.use_item(game, player, 2019)
    if res and res.waiting then
      return res
    end
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

local function indices_in_range(board, start, distance)
  local len = board:length()
  local seen = {}
  local list = {}
  for step = 1, distance do
    local forward = start + step
    if forward > len then
      forward = forward - len
    end
    if not seen[forward] then
      table.insert(list, forward)
      seen[forward] = true
    end

    local back = start - step
    if back < 1 then
      back = len + back
    end
    if not seen[back] then
      table.insert(list, back)
      seen[back] = true
    end
  end
  return list
end

function ItemService.find_monster_target(game, player, distance)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    local tile = board:get_tile(idx)
    if tile.type == "land" and tile.level > 0 and tile.owner_id and tile.owner_id ~= player.id then
      local value = tile:total_invested()
      if not best_value or value > best_value then
        best_value = value
        best_idx = idx
      end
    end
  end
  return best_idx
end

local function destroy_building(tile)
  if tile.type == "land" then
    tile.level = 0
  end
end

function ItemService.use_monster(game, player, distance)
  local idx = ItemService.find_monster_target(game, player, distance)
  if not idx then
    logger.warn(player.name .. " 前后无可拆除建筑，怪兽卡未生效")
    return false
  end
  local tile = game.board:get_tile(idx)
  destroy_building(tile)
  logger.event(player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑")
  push_popup(game, "怪兽卡", player.name .. " 拆毁了 " .. tile.name .. " 的建筑")
  return true
end

find_missile_target = function(game, player, distance)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    if idx ~= player.position then
      local tile = board:get_tile(idx)
      local val = 0
      if tile.type == "land" then
        val = tile:total_invested()
      end
      if not best_value or val > best_value then
        best_value = val
        best_idx = idx
      end
    end
  end
  return best_idx
end

local function send_players_to_hospital(game, idx)
  local occupants = game.occupants[idx]
  if not occupants then
    return 0
  end
  local count = 0
  local snapshot = { table.unpack(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = game.players[pid]
    if target then
      target.seat_id = nil
      StatusService.send_to_hospital(game, target, { skip_fee = true })
      count = count + 1
    end
  end
  return count
end

local function clear_overlays(game, idx)
  if game.overlays.roadblocks[idx] then
    game.overlays.roadblocks[idx] = nil
  end
  if game.overlays.mines[idx] then
    game.overlays.mines[idx] = nil
  end
end

function ItemService.apply_missile(game, player, idx)
  clear_overlays(game, idx)
  local tile = game.board:get_tile(idx)
  destroy_building(tile)
  local hit = send_players_to_hospital(game, idx)
  local msg = player.name .. " 发射导弹轰炸 " .. tile.name
  if tile.type == "land" then
    msg = msg .. "，建筑被摧毁"
  end
  if hit > 0 then
    msg = msg .. "，" .. hit .. " 名玩家送医"
  end
  logger.event(msg)
  push_popup(game, "导弹卡", msg)
end

function ItemService.use_missile(game, player, distance)
  local best_idx = find_missile_target(game, player, distance)
  if not best_idx then
    logger.warn(player.name .. " 前后无可轰炸目标，导弹卡未生效")
    return false
  end
  if game and game.ui_enabled then
    local idxs = indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}
    for _, idx in ipairs(idxs) do
      if idx ~= player.position then
        local tile = game.board:get_tile(idx)
        table.insert(body_lines, "#" .. idx .. " " .. tile.name)
        table.insert(options, { id = idx, label = tile.name })
      end
    end
    if #options > 0 then
      Choice.open(game, {
        kind = "missile_target",
        title = "导弹卡：选择目标格子",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { player_id = player.id },
      })
      return { waiting = true }
    end
  end

  if not consume_item(player, 2013) then
    return false
  end
  ItemService.apply_missile(game, player, best_idx)
  return true
end

function ItemService.apply_target_item_effect(game, player, item_id, target)
  if item_id == 2011 then
    local total = player.cash + target.cash
    local half = math.floor(total / 2)
    player.cash = half
    target.cash = total - half
    logger.event(player.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
    return true
  elseif item_id == 2012 then
    StatusService.send_to_mountain(game, target)
    logger.event(player.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
    return true
  elseif item_id == 2014 then
    if StatusService.has_angel(target) then
      logger.event(target.name .. " 有天使，查税无效")
      return true
    end
    local tax_free = find_item_index(target, 2010)
    if tax_free then
      target.inventory:remove_by_index(tax_free)
      logger.event(target.name .. " 使用免税卡抵消查税")
      return true
    end
    local fee = math.floor(target.cash * 0.5)
    target:deduct_cash(fee)
    logger.event(player.name .. " 使用查税卡，" .. target.name .. " 支付 " .. fee .. " 税金")
    if target.cash < 0 then
      BankruptcyService.eliminate(game, target)
    end
    return true
  elseif item_id == 2015 then
    if not target.status.deity then
      logger.warn("没有可请的神")
      return false
    end
    local deity = target.status.deity
    target:set_deity(nil)
    player:set_deity(deity.type, deity.remaining)
    logger.event(player.name .. " 使用请神卡，从 " .. target.name .. " 请走 " .. deity.type)
    return true
  elseif item_id == 2016 then
    if not player:has_deity("poor") then
      logger.warn("未附身穷神，无法送神")
      return false
    end
    local remaining = player.status.deity and player.status.deity.remaining or nil
    target:set_deity("poor", remaining)
    player:set_deity(nil)
    logger.event(player.name .. " 使用送神卡，将穷神送给 " .. target.name)
    return true
  elseif item_id == 2018 then
    target:set_deity("poor")
    logger.event(player.name .. " 使用穷神卡，" .. target.name .. " 穷神附身")
    return true
  end
  return false
end

function ItemService.use_item(game, player, item_id, context)
  local cfg = cfg_by_id[item_id]
  if not cfg then
    return false
  end

  -- Items requiring target selection should consume inside their callback
  if item_id == 2008 then
    if not ItemService.find_monster_target(game, player, 3) then
      logger.warn(player.name .. " 前后无他人建筑，怪兽卡未使用")
      return false
    end
    if not consume_item(player, item_id) then
      return false
    end
    return ItemService.use_monster(game, player, 3)
  elseif item_id == 2013 then
    if not find_missile_target(game, player, 3) then
      logger.warn(player.name .. " 前后无轰炸目标，导弹卡未使用")
      return false
    end
    return ItemService.use_missile(game, player, 3)
  end

  if item_id == 2011 or item_id == 2012 or item_id == 2014 or item_id == 2015 or item_id == 2016 or item_id == 2018 then
    if item_id == 2016 and not player:has_deity("poor") then
      logger.warn("未附身穷神，无法送神")
      return false
    end

    local candidates = {}
    for _, p in ipairs(game.players) do
      if p.id ~= player.id and not p.eliminated then
        if item_id == 2015 then
          if p.status.deity then
            table.insert(candidates, p)
          end
        else
          table.insert(candidates, p)
        end
      end
    end

    if #candidates == 0 then
      logger.warn("没有可选择的目标玩家")
      return false
    end

    if game and game.ui_enabled and #candidates > 1 then
      local options = {}
      local body_lines = {}
      for _, t in ipairs(candidates) do
        table.insert(body_lines, t.name .. " 现金:" .. t.cash .. (t.status.deity and (" 神:" .. t.status.deity.type) or ""))
        table.insert(options, { id = t.id, label = t.name })
      end
      Choice.open(game, {
        kind = "item_target_player",
        title = ItemService.item_name(item_id) .. "：选择目标玩家",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { item_id = item_id, user_id = player.id },
      })
      return { waiting = true }
    end

    local target = candidates[1]
    local ok = ItemService.apply_target_item_effect(game, player, item_id, target)
    if ok then
      consume_item(player, item_id)
    end
    return ok
  end

  local ok = consume_item(player, item_id)
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
    push_popup(game, "埋设地雷", player.name .. " 在脚下埋设了地雷")
  elseif item_id == 2006 then
    ItemService.clear_obstacles(game, player, 12)
  elseif item_id == 2007 then
    -- 偷窃在经过时处理
    logger.event(player.name .. " 准备偷窃（将在经过玩家时触发）")
  elseif item_id == 2009 then
    logger.event(player.name .. " 准备使用强征卡（踩他人地块时触发）")
  elseif item_id == 2010 then
    player.status.pending_tax_free = true
    logger.event(player.name .. " 使用免税卡，本次征税免除")
  elseif item_id == 2011 then
    ItemService.use_wealth_share(game, player)
  elseif item_id == 2012 then
    ItemService.use_exile(game, player)
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
      push_popup(game, "放置路障", player.name .. " 在 " .. board:get_tile(current).name .. " 设置了路障")
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
  local candidates = {}
  for _, target_id in ipairs(encountered_ids) do
    local t = game.players[target_id]
    if t and not StatusService.has_angel(t) and t.inventory:count() > 0 then
      table.insert(candidates, t)
    end
  end
  if #candidates == 0 then
    return
  end
  if not game or not game.ui_enabled then
    ItemService.steal_item_at_index(game, player, candidates[1], 1)
    return nil
  end

  if #candidates == 1 then
    local target = candidates[1]
    if target.inventory:count() <= 1 then
      ItemService.steal_item_at_index(game, player, target, 1)
      return nil
    end
    local options = {}
    local body_lines = {}
    for idx, it in ipairs(target.inventory.items) do
      local label = ItemService.item_name(it.id)
      table.insert(body_lines, idx .. ". " .. label)
      table.insert(options, { id = idx, label = label })
    end
    Choice.open(game, {
      kind = "steal_item",
      title = "选择要偷的道具",
      body_lines = body_lines,
      options = options,
      allow_cancel = true,
      cancel_label = "取消",
      meta = { stealer_id = player.id, target_id = target.id },
    })
    return { waiting = true }
  end

  local options = {}
  local body_lines = {}
  for _, t in ipairs(candidates) do
    table.insert(body_lines, t.name .. " 现金:" .. t.cash)
    table.insert(options, { id = t.id, label = t.name })
  end
  Choice.open(game, {
    kind = "steal_target",
    title = "偷窃卡：选择目标",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "取消",
    meta = { stealer_id = player.id },
  })
  return { waiting = true }
end

function ItemService.steal_item_at_index(game, player, target, item_idx)
  local inv = target.inventory
  if inv:count() == 0 then
    logger.warn(target.name .. " 没有可偷道具")
    return nil
  end
  local stolen = inv:remove_by_index(item_idx or 1)
  if not stolen then
    return nil
  end
  if player.inventory:is_full() then
    logger.warn(player.name .. " 背包已满，偷窃道具被销毁")
    return nil
  end
  player.inventory:add(stolen)
  consume_item(player, 2007)
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. ItemService.item_name(stolen.id))
  push_popup(game, "偷窃成功", player.name .. " 从 " .. target.name .. " 偷走了 " .. ItemService.item_name(stolen.id))
  return stolen
end

function ItemService.use_wealth_share(game, player)
  local target = ItemService.select_player(game, player, "均富卡：选择一名玩家平分现金", function(t)
    local total = player.cash + t.cash
    local half = math.floor(total / 2)
    player.cash = half
    t.cash = total - half
    logger.event(player.name .. " 使用均富卡，与 " .. t.name .. " 平分资金")
  end)
  if target then
    local total = player.cash + target.cash
    local half = math.floor(total / 2)
    player.cash = half
    target.cash = total - half
    logger.event(player.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
  end
end

function ItemService.use_exile(game, player)
  local target = ItemService.select_player(game, player, "流放卡：选择一名玩家送往深山", function(t)
    StatusService.send_to_mountain(game, t)
    logger.event(player.name .. " 使用流放卡，将 " .. t.name .. " 送往深山")
  end)
  if target then
    StatusService.send_to_mountain(game, target)
    logger.event(player.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
  end
end

function ItemService.use_audit(game, player)
  local function audit_target(t)
    if StatusService.has_angel(t) then
      logger.event(t.name .. " 有天使，查税无效")
      return
    end
    local tax_free = find_item_index(t, 2010)
    if tax_free then
      t.inventory:remove_by_index(tax_free)
      logger.event(t.name .. " 使用免税卡抵消查税")
      return
    end
    local fee = math.floor(t.cash * 0.5)
    t:deduct_cash(fee)
    logger.event(player.name .. " 使用查税卡，" .. t.name .. " 支付 " .. fee .. " 税金")
    if t.cash < 0 then
      BankruptcyService.eliminate(game, t)
    end
  end
  local target = ItemService.select_player(game, player, "查税卡：选择一名玩家支付 50% 现金", audit_target)
  if target then
    audit_target(target)
  end
end

function ItemService.use_invite_god(game, player)
  local function do_invite(t)
    if not t.status.deity then
      logger.warn("没有可请的神")
      return
    end
    local deity = t.status.deity
    t:set_deity(nil)
    player:set_deity(deity.type, deity.remaining)
    logger.event(player.name .. " 使用请神卡，从 " .. t.name .. " 请走 " .. deity.type)
  end
  local target = ItemService.select_player(game, player, "请神卡：选择一名玩家夺取其神", do_invite)
  if target then
    do_invite(target)
  end
end

function ItemService.use_send_poor_god(game, player)
  if not player:has_deity("poor") then
    logger.warn("未附身穷神，无法送神")
    return
  end
  local function do_send(t)
    t:set_deity("poor", player.status.deity.remaining)
    player:set_deity(nil)
    logger.event(player.name .. " 使用送神卡，将穷神送给 " .. t.name)
  end
  local target = ItemService.select_player(game, player, "送神卡：选择一名玩家转移穷神", do_send)
  if target then
    do_send(target)
  end
end

function ItemService.use_poor_god(game, player)
  local function do_poor(t)
    t:set_deity("poor")
    logger.event(player.name .. " 使用穷神卡，" .. t.name .. " 穷神附身")
  end
  local target = ItemService.select_player(game, player, "穷神卡：选择一名玩家附身穷神", do_poor)
  if target then
    do_poor(target)
  end
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

function ItemService.select_player(game, player, title, on_async_select)
  local choices = {}
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated then
      table.insert(choices, p)
    end
  end
  if #choices == 0 then
    return nil
  end
  if on_async_select and game.ui_hooks and game.ui_hooks.request_choice and #choices > 1 then
    local body_lines = {}
    for _, p in ipairs(choices) do
      table.insert(body_lines, p.name .. " 现金:" .. p.cash .. (p.status.deity and (" 神:" .. p.status.deity.type) or ""))
    end
    request_choice(game, title or "选择玩家", choices, on_async_select, body_lines)
    return nil
  end
  return choices[1]
end

return ItemService
