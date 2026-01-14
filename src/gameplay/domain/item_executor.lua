local constants = require("src.config.constants")
local logger = require("src.util.logger")
local UI = require("src.gameplay.ports.ui_port")
local Agent = require("src.gameplay.ai.agent")
local ItemEffects = require("src.gameplay.domain.item_post_effects")
local Demolish = require("src.gameplay.domain.item_demolish")
local Roadblock = require("src.gameplay.domain.item_roadblock")
local Steal = require("src.gameplay.domain.item_steal")
local Inventory = require("src.gameplay.domain.item_inventory")
local Strategy = require("src.gameplay.domain.item_strategy")

local Executor = {}

local function get_strategy(deps)
  return (deps and deps.strategy) or Strategy
end

local function get_inventory(deps)
  return (deps and deps.inventory) or Inventory
end

function Executor.apply_remote_dice(game, player, dice_count, value)
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


local function handle_target_player_item(game, player, item_id, context, deps)
  local strategy = get_strategy(deps)
  local inventory = get_inventory(deps)
  local candidates = strategy.target_candidates(game, player, item_id)

  if #candidates == 0 then
    logger.warn("没有可选择的目标玩家")
    return false
  end

  if context and context.by_ai then
    local target = strategy.pick_target_player(game, player, item_id, candidates)
    if not target then
      return false
    end
    local ok = ItemEffects.apply_target(game, player, item_id, target)
    if ok then
      inventory.consume(player, item_id)
    end
    return ok
  end

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
        title = inventory.item_name(item_id) .. "：选择目标玩家",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { item_id = item_id, user_id = player.id },
      },
    },
  }
end

local function handle_remote_dice(game, player, item_id, context, deps)
  local inventory = get_inventory(deps)
  local dice_count = player.seat_id and constants.dice_with_vehicle or constants.default_dice_count
  if context and context.by_ai then
    local value, target_tile = Agent.pick_remote_dice_value(game, player, dice_count)
    if not value then
      return false
    end
    if not inventory.consume(player, item_id) then
      return false
    end
    local ok = Executor.apply_remote_dice(game, player, dice_count, value)
    if ok and target_tile then
      logger.event(player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. value)
    end
    return ok
  end
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

local function handle_roadblock(game, player, item_id, context, deps)
  local inventory = get_inventory(deps)
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
    if not inventory.consume(player, item_id) then
      return false
    end
    return Roadblock.apply(game, player, idx)
  end

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

local function handle_monster(game, player, item_id, context, deps)
  local inventory = get_inventory(deps)
  return Demolish.use(game, player, 3, inventory.consume, {
    item_id = item_id,
    injure = false,
    title = "怪兽卡",
    by_ai = context and context.by_ai
  })
end

local function handle_missile(game, player, item_id, context, deps)
  local inventory = get_inventory(deps)
  return Demolish.use(game, player, 3, inventory.consume, {
    item_id = item_id,
    injure = true,
    title = "导弹卡",
    by_ai = context and context.by_ai
  })
end

local item_handlers = {
  [2002] = handle_remote_dice,
  [2004] = handle_roadblock,
  [2008] = handle_monster,
  [2013] = handle_missile,
}

for _, id in ipairs({ 2011, 2012, 2014, 2015, 2016, 2018 }) do
  item_handlers[id] = handle_target_player_item
end

function Executor.use_item(game, player, item_id, context, deps)
  context = context or {}
  deps = deps or {}
  local inventory = get_inventory(deps)
  if context.by_ai == nil then
    context.by_ai = Agent.is_auto_player(player)
  end
  local cfg = inventory.cfg(item_id)
  if not cfg then
    return false
  end

  local handler = item_handlers[item_id]
  if handler then
    return handler(game, player, item_id, context, deps)
  end

  local consumed = inventory.consume(player, item_id)
  if not consumed then
    return false
  end

  local res = ItemEffects.apply_post(game, player, item_id, context)
  if res ~= nil then
    return res
  end

  logger.warn("未实现的道具:" .. tostring(item_id))
  return false
end

return Executor
