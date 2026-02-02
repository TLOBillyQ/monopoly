local Logger = require("Components.Logger")
local ItemEffects = require("Manager.ItemManager.ItemPostEffects")
local Demolish = require("Manager.ItemManager.ItemDemolish")
local Roadblock = require("Manager.ItemManager.ItemRoadblock")
local RemoteDice = require("Manager.ItemManager.ItemRemoteDice")
local Agent = require("Manager.GameManager.Agent")
local GameplayRules = require("Config.GameplayRules")
local Inventory = require("Manager.ItemManager.ItemInventory")

local ItemRegistry = {}
local handlers = {}
local defaults_registered = false
local ITEM_IDS = GameplayRules.item_ids

ItemRegistry.handlers = handlers

function ItemRegistry.TargetCandidates(game, player, item_id)
  local spec = ItemEffects.GetTargetSpec(item_id)
  assert(spec ~= nil, "missing target spec: " .. tostring(item_id))

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

local function _RunItemChoiceFlow(game, player, item_id, context, opts)
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

local function _HandleTargetPlayerItem(game, player, item_id, context)
  return _RunItemChoiceFlow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player, inner_item_id)
      return ItemRegistry.TargetCandidates(inner_game, inner_player, inner_item_id)
    end,
    on_empty = function()
      Logger.Warn("没有可选择的目标玩家")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local target = Agent.PickTargetPlayer(inner_game, inner_player, inner_item_id, candidates)
      assert(target ~= nil, "missing target player")
      local ok = ItemEffects.ApplyTarget(inner_game, inner_player, inner_item_id, target)
      if ok then
        Inventory.Consume(inner_player, inner_item_id)
      end
      return ok
    end,
    choice_spec = function(_, inner_player, inner_item_id, candidates)
      local options = {}
      local body_lines = {}
      for _, t in ipairs(candidates) do
        local deity_text = ""
        if t.status.deity then
          deity_text = " 神:" .. t.status.deity.type
        end
        table.insert(body_lines, t.name .. " 现金:" .. t.cash .. deity_text)
        table.insert(options, { id = t.id, label = t.name })
      end
      return {
        kind = "item_target_player",
        title = Inventory.ItemName(inner_item_id) .. "：选择目标玩家",
        body_lines = body_lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { item_id = inner_item_id, player_id = inner_player.id },
      }
    end,
  })
end

local function _HandleRemoteDice(game, player, item_id, context)
  local dice_count = player:DiceCount()
  return _RunItemChoiceFlow(game, player, item_id, context, {
    candidates = function()
      return { 1, 2, 3, 4, 5, 6 }
    end,
    ai_select = function(inner_game, inner_player, inner_item_id)
      local value, target_tile = Agent.PickRemoteDiceValue(inner_game, inner_player, dice_count)
      assert(value ~= nil, "missing remote dice value")
      assert(Inventory.Consume(inner_player, inner_item_id) == true, "consume remote dice failed")
      local ok = RemoteDice.Apply(inner_game, inner_player, dice_count, value)
      if ok and target_tile then
        Logger.Event(inner_player.name .. " AI 设定遥控骰子前往 " .. target_tile.name .. " 点数 " .. value)
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

local function _HandleRoadblock(game, player, item_id, context)
  return _RunItemChoiceFlow(game, player, item_id, context, {
    candidates = function(inner_game, inner_player)
      return Roadblock.Candidates(inner_game, inner_player, 3)
    end,
    on_empty = function(_, inner_player)
      Logger.Warn(inner_player.name .. " 无可放置路障的位置")
    end,
    ai_select = function(inner_game, inner_player, inner_item_id, candidates)
      local best = Roadblock.PickBest(candidates)
      assert(best ~= nil and best.idx ~= nil, "missing roadblock target")
      local idx = best.idx
      assert(Inventory.Consume(inner_player, inner_item_id) == true, "consume roadblock failed")
      return Roadblock.Apply(inner_game, inner_player, idx)
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

local DEMOLISH_ITEMS = {
  [ITEM_IDS.monster] = { title = "怪兽卡", injure = false },
  [ITEM_IDS.missile] = { title = "导弹卡", injure = true },
}

local function _HandleDemolish(game, player, item_id, context)
  context = context or {}
  local cfg = assert(DEMOLISH_ITEMS[item_id], "missing demolish cfg: " .. tostring(item_id))
  return Demolish.Use(game, player, 3, Inventory.Consume, {
    item_id = item_id,
    injure = cfg.injure,
    title = cfg.title,
    by_ai = context.by_ai
  })
end

function ItemRegistry.Register(item_id, handler)
  handlers[item_id] = handler
end

function ItemRegistry.RegisterDefaults()
  if defaults_registered then
    return
  end
  defaults_registered = true

  ItemRegistry.Register(ITEM_IDS.remote_dice, _HandleRemoteDice)
  ItemRegistry.Register(ITEM_IDS.roadblock, _HandleRoadblock)
  ItemRegistry.Register(ITEM_IDS.monster, _HandleDemolish)
  ItemRegistry.Register(ITEM_IDS.missile, _HandleDemolish)

  for _, id in ipairs(ItemEffects.TargetItemIds()) do
    ItemRegistry.Register(id, _HandleTargetPlayerItem)
  end
end

return ItemRegistry


