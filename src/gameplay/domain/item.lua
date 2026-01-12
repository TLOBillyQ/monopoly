local constants = require("src.config.constants")
local items_cfg = require("src.config.items")
local random = require("src.util.random")
local logger = require("src.util.logger")
local UI = require("src.gameplay.ui")

local ItemEffects = {}

local find_missile_target -- forward declare

local function get_service(game, key)
  if game and game.services then
    return game.services[key]
  end
end

local function status_service(game)
  return get_service(game, "status")
end

local function bankruptcy_service(game)
  return get_service(game, "bankruptcy")
end

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

function ItemEffects.item_name(item_id)
  local cfg = cfg_by_id[item_id]
  return (cfg and cfg.name) or tostring(item_id)
end

local function find_item_index(player, item_id)
  return player.inventory:find_index(function(it)
    return it.id == item_id
  end)
end

function ItemEffects.consume_item(player, item_id)
  local idx = find_item_index(player, item_id)
  if idx then
    player.inventory:remove_by_index(idx)
    return true
  end
  return false
end

function ItemEffects.draw_random_item(rng)
  return random.weighted_choice(items_cfg, "weight", rng)
end

function ItemEffects.give_item(player, item_id)
  if player.inventory:is_full() then
    logger.warn(player.name .. " 的背包已满，无法获得道具 " .. item_id)
    return false
  end
  player.inventory:add({ id = item_id })
  logger.event(player.name .. " 获得道具 " .. ItemEffects.item_name(item_id))
  return true
end

function ItemEffects.draw_and_give(player, rng)
  local cfg = ItemEffects.draw_random_item(rng)
  if not cfg then
    return
  end
  ItemEffects.give_item(player, cfg.id)
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

local function tile_state(game, tile)
  if not game or not game.store or not tile or tile.type ~= "land" then
    return { owner_id = nil, level = 0 }
  end
  local s = game.store:get({ "board", "tiles", tile.id })
  if type(s) ~= "table" then
    return { owner_id = nil, level = 0 }
  end
  return { owner_id = s.owner_id, level = s.level or 0 }
end

local function total_invested(tile, owner_id, level)
  if not owner_id then
    return 0
  end
  level = level or 0
  local price = tile.price or 0
  return price * ((2 ^ (level + 1)) - 1)
end

function ItemEffects.find_monster_target(game, player, distance)
  distance = distance or 3
  local board = game.board
  local best_idx = nil
  local best_value = nil
  for _, idx in ipairs(indices_in_range(board, player.position, distance)) do
    local tile = board:get_tile(idx)
    if tile.type == "land" then
      local st = tile_state(game, tile)
      if (st.level or 0) > 0 and st.owner_id and st.owner_id ~= player.id then
        local value = total_invested(tile, st.owner_id, st.level)
      if not best_value or value > best_value then
        best_value = value
        best_idx = idx
      end
      end
    end
  end
  return best_idx
end

local function destroy_building(game, tile)
  if tile.type ~= "land" then
    return
  end
  if game and game.set_tile_level then
    game:set_tile_level(tile, 0)
  elseif game and game.store and tile and tile.id then
    game.store:set({ "board", "tiles", tile.id, "level" }, 0)
  end
end

