local Inventory = require("Manager.ItemManager.ItemInventory")
local Demolish = require("Manager.ItemManager.ItemDemolish")
local Steal = require("Manager.ItemManager.ItemSteal")
local Roadblock = require("Manager.ItemManager.ItemRoadblock")
local Logger = require("Components.Logger")
local RemoteDice = require("Manager.ItemManager.ItemRemoteDice")
local ItemPhase = require("Manager.ItemManager.ItemPhase")
local GameplayRules = require("Config.GameplayRules")
local MonopolyEvent = require("Globals.MonopolyEvents")

local ItemChoiceHandler = {}
local ITEM_IDS = GameplayRules.item_ids

local function _ResolveEventName(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _DispatchIntent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:Get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:Set({ "turn", "choice_seq" }, seq)
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
    game.store:Set({ "turn", "pending_choice" }, entry)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _ResolveEventName("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function ItemChoiceHandler.Build(helpers)
  local is_cancel = helpers.IsCancel
  local finish_choice = helpers.FinishChoice
  local use_item = helpers.UseItem
  local finish_item_phase = helpers.FinishItemPhase
  local finish_active_item_phase = helpers.FinishActiveItemPhase

  local function _FinishAndClear(game)
    finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function _OpenStealItemChoice(game, stealer, target)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.Items(target)) do
      local label = Inventory.ItemName(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    _DispatchIntent(game, {
      kind = "need_choice",
      choice_spec = {
        kind = "steal_item",
        title = "选择要偷的道具",
        body_lines = lines,
        options = options,
        allow_cancel = true,
        cancel_label = "取消",
        meta = { player_id = stealer.id, target_id = target.id },
      },
    })
  end

  local function _OpenDiscardItemChoice(game, player, phase)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.Items(player)) do
      local label = Inventory.ItemName(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    _DispatchIntent(game, {
      kind = "need_choice",
      choice_spec = {
        kind = "discard_item",
        title = "选择要丢弃的道具",
        body_lines = lines,
        options = options,
        allow_cancel = true,
        cancel_label = "返回",
        meta = { player_id = player.id, phase = phase },
      },
    })
  end

  local function _ReopenItemPhase(game, player, phase)
    local spec = ItemPhase.BuildChoiceSpec(player, phase)
    assert(spec ~= nil, "missing item phase spec")
    _DispatchIntent(game, { kind = "need_choice", choice_spec = spec })
    return { stay = true }
  end

  local function _HandleDemolishTarget(game, choice, action)
    if is_cancel(action) then
      return _FinishAndClear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing demolish index")
    if meta.item_id then
      Inventory.Consume(player, meta.item_id)
    end
    local res = Demolish.Apply(game, player, idx, {
      services = game:GetServices(),
      injure = meta.injure,
      title = meta.title
    })
    local intent = res.intent or {}
    _DispatchIntent(game, intent)
    return _FinishAndClear(game)
  end

  local function _HandleRoadblockTarget(game, choice, action)
    if is_cancel(action) then
      return _FinishAndClear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing roadblock index")
    if meta.item_id then
      Inventory.Consume(player, meta.item_id)
    end
    local res = Roadblock.Apply(game, player, idx)
    if res then
      _DispatchIntent(game, res)
    end
    return _FinishAndClear(game)
  end

  local function _HandleStealItem(game, choice, action)
    if is_cancel(action) then
      return _FinishAndClear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local stealer = assert(game.players[meta.player_id], "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game.players[meta.target_id], "missing target: " .. tostring(meta.target_id))
    assert(idx ~= nil, "missing steal index")
    local res = Steal.StealItemAtIndex(game, stealer, target, idx)
    Logger.Event("Steal choice result (multi)", res)
    assert(res ~= nil, "missing steal result")
    _DispatchIntent(game, res.intent or {})
    return _FinishAndClear(game)
  end

  local function _HandleStealPrompt(game, choice, action)
    if is_cancel(action) then
      return finish_choice(game, false)
    end
    local meta = choice.meta
    local stealer = assert(game.players[meta.player_id], "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game.players[meta.target_id], "missing target: " .. tostring(meta.target_id))
    if target.eliminated then
      return finish_choice(game, false)
    end

    assert(action ~= nil, "missing action")
    if action.option_id == "use" then
      if Inventory.Count(target) <= 0 then
        Inventory.Consume(stealer, ITEM_IDS.steal)
        local res = Steal.StealItemAtIndex(game, stealer, target, 1)
        assert(res ~= nil, "missing steal result")
        _DispatchIntent(game, res.intent or {})
        return finish_choice(game, false)
      end
      if Inventory.Count(target) <= 1 then
        local res = Steal.StealItemAtIndex(game, stealer, target, 1)
        assert(res ~= nil, "missing steal result")
        _DispatchIntent(game, res.intent or {})
        return finish_choice(game, false)
      end
      _OpenStealItemChoice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if Inventory.FindIndex(stealer, ITEM_IDS.steal) and queue[next_index] then
      local spec = Steal.BuildPromptSpec(game, stealer, queue, next_index)
      assert(spec ~= nil, "missing steal prompt spec")
      _DispatchIntent(game, { kind = "need_choice", choice_spec = spec })
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  local function _HandleItemTargetPlayer(game, choice, action)
    if is_cancel(action) then
      return _FinishAndClear(game)
    end
    local target_id = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    local item_id = assert(meta.item_id, "missing item_id")
    assert(target_id ~= nil, "missing target_id")
    local res = use_item(game, player, item_id, { target_id = target_id })
    assert(res ~= nil, "missing use_item result")
    if res.waiting then return { stay = true } end
    return _FinishAndClear(game)
  end

  local function _HandleRemoteDiceValue(game, choice, action)
    if is_cancel(action) then
      return _FinishAndClear(game)
    end
    local value = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(value ~= nil, "missing dice value")
    local dice_count = meta.dice_count or player:DiceCount()
    if meta.item_id then
      Inventory.Consume(player, meta.item_id)
    end
    RemoteDice.Apply(game, player, dice_count, value)
    return _FinishAndClear(game)
  end

  local function _HandleItemPhaseChoice(game, choice, action)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local phase = meta.phase
    if is_cancel(action) then
      finish_item_phase(game, phase)
      return finish_choice(game, false)
    end
    local item_id = tonumber(action.option_id)
    if not item_id and action.option_id == "discard_item" then
      finish_choice(game, false)
      _OpenDiscardItemChoice(game, player, phase)
      return { stay = true }
    end
    assert(item_id ~= nil, "missing item_id")

    local res = use_item(game, player, item_id)
    if type(res) == "table" and res.waiting then
      _DispatchIntent(game, res.intent or {})
      return { stay = true }
    end
    finish_item_phase(game, phase)
    return finish_choice(game, false)
  end

  local function _HandleDiscardItem(game, choice, action)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local phase = meta.phase
    if is_cancel(action) then
      finish_choice(game, false)
      return _ReopenItemPhase(game, player, phase)
    end
    local idx = tonumber(action.option_id)
    assert(idx ~= nil, "missing discard index")
    local dropped = assert(Inventory.RemoveByIndex(player, idx), "missing dropped item")
    Logger.Event(player.name .. " 丢弃道具 " .. Inventory.ItemName(dropped.id))
    finish_choice(game, false)
    return _ReopenItemPhase(game, player, phase)
  end

  return {
    item_phase_choice = _HandleItemPhaseChoice,
    demolish_target = _HandleDemolishTarget,
    roadblock_target = _HandleRoadblockTarget,
    steal_item = _HandleStealItem,
    steal_prompt = _HandleStealPrompt,
    item_target_player = _HandleItemTargetPlayer,
    remote_dice_value = _HandleRemoteDiceValue,
    discard_item = _HandleDiscardItem,
  }
end

return ItemChoiceHandler


