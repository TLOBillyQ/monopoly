local logger = require("src.core.Logger")
local item_effects = require("src.game.item.ItemPostEffects")
local demolish = require("src.game.item.ItemDemolish")
local roadblock = require("src.game.item.ItemRoadblock")
local remote_dice = require("src.game.item.ItemRemoteDice")
local agent = require("src.game.game.Agent")
local gameplay_rules = require("Config.GameplayRules")
local inventory = require("src.game.item.ItemInventory")
local number_utils = require("src.core.NumberUtils")

local item_registry = {}
local handlers = {}
local defaults_registered = false
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

item_registry.handlers = handlers

function item_registry.target_candidates(game, player, item_id)
  local spec = item_effects.get_target_spec(item_id)
  assert(spec ~= nil, "missing target spec: " .. tostring(item_id))

  if spec.require_user and not spec.require_user(game, player) then
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

local function _resolve_apply_ok(res)
  if type(res) == "table" then
    if type(res.ok) == "boolean" then
      return res.ok
    end
    return true
  end
  return res == true
end

local function _queue_target_player_anim(game, user, item_id, target)
  local ui_port = game.ui_port
  if not (ui_port and ui_port.wait_action_anim) then
    return false
  end
  game:queue_action_anim({
    kind = "item_target_player",
    player_id = user.id,
    target_player_id = target.id,
    item_id = item_id,
    item_name = inventory.item_name(item_id),
    duration = action_anim_duration,
  })
  return true
end

local function _apply_target_player_item(game, user, item_id, target, context)
  local apply_res = item_effects.apply_target(game, user, item_id, target, context)
  local ok = _resolve_apply_ok(apply_res)
  if not ok then
    return apply_res
  end
  assert(inventory.consume(user, item_id) == true, "consume target item failed: " .. tostring(item_id))
  local queued = _queue_target_player_anim(game, user, item_id, target)
  if type(apply_res) == "table" then
    apply_res.ok = true
    if queued then
      apply_res.action_anim = true
    end
    return apply_res
  end
  return { ok = true, action_anim = queued }
end

local function _run_item_choice_flow(game, player, item_id, context, opts)
  context = context or {}
  local candidates = assert(opts.candidates(game, player, item_id, context), "missing candidates")
  if #candidates == 0 then
    if opts.on_empty then
      opts.on_empty(game, player, item_id, context)
    end
    return false
  end

  if context.by_ai then
    assert(opts.ai_select ~= nil, "missing ai_select")
    return opts.ai_select(game, player, item_id, candidates, context)
  end

  assert(opts.choice_spec ~= nil, "missing choice_spec")
  local choice_spec = assert(opts.choice_spec(game, player, item_id, candidates, context), "missing choice_spec")
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = choice_spec,
    },
  }
end

local function _handle_target_player_item(game, player, item_id, context)
  context = context or {}
  if context.target_id then
    local target = game.players[context.target_id]
    if not target or target.id == player.id or target.eliminated then
      logger.warn("目标玩家无效:", tostring(context.target_id))
      return false
    end
    local candidates = item_registry.target_candidates(game, player, item_id)
    local matched = false
    for _, cand in ipairs(candidates) do
      if cand.id == target.id then
        matched = true
        break
      end
    end
    if not matched then
      logger.warn("目标玩家不在可选列表中:", tostring(context.target_id))
      return false
    end
    return _apply_target_player_item(game, player, item_id, target, context)
  end

  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player, inner_item_id)
      return item_registry.target_candidates(inner_game, inner_player, inner_item_id)
    end,
    on_empty = function()
      logger.warn("没有可选择的目标玩家")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local target = agent.pick_target_player(inner_game, inner_player, inner_item_id, candidates)
      assert(target ~= nil, "missing target player")
      return _apply_target_player_item(inner_game, inner_player, inner_item_id, target, context)
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, t in ipairs(candidates) do
        local deity_text = ""
        if t.status.deity then
          deity_text = " 神:" .. t.status.deity.type
        end
        local cash_text = number_utils.format_integer_part(game:player_balance(t, "金币"))
        table.insert(body_lines, t.name .. " 现金:" .. cash_text .. deity_text)
        table.insert(options, { id = t.id, label = t.name })
      end
      return {
        kind = "item_target_player",
        title = inventory.item_name(inner_item_id) .. "：选择目标玩家",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { item_id = inner_item_id, player_id = inner_player.id },
      }
    end,
  })
end

local function _handle_remote_dice(game, player, item_id, context)
  local dice_count = game:player_dice_count(player)
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function()
      return { 1, 2, 3, 4, 5, 6 }
    end,
    ai_select = function(inner_game, inner_player, inner_item_id)
      local value, target_tile = agent.pick_remote_dice_value(inner_game, inner_player, dice_count)
      assert(value ~= nil, "missing remote dice value")
      assert(inventory.consume(inner_player, inner_item_id) == true, "consume remote dice failed")
      local ok = remote_dice.apply(inner_game, inner_player, dice_count, value)
      if ok and target_tile then
        logger.event(inner_player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. value)
      end
      return ok
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, value in ipairs(candidates) do
        table.insert(options, { id = value, label = tostring(value) })
        table.insert(body_lines, "点数 " .. value)
      end
      return {
        kind = "remote_dice_value",
        title = "遥控骰子：选择点数",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { player_id = inner_player.id, item_id = inner_item_id, dice_count = dice_count },
      }
    end,
  })
end

local function _handle_roadblock(game, player, item_id, context)
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player)
      return roadblock.candidates(inner_game, inner_player, 3)
    end,
    on_empty = function(_, inner_player)
      logger.warn(inner_player.name .. " 无可放置路障的位置")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local best = roadblock.pick_best(candidates)
      assert(best ~= nil and best.idx ~= nil, "missing roadblock target")
      local idx = best.idx
      assert(inventory.consume(inner_player, inner_item_id) == true, "consume roadblock failed")
      return roadblock.apply(inner_game, inner_player, idx)
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, cand in ipairs(candidates) do
        table.insert(options, { id = cand.idx, label = cand.label })
        table.insert(body_lines, cand.label)
      end
      return {
        kind = "roadblock_target",
        title = "路障卡：选择位置",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "放弃",
        meta = { player_id = inner_player.id, item_id = inner_item_id },
      }
    end,
  })
end

local demolish_items = {
  [item_ids.monster] = { title = "怪兽卡", injure = false },
  [item_ids.missile] = { title = "导弹卡", injure = true },
}

local function _handle_demolish(game, player, item_id, context)
  context = context or {}
  local cfg = assert(demolish_items[item_id], "missing demolish cfg: " .. tostring(item_id))
  return demolish.use(game, player, 3, inventory.consume, {
    item_id = item_id,
    injure = cfg.injure,
    title = cfg.title,
    by_ai = context.by_ai
  })
end

function item_registry.register(item_id, handler)
  handlers[item_id] = handler
end

function item_registry.register_defaults()
  if defaults_registered then
    return
  end
  defaults_registered = true

  item_registry.register(item_ids.remote_dice, _handle_remote_dice)
  item_registry.register(item_ids.roadblock, _handle_roadblock)
  item_registry.register(item_ids.monster, _handle_demolish)
  item_registry.register(item_ids.missile, _handle_demolish)

  for _, id in ipairs(item_effects.target_item_ids()) do
    item_registry.register(id, _handle_target_player_item)
  end
end

return item_registry
