local logger = require("src.core.utils.Logger")
local auto_play_port = require("src.game.ports.AutoPlayPort")
local item_effects = require("src.game.systems.items.ItemPostEffects")
local inventory = require("src.game.systems.items.ItemInventory")
local number_utils = require("src.core.utils.NumberUtils")
local roadblock = require("src.game.systems.items.ItemRoadblock")
local remote_dice = require("src.game.systems.items.ItemRemoteDice")
local demolish = require("src.game.systems.items.ItemDemolish")
local gameplay_rules = require("src.core.config.GameplayRules")
local action_anim_port = require("src.core.ports.ActionAnimPort")

local handlers = {}
local item_ids = gameplay_rules.item_ids
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

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
  return action_anim_port.queue(game, {
    kind = "item_target_player",
    player_id = user.id,
    target_player_id = target.id,
    item_id = item_id,
    item_name = inventory.item_name(item_id),
    duration = action_anim_duration,
  })
end

local function _apply_target_player_item(game, user, item_id, target, context)
  local apply_res = item_effects.apply_target(game, user, item_id, target, context)
  local ok = _resolve_apply_ok(apply_res)
  if not ok then
    return apply_res
  end
  if context.item_preconsumed ~= true then
    assert(inventory.consume(user, item_id) == true, "consume target item failed: " .. tostring(item_id))
  end
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

function handlers.handle_target_player_item(game, player, item_id, context)
  context = context or {}
  local resolve_candidates = context.resolve_target_candidates
  assert(resolve_candidates ~= nil, "missing resolve_target_candidates")
  if context.target_id then
    local target = game:find_player_by_id(context.target_id)
    if not target or target.id == player.id or target.eliminated then
      logger.warn("目标玩家无效:", tostring(context.target_id))
      return false
    end
    local candidates = resolve_candidates(game, player, item_id)
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
      return resolve_candidates(inner_game, inner_player, inner_item_id)
    end,
    on_empty = function()
      logger.warn("没有可选择的目标玩家")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local target = auto_play_port.pick_target_player(inner_game, inner_player, inner_item_id, candidates)
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
        route_key = "player",
        owner_role_id = inner_player.id,
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

function handlers.handle_remote_dice(game, player, item_id, context)
  local dice_count = game:player_dice_count(player)
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function()
      return { 1, 2, 3, 4, 5, 6 }
    end,
    ai_select = function(inner_game, inner_player, inner_item_id)
      local value, target_tile = auto_play_port.pick_remote_dice_value(inner_game, inner_player, dice_count)
      assert(value ~= nil, "missing remote dice value")
      assert(inventory.consume(inner_player, inner_item_id) == true, "consume remote dice failed")
      local ok = remote_dice.apply(inner_game, inner_player, dice_count, value)
      if ok and target_tile then
        logger.event(inner_player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. number_utils.format_integer_part(value))
      end
      return ok
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, value in ipairs(candidates) do
        table.insert(options, { id = value, label = tostring(value) })
        table.insert(body_lines, "点数 " .. number_utils.format_integer_part(value))
      end
      return {
        kind = "remote_dice_value",
        route_key = "remote",
        owner_role_id = inner_player.id,
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

function handlers.handle_roadblock(game, player, item_id, context)
  context = context or {}
  return _run_item_choice_flow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player, _, inner_context)
      if inner_context.by_ai then
        return roadblock.auto_candidates(inner_game, inner_player, 3)
      end
      return roadblock.ui_candidates(inner_game, inner_player, 3)
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
        route_key = "target",
        owner_role_id = inner_player.id,
        uses_target_picker = true,
        target_picker_owner_role_id = inner_player.id,
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

local function _build_demolish_payload(item_id)
  return assert(demolish_items[item_id], "missing demolish cfg: " .. tostring(item_id))
end

function handlers.handle_demolish(game, player, item_id, context)
  context = context or {}
  local cfg = _build_demolish_payload(item_id)
  return demolish.use(game, player, 3, inventory.consume, {
    item_id = item_id,
    injure = cfg.injure,
    title = cfg.title,
    by_ai = context.by_ai,
  })
end

return handlers
