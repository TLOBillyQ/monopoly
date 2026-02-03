local ItemsCfg = require("Config.Generated.Items")
local GameplayRules = require("Config.GameplayRules")
local Agent = require("src.game.game.Agent")
local Strategy = require("src.game.item.ItemStrategy")
local Inventory = require("src.game.item.ItemInventory")
local MonopolyEvent = require("src.game.MonopolyEvents")

local ItemPhase = {}

local cfg_by_id = {}
for _, cfg in ipairs(ItemsCfg) do
  cfg_by_id[cfg.id] = cfg
end

local PHASE_TITLES = {
  pre_action = "行动前：使用道具？",
  pre_move = "投骰后：使用道具？",
  post_action = "行动后：使用道具？",
}

local function _ResolveEventName(kind)
  local intent = MonopolyEvent.intent
  assert(kind ~= nil, "missing intent kind")
  return intent[kind] or kind
end

local function _DispatchIntent(game, payload)
  assert(payload ~= nil, "missing intent payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" then
    assert(intent.choice_spec ~= nil, "missing choice spec")
    assert(game and game.store, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:Get({ "turn", "choice_seq" })
    seq = seq + 1
    game.store:Set({ "turn", "choice_seq" }, seq)
    local entry = {
      id = seq,
      kind = spec.kind,
      title = spec.title,
      body_lines = spec.body_lines,
      options = spec.options,
      allow_cancel = spec.allow_cancel,
      cancel_label = spec.cancel_label,
      meta = spec.meta,
    }
    game.store:Set({ "turn", "pending_choice" }, entry)
    local event_name = _ResolveEventName("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" then
    assert(intent.payload ~= nil, "missing popup payload")
    local ui_port = game.ui_port
    assert(ui_port ~= nil and ui_port.push_popup ~= nil, "missing ui_port")
    ui_port:PushPopup(intent.payload)
    local event_name = _ResolveEventName("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function ItemPhase.IsEnabled(game, phase)
  local queue = GameplayRules.item_phase_queue
  assert(type(queue) == "table", "invalid item_phase_queue")
  for _, name in ipairs(queue) do
    if name == phase then
      return true
    end
  end
  return false
end

local function _BuildOptions(player, phase)
  local options = {}
  local body_lines = {}
  for _, it in ipairs(Inventory.Items(player)) do
    local cfg = cfg_by_id[it.id]
    local timing = cfg.timing
    if Strategy.TimingAllowed(phase, timing, false) then
      table.insert(options, { id = it.id, label = cfg.name })
      local line = cfg.name
      if cfg.usage and #cfg.usage > 0 then
        line = line .. "：" .. cfg.usage
      end
      table.insert(body_lines, line)
    end
  end
  if Inventory.Count(player) > 0 then
    table.insert(options, { id = "discard_item", label = "丢弃道具" })
    table.insert(body_lines, "丢弃道具：从背包丢弃一张")
  end
  return body_lines, options
end

function ItemPhase.Finish(game, phase)
  local store = game.store
  store:Set({ "turn", "item_phase", phase }, { done = true })
  local active = store:Get({ "turn", "item_phase_active" })
  if active == phase then
    store:Set({ "turn", "item_phase_active" }, "")
  end
end

function ItemPhase.Run(tm, phase, args)
  local game = tm.game
  local player = args.player
  assert(player ~= nil, "missing player")
  if not ItemPhase.IsEnabled(game, phase) then
    return nil
  end

  local store = game.store
  local phase_state = store:Get({ "turn", "item_phase", phase })
  if phase_state and phase_state.done then
    store:Set({ "turn", "item_phase", phase }, nil)
    return nil
  end

  if Agent.IsAutoPlayer(player) then
    local pre = Strategy.AutoPreAction(game, player, phase)
    if pre then
      _DispatchIntent(game, pre)
    end
    if pre and pre.waiting then
      store:Set({ "turn", "item_phase_active" }, phase)
      return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    if store:Get({ "turn", "action_anim" }) then
      ItemPhase.Finish(game, phase)
      return { waiting = true, wait_action_anim = true, resume_state = args.resume_state, resume_args = args.resume_args }
    end
    ItemPhase.Finish(game, phase)
    return nil
  end

  assert(game.ui_port ~= nil, "missing ui_port")

  local spec = ItemPhase.BuildChoiceSpec(player, phase)
  assert(spec ~= nil, "missing choice spec")

  _DispatchIntent(game, { kind = "need_choice", choice_spec = spec })

  store:Set({ "turn", "item_phase", phase }, { active = true })
  store:Set({ "turn", "item_phase_active" }, phase)

  return { waiting = true, resume_state = args.resume_state, resume_args = args.resume_args }
end

function ItemPhase.BuildChoiceSpec(player, phase)
  local body_lines, options = _BuildOptions(player, phase)
  assert(#options > 0, "missing item options")
  return {
    kind = "item_phase_choice",
    title = PHASE_TITLES[phase],
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = { player_id = player.id, phase = phase },
  }
end

return ItemPhase

