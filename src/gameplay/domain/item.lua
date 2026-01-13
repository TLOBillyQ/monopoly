local constants = require("src.config.constants")
local items_cfg = require("src.config.items")
local random = require("src.util.random")
local logger = require("src.util.logger")
local UI = require("src.gameplay.ports.ui_port")
local GameState = require("src.util.game_state")
local Agent = require("src.gameplay.ai.agent")
local PostEffects = require("src.gameplay.domain.item_post_effects")
local TargetEffects = require("src.gameplay.domain.item_target_effects")
local Monster = require("src.gameplay.domain.item_monster")
local Missile = require("src.gameplay.domain.item_missile")
local Roadblock = require("src.gameplay.domain.item_roadblock")
local Steal = require("src.gameplay.domain.item_steal")

local ItemEffects = {}

local function get_service(context, game, key)
  if context and context.services and context.services[key] then
    return context.services[key]
  end
  return game and game.services and game.services[key]
end

local tile_state = GameState.tile_state

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

local function target_candidates(game, player, item_id)
  local spec = TargetEffects.get_spec(item_id)
  if not spec then
    return {}
  end

  if spec.require_user and not spec.require_user(player) then
    return {}
  end

  local candidates = {}
  for _, p in ipairs(game.players) do
    if p.id ~= player.id and not p.eliminated then
      if not spec.filter_target or spec.filter_target(game, player, p) then
        table.insert(candidates, p)
      end
    end
  end
  return candidates
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

function ItemEffects.apply_remote_dice(game, player, dice_count, value)
  if not dice_count or dice_count < 1 then
    return false
  end
  local values = {}
  for i = 1, dice_count do
    values[i] = value
  end
  game:set_player_status(player, "pending_remote_dice", { values = values })
  logger.event(player.name .. " 使用遥控骰子，设定点数 " .. table.concat(values, ","))
  return true
end

function ItemEffects.find_monster_target(game, player, distance)
  return Monster.find_target(game, player, distance)
end

function ItemEffects.use_monster(game, player, distance)
  return Monster.use(game, player, distance)
end

function ItemEffects.find_missile_target(game, player, distance)
  return Missile.find_target(game, player, distance)
end

function ItemEffects.apply_missile(game, player, idx, context)
  return Missile.apply(game, player, idx, context)
end

function ItemEffects.use_missile(game, player, distance, context)
  return Missile.use(game, player, distance, ItemEffects.consume_item, context)
end

function ItemEffects.apply_target_item_effect(game, player, item_id, target)
  return TargetEffects.apply(game, player, item_id, target)
end

local function handle_target_player_item(game, player, item_id, context)
  local spec = TargetEffects.get_spec(item_id)
  if not spec then
    return false
  end

  if spec.require_user and not spec.require_user(player) then
    return false
  end

  local candidates = target_candidates(game, player, item_id)

  if #candidates == 0 then
    logger.warn("没有可选择的目标玩家")
    return false
  end

  if context and context.by_ai then
    local target = Agent.pick_target_player(game, player, item_id, candidates)
    if not target then
      return false
    end
    local ok = ItemEffects.apply_target_item_effect(game, player, item_id, target)
    if ok then
      ItemEffects.consume_item(player, item_id)
    end
    return ok
  end

  if UI.is_available(game) and #candidates > 1 then
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

item_handlers[2002] = function(game, player, item_id, context)
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  if context and context.by_ai then
    local value, target_tile = Agent.pick_remote_dice_value(game, player, dice_count)
    if not value then
      return false
    end
    if not ItemEffects.consume_item(player, item_id) then
      return false
    end
    local ok = ItemEffects.apply_remote_dice(game, player, dice_count, value)
    if ok and target_tile then
      logger.event(player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. value)
    end
    return ok
  end
  if UI.is_available(game) then
    local options = {}
    local body_lines = {}
    for i = 1, 6 do
      table.insert(options, { id = i, label = tostring(i) })
      table.insert(body_lines, "点数 " .. i)
    end
    return {
      waiting = true,
      intent = {
        kind = "need_choice",
        choice_spec = {
          kind = "remote_dice_value",
          title = "遥控骰子：选择点数",
          body_lines = body_lines,
          options = options,
          allow_cancel = true,
          cancel_label = "放弃",
          meta = { player_id = player.id, item_id = item_id, dice_count = dice_count },
        },
      },
    }
  end

  if not ItemEffects.consume_item(player, item_id) then
    return false
  end
  return ItemEffects.apply_remote_dice(game, player, dice_count, 6)
end

item_handlers[2004] = function(game, player, item_id, context)
  local candidates = Roadblock.candidates(game, player, 3)
  if not candidates or #candidates == 0 then
    logger.warn(player.name .. " 无可放置路障的位置")
    return false
  end

  if context and context.by_ai then
    local idx = Agent.pick_roadblock_target(game, player)
    if not idx then
      return false
    end
    if not ItemEffects.consume_item(player, item_id) then
      return false
    end
    return Roadblock.apply(game, player, idx)
  end

  if UI.is_available(game) then
    local options = {}
    local body_lines = {}
    for _, cand in ipairs(candidates) do
      table.insert(options, { id = cand.idx, label = cand.label })
      table.insert(body_lines, cand.label)
    end
    return {
      waiting = true,
      intent = {
        kind = "need_choice",
        choice_spec = {
          kind = "roadblock_target",
          title = "路障卡：选择位置",
          body_lines = body_lines,
          options = options,
          allow_cancel = true,
          cancel_label = "放弃",
          meta = { player_id = player.id, item_id = item_id },
        },
      },
    }
  end

  local best = Roadblock.pick_best(candidates)
  if not best then
    logger.warn(player.name .. " 未找到可放置的路障格子")
    return false
  end
  if not ItemEffects.consume_item(player, item_id) then
    return false
  end
  return Roadblock.apply(game, player, best.idx)
