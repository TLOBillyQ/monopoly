local items_cfg = require("Config.Generated.Items")
local gameplay_constants = require("Config.GameplayConstants")
local Agent = require("Manager.GameManager.Agent")
local Strategy = require("Manager.ItemManager.Item.ItemStrategy")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local Demolish = require("Manager.ItemManager.Item.ItemDemolish")
local Executor = require("Manager.ItemManager.Item.ItemExecutor")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local ItemPhase = {}

local cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  cfg_by_id[cfg.id] = cfg
end

local PHASE_TITLES = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

local function resolve_event_name(kind)
  if not kind then
    return nil
  end
  local intent = MONOPOLY_EVENT and MONOPOLY_EVENT.intent
  if intent and intent[kind] then
    return intent[kind]
  end
  return kind
end

local function dispatch_intent(game, payload)
  if not payload then
    return
  end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game and game.store, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:set({ "turn", "choice_seq" }, seq)
    local entry = {
      id = seq,
      kind = spec.kind,
      title = spec.title or "请选择",
      body_lines = spec.body_lines or {},
      options = spec.options or {},
      allow_cancel = spec.allow_cancel ~= false,
      cancel_label = spec.cancel_label or "取消",
      meta = spec.meta,
    }
    game.store:set({ "turn", "pending_choice" }, entry)
    if TriggerCustomEvent then
      local event_name = resolve_event_name("need_choice")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
      end
    end
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = game and game.ui_port
    if ui_port and ui_port.push_popup then
      ui_port:push_popup(intent.payload)
    end
    if TriggerCustomEvent then
      local event_name = resolve_event_name("push_popup")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
      end
    end
  end
end

function ItemPhase.is_enabled(game, phase)
  local queue = gameplay_constants.item_phase_queue
  if type(queue) ~= "table" then
    return true
  end
  for _, name in ipairs(queue) do
    if name == phase then
      return true
    end
  end
  return false
end

local function build_options(player, phase)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(Inventory.items(player)) do
    local cfg = cfg_by_id[it.id]
    local timing = cfg.timing
    if Strategy.timing_allowed(phase, timing, false) then
      table.insert(options, { id = it.id, label = cfg.name })
      local line = cfg.name
      if cfg.usage and #cfg.usage > 0 then
        line = line .. "：" .. cfg.usage
      end
      table.insert(body_lines, line)
    end
  end
  if Inventory.count(player) > 0 then
    table.insert(options, { id = "discard_item", label = "丢弃道具" })
    table.insert(body_lines, "丢弃道具：从背包丢弃一张")
  end
  return body_lines, options
end

function ItemPhase.finish(game, phase)
  local store = game.store
  store:set({ "turn", "item_phase", phase }, { done = true })
  local active = store:get({ "turn", "item_phase_active" })
  if active == phase then
    store:set({ "turn", "item_phase_active" }, nil)
  end
end

function ItemPhase.run(tm, phase, args)
  local game = tm.game
  local player = args.player or game:current_player()
  if not ItemPhase.is_enabled(game, phase) then
    return nil
  end

  local store = game.store
  local phase_state = store:get({ "turn", "item_phase", phase })
  if phase_state and phase_state.done then
    store:set({ "turn", "item_phase", phase }, nil)
    return nil
  end

  if Agent.is_auto_player(player) then
    local pre = Strategy.auto_pre_action(game, player, {
      inventory = Inventory,
      find_monster_target = Demolish.find_target,
      find_missile_target = Demolish.find_target,
      use_item = function(g, p, id, ctx)
        ctx = ctx or { by_ai = true }
        ctx.services = g:get_services()
        return Executor.use_item(g, p, id, ctx, { inventory = Inventory, strategy = Strategy })
      end,
    }, phase)
    if pre then
      dispatch_intent(game, pre)
    end
    if pre and pre.waiting then
      store:set({ "turn", "item_phase_active" }, phase)
      return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    if store:get({ "turn", "action_anim" }) then
      ItemPhase.finish(game, phase)
      return { waiting = true, wait_action_anim = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    ItemPhase.finish(game, phase)
    return nil
  end

  if game.ui_port == nil then
    ItemPhase.finish(game, phase)
    return nil
  end

  local spec = ItemPhase.build_choice_spec(player, phase)
  if not spec then
    ItemPhase.finish(game, phase)
    return nil
  end

  dispatch_intent(game, { kind = "need_choice", choice_spec = spec })

  store:set({ "turn", "item_phase", phase }, { active = true })
  store:set({ "turn", "item_phase_active" }, phase)

  return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
end

function ItemPhase.build_choice_spec(player, phase)
  local body_lines, options = build_options(player, phase)
  if #options == 0 then
    return nil
  end
  return {
    kind = "item_phase_choice",
    title = PHASE_TITLES[phase] or "使用道具？",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = { player_id = player.id, phase = phase },
  }
end

return ItemPhase