function ItemEffects.use_monster(game, player, distance)
  local idx = ItemEffects.find_monster_target(game, player, distance)
  if not idx then
    logger.warn(player.name .. " 前后无可拆除建筑，怪兽卡未生效")
    return false
  end
  local tile = game.board:get_tile(idx)
  destroy_building(game, tile)
  logger.event(player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑")
  UI.push_popup(game, { title = "怪兽卡", body = player.name .. " 拆毁了 " .. tile.name .. " 的建筑" })
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
        local st = tile_state(game, tile)
        val = total_invested(tile, st.owner_id, st.level)
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
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法送医")
    return 0
  end
  local count = 0
  local unpack_fn = table.unpack or unpack
  local snapshot = { unpack_fn(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = game.players[pid]
    if target then
      if game and game.set_player_seat then
        game:set_player_seat(target, nil)
      else
        target.seat_id = nil
      end
      status.send_to_hospital(game, target, { skip_fee = true })
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

function ItemEffects.apply_missile(game, player, idx)
  clear_overlays(game, idx)
  local tile = game.board:get_tile(idx)
  destroy_building(game, tile)
  local hit = send_players_to_hospital(game, idx)
  local msg = player.name .. " 发射导弹轰炸 " .. tile.name
  if tile.type == "land" then
    msg = msg .. "，建筑被摧毁"
  end
  if hit > 0 then
    msg = msg .. "，" .. hit .. " 名玩家送医"
  end
  logger.event(msg)
  UI.push_popup(game, { title = "导弹卡", body = msg })
end

function ItemEffects.use_missile(game, player, distance)
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
      return {
        waiting = true,
        intent = {
          kind = "need_choice",
          choice_spec = {
            kind = "missile_target",
            title = "导弹卡：选择目标格子",
            body_lines = body_lines,
            options = options,
            allow_cancel = true,
            cancel_label = "取消",
            meta = { player_id = player.id },
          },
        },
      }
    end
  end

  if not ItemEffects.consume_item(player, 2013) then
    return false
  end
  ItemEffects.apply_missile(game, player, best_idx)
  return true
end

function ItemEffects.apply_target_item_effect(game, player, item_id, target)
  if item_id == 2011 then
    local total = player.cash + target.cash
    local half = math.floor(total / 2)
    player:set_cash(half)
    target:set_cash(total - half)
    logger.event(player.name .. " 使用均富卡，与 " .. target.name .. " 平分资金")
    return true
  elseif item_id == 2012 then
    local status = status_service(game)
    if not status then
      logger.warn("缺少 StatusService，无法流放")
      return false
    end
    status.send_to_mountain(game, target)
    logger.event(player.name .. " 使用流放卡，将 " .. target.name .. " 送往深山")
    return true
  elseif item_id == 2014 then
    local status = status_service(game)
    if not status then
      logger.warn("缺少 StatusService，无法查税")
      return false
    end
    if status.has_angel(target) then
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
      local bankruptcy = bankruptcy_service(game)
      if not bankruptcy then
        logger.warn("缺少 BankruptcyService，无法淘汰破产玩家")
        return true
      end
      bankruptcy.eliminate(game, target)
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

local function handle_target_player_item(game, player, item_id)
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
    return {
      waiting = true,
      intent = {
        kind = "need_choice",
        choice_spec = {
          kind = "item_target_player",
          title = ItemEffects.item_name(item_id) .. "：选择目标玩家",
          body_lines = body_lines,
          options = options,
          allow_cancel = true,
          cancel_label = "取消",
          meta = { item_id = item_id, user_id = player.id },
        },
      },
    }
  end

  local target = candidates[1]
  local ok = ItemEffects.apply_target_item_effect(game, player, item_id, target)
  if ok then
    ItemEffects.consume_item(player, item_id)
  end
  return ok
end

local item_handlers = {}
local post_consume_handlers = {}

item_handlers[2008] = function(game, player, item_id)
  if not ItemEffects.find_monster_target(game, player, 3) then
    logger.warn(player.name .. " 前后无他人建筑，怪兽卡未使用")
    return false
  end
  if not ItemEffects.consume_item(player, item_id) then
    return false
  end
  return ItemEffects.use_monster(game, player, 3)
end

item_handlers[2013] = function(game, player, _item_id)
  if not find_missile_target(game, player, 3) then
    logger.warn(player.name .. " 前后无轰炸目标，导弹卡未使用")
    return false
  end
  return ItemEffects.use_missile(game, player, 3)
end

for _, id in ipairs({ 2011, 2012, 2014, 2015, 2016, 2018 }) do
  item_handlers[id] = handle_target_player_item
end

post_consume_handlers[2001] = function(game, player, _context)
  if game and game.set_player_status then
    game:set_player_status(player, "pending_free_rent", true)
  else
    player.status.pending_free_rent = true
  end
  logger.event(player.name .. " 使用免费卡，下一次租金免除")
  return true
end

post_consume_handlers[2002] = function(game, player, _context)
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  local values = {}
  for i = 1, dice_count do
    values[i] = 6
  end
  if game and game.set_player_status then
    game:set_player_status(player, "pending_remote_dice", { values = values })
  else
    player.status.pending_remote_dice = { values = values }
  end
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

post_consume_handlers[2003] = function(game, player, _context)
  if game and game.set_player_status then
    game:set_player_status(player, "pending_dice_multiplier", 2)
  else
    player.status.pending_dice_multiplier = 2
  end
  logger.event(player.name .. " 使用骰子加倍卡，本次步数翻倍")
  return true
end

post_consume_handlers[2004] = function(game, player)
  local board = game.board
  local current = player.position
  local parity = 1
  for _ = 1, 3 do
    local next_index = board:advance(current, 1, parity)
    current = next_index
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

post_consume_handlers[2005] = function(game, player)
  game.overlays.mines[player.position] = true
  logger.event(player.name .. " 在脚下埋设地雷")
  UI.push_popup(game, { title = "埋设地雷", body = player.name .. " 在脚下埋设了地雷" })
  return true
end

post_consume_handlers[2006] = function(game, player)
  local board = game.board
  local cleared = 0
  local current = player.position
  local parity = 1
  for _ = 1, 12 do
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
  return true
end

post_consume_handlers[2007] = function(_, player)
  logger.event(player.name .. " 准备偷窃（将在经过玩家时触发）")
  return true
end

post_consume_handlers[2009] = function(_, player)
  logger.event(player.name .. " 准备使用强征卡（踩他人地块时触发）")
  return true
end

post_consume_handlers[2010] = function(game, player, _context)
  if game and game.set_player_status then
    game:set_player_status(player, "pending_tax_free", true)
  else
    player.status.pending_tax_free = true
  end
  logger.event(player.name .. " 使用免税卡，本次征税免除")
  return true
end

post_consume_handlers[2017] = function(game, player)
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法附身财神")
    return false
  end
  status.apply_deity(player, "rich")
  return true
end

post_consume_handlers[2019] = function(game, player)
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法附身天使")
    return false
  end
  status.apply_deity(player, "angel")
  return true
end

function ItemEffects.use_item(game, player, item_id, context)
  local cfg = cfg_by_id[item_id]
  if not cfg then
    return false
  end

  local handler = item_handlers[item_id]
  if handler then
    return handler(game, player, item_id, context)
  end

  local consumed = ItemEffects.consume_item(player, item_id)
  if not consumed then
    return false
  end

  local post = post_consume_handlers[item_id]
  if post then
    local res = post(game, player, context)
    if res ~= nil then
      return res
    end
    return true
  end

  logger.warn("未实现的道具:" .. tostring(item_id))
  return false
end

function ItemEffects.has_obstacles_ahead(game, player, distance)
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

function ItemEffects.auto_pre_action(game, player)
  -- 清障卡：若前方 12 格有障碍则使用
  if find_item_index(player, 2006) then
    if ItemEffects.has_obstacles_ahead(game, player, 12) then
      local res = ItemEffects.use_item(game, player, 2006)
      if type(res) == "table" and res.waiting then
        return res
      end
    end
  end

  -- 遥控骰子：自动设为最高点数
  if find_item_index(player, 2002) then
    local res = ItemEffects.use_item(game, player, 2002)
    if type(res) == "table" and res.waiting then
      return res
    end
  end

  -- 骰子加倍：有就用
  if find_item_index(player, 2003) then
    local res = ItemEffects.use_item(game, player, 2003)
    if type(res) == "table" and res.waiting then
      return res
    end
  end

  -- 路障：自动放置前方 3 格内最近空位
  if find_item_index(player, 2004) then
    local res = ItemEffects.use_item(game, player, 2004)
    if type(res) == "table" and res.waiting then
      return res
    end
  end

  -- 怪兽卡：若前后 3 格内有他人建筑则使用
  if find_item_index(player, 2008) and ItemEffects.find_monster_target(game, player, 3) then
    local res = ItemEffects.use_item(game, player, 2008)
    if type(res) == "table" and res.waiting then
      return res
    end
  end

  -- 导弹卡：若前后 3 格有可轰炸目标则使用
  if find_item_index(player, 2013) and find_missile_target(game, player, 3) then
    local res = ItemEffects.use_item(game, player, 2013)
    if type(res) == "table" and res.waiting then
      return res
    end
  end

  -- 财神/天使/穷神：优先自用财神/天使
  if find_item_index(player, 2017) then
    local res = ItemEffects.use_item(game, player, 2017)
    if type(res) == "table" and res.waiting then
      return res
    end
  elseif find_item_index(player, 2019) then
    local res = ItemEffects.use_item(game, player, 2019)
    if type(res) == "table" and res.waiting then
      return res
    end
  end
end

function ItemEffects.steal_item_at_index(game, player, target, item_idx)
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
  ItemEffects.consume_item(player, 2007)
  logger.event(player.name .. " 使用偷窃卡，从 " .. target.name .. " 偷走道具 " .. ItemEffects.item_name(stolen.id))
  UI.push_popup(game, { title = "偷窃成功", body = player.name .. " 从 " .. target.name .. " 偷走了 " .. ItemEffects.item_name(stolen.id) })
  return stolen
end

function ItemEffects.handle_pass_players(game, player, encountered_ids)
  if #encountered_ids == 0 then
    return
  end
  local has_steal = find_item_index(player, 2007)
  if not has_steal then
    return
  end
  local candidates = {}
  local status = status_service(game)
  if not status then
    logger.warn("缺少 StatusService，无法处理偷窃目标筛选")
    return
  end
  for _, target_id in ipairs(encountered_ids) do
    local t = game.players[target_id]
    if t and not status.has_angel(t) and t.inventory:count() > 0 then
      table.insert(candidates, t)
    end
  end
  if #candidates == 0 then
    return
  end
  if not game or not game.ui_enabled then
    ItemEffects.steal_item_at_index(game, player, candidates[1], 1)
    return nil
  end

  if #candidates == 1 then
    local target = candidates[1]
    if target.inventory:count() <= 1 then
      ItemEffects.steal_item_at_index(game, player, target, 1)
      return nil
    end
    local options = {}
    local body_lines = {}
    for idx, it in ipairs(target.inventory.items) do
      local label = ItemEffects.item_name(it.id)
      table.insert(body_lines, idx .. ". " .. label)
      table.insert(options, { id = idx, label = label })
    end
    return {
      waiting = true,
      intent = {
        kind = "need_choice",
        choice_spec = {
          kind = "steal_item",
          title = "选择要偷的道具",
          body_lines = body_lines,
          options = options,
          allow_cancel = true,
          cancel_label = "取消",
          meta = { stealer_id = player.id, target_id = target.id },
        },
      },
    }
  end

  local options = {}
  local body_lines = {}
  for _, t in ipairs(candidates) do
    table.insert(body_lines, t.name .. " 现金:" .. t.cash)
    table.insert(options, { id = t.id, label = t.name })
  end
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = {
        kind = "steal_target",
        title = "偷窃卡：选择目标",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { stealer_id = player.id },
      },
    },
  }
end

return ItemEffects