end

item_handlers[2008] = function(game, player, item_id, _context)
  if not ItemEffects.find_monster_target(game, player, 3) then
    logger.warn(player.name .. " 前后无他人建筑，怪兽卡未使用")
    return false
  end
  if not ItemEffects.consume_item(player, item_id) then
    return false
  end
  return ItemEffects.use_monster(game, player, 3)
end

item_handlers[2013] = function(game, player, _item_id, context)
  if not ItemEffects.find_missile_target(game, player, 3) then
    logger.warn(player.name .. " 前后无轰炸目标，导弹卡未使用")
    return false
  end
  return ItemEffects.use_missile(game, player, 3, context)
end

for _, id in ipairs({ 2011, 2012, 2014, 2015, 2016, 2018 }) do
  item_handlers[id] = handle_target_player_item
end

function ItemEffects.use_item(game, player, item_id, context)
  context = context or {}
  context.services = context.services or (game and game.services)
  if context.by_ai == nil then
    context.by_ai = Agent.is_auto_player(player)
  end
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

  local res = PostEffects.apply(game, player, item_id, context)
  if res ~= nil then
    return res
  end

  logger.warn("未实现的道具:" .. tostring(item_id))
  return false
end

function ItemEffects.has_obstacles_ahead(game, player, distance)
  local board = game.board
  local parity = 1
  local current = player.position
  local facing = player.status and player.status.move_dir or nil
  local overlay = get_service(nil, game, "overlay")
  if not overlay then
    return false
  end
  for _ = 1, distance do
    local next_index, _passed, step_dir = board:step_forward_by_facing(current, facing, parity)
    current = next_index
    facing = step_dir or facing
    if overlay.has_roadblock(game, current) or overlay.has_mine(game, current) then
      return true
    end
  end
  return false
end

function ItemEffects.auto_pre_action(game, player)
  if not Agent.is_auto_player(player) then
    return nil
  end

  local function try_use(item_id, cond)
    if cond and not cond() then
      return nil
    end
    if not find_item_index(player, item_id) then
      return nil
    end
    local res = ItemEffects.use_item(game, player, item_id, { by_ai = true })
    if type(res) == "table" then
      if res.waiting then
        return res
      end
      if res.intent or res.intents then
        return res
      end
    end
    return nil
  end

  local rules = {
    { id = 2006, cond = function() return ItemEffects.has_obstacles_ahead(game, player, 12) end },
    {
      id = 2002,
      cond = function()
        local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
        local value = Agent.pick_remote_dice_value(game, player, dice_count)
        return value ~= nil
      end,
    },
    { id = 2003 },
    { id = 2004, cond = function() return Agent.pick_roadblock_target(game, player) ~= nil end },
    { id = 2008, cond = function() return ItemEffects.find_monster_target(game, player, 3) ~= nil end },
    { id = 2013, cond = function() return ItemEffects.find_missile_target(game, player, 3) ~= nil end },
    {
      id = 2011,
      cond = function()
        return Agent.pick_target_player(game, player, 2011, target_candidates(game, player, 2011)) ~= nil
      end,
    },
    {
      id = 2012,
      cond = function()
        return Agent.pick_target_player(game, player, 2012, target_candidates(game, player, 2012)) ~= nil
      end,
    },
    {
      id = 2014,
      cond = function()
        return Agent.pick_target_player(game, player, 2014, target_candidates(game, player, 2014)) ~= nil
      end,
    },
    {
      id = 2015,
      cond = function()
        return Agent.pick_target_player(game, player, 2015, target_candidates(game, player, 2015)) ~= nil
      end,
    },
    {
      id = 2016,
      cond = function()
        return Agent.pick_target_player(game, player, 2016, target_candidates(game, player, 2016)) ~= nil
      end,
    },
    {
      id = 2018,
      cond = function()
        return Agent.pick_target_player(game, player, 2018, target_candidates(game, player, 2018)) ~= nil
      end,
    },
  }

  for _, r in ipairs(rules) do
    local waiting = try_use(r.id, r.cond)
    if waiting then
      return waiting
    end
  end

  return try_use(2017) or try_use(2019)
end

function ItemEffects.steal_item_at_index(game, player, target, item_idx)
  return Steal.steal_item_at_index(game, player, target, item_idx, {
    item_name = ItemEffects.item_name,
    consume_item = ItemEffects.consume_item,
  })
end

function ItemEffects.handle_pass_players(game, player, encountered_ids, context)
  return Steal.handle_pass_players(game, player, encountered_ids, {
    item_name = ItemEffects.item_name,
    consume_item = ItemEffects.consume_item,
    services = (context and context.services) or (game and game.services),
  })
end

return ItemEffects
