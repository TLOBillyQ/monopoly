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

local function resolve_event_name(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function dispatch_intent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
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
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

function ItemChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local use_item = helpers.use_item
  local finish_item_phase = helpers.finish_item_phase
  local finish_active_item_phase = helpers.finish_active_item_phase

  local function finish_and_clear(game)
    finish_active_item_phase(game)
    return finish_choice(game, false)
  end

  local function open_steal_item_choice(game, stealer, target)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.items(target)) do
      local label = Inventory.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    dispatch_intent(game, {
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

  local function open_discard_item_choice(game, player, phase)
    local lines = {}
    local options = {}
    for i, it in ipairs(Inventory.items(player)) do
      local label = Inventory.item_name(it.id)
      table.insert(lines, i .. ". " .. label)
      table.insert(options, { id = i, label = label })
    end
    dispatch_intent(game, {
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

  local function reopen_item_phase(game, player, phase)
    local spec = ItemPhase.build_choice_spec(player, phase)
    assert(spec ~= nil, "missing item phase spec")
    dispatch_intent(game, { kind = "need_choice", choice_spec = spec })
    return { stay = true }
  end

  local function handle_demolish_target(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing demolish index")
    if meta.item_id then
      Inventory.consume(player, meta.item_id)
    end
    local res = Demolish.apply(game, player, idx, {
      services = game:get_services(),
      injure = meta.injure,
      title = meta.title
    })
    local intent = res.intent or {}
    dispatch_intent(game, intent)
    return finish_and_clear(game)
  end

  local function handle_roadblock_target(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(idx ~= nil, "missing roadblock index")
    if meta.item_id then
      Inventory.consume(player, meta.item_id)
    end
    local res = Roadblock.apply(game, player, idx)
    if res then
      dispatch_intent(game, res)
    end
    return finish_and_clear(game)
  end

  local function handle_steal_item(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local idx = tonumber(action.option_id)
    local meta = choice.meta
    local stealer = assert(game.players[meta.player_id], "missing stealer: " .. tostring(meta.player_id))
    local target = assert(game.players[meta.target_id], "missing target: " .. tostring(meta.target_id))
    assert(idx ~= nil, "missing steal index")
    local res = Steal.steal_item_at_index(game, stealer, target, idx)
    Logger.event("Steal choice result (multi)", res)
    assert(res ~= nil, "missing steal result")
    dispatch_intent(game, res.intent or {})
    return finish_and_clear(game)
  end

  local function handle_steal_prompt(game, choice, action)
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
      if Inventory.count(target) <= 0 then
        Inventory.consume(stealer, ITEM_IDS.steal)
        local res = Steal.steal_item_at_index(game, stealer, target, 1)
        assert(res ~= nil, "missing steal result")
        dispatch_intent(game, res.intent or {})
        return finish_choice(game, false)
      end
      if Inventory.count(target) <= 1 then
        local res = Steal.steal_item_at_index(game, stealer, target, 1)
        assert(res ~= nil, "missing steal result")
        dispatch_intent(game, res.intent or {})
        return finish_choice(game, false)
      end
      open_steal_item_choice(game, stealer, target)
      return { stay = true }
    end

    local next_index = meta.index + 1
    local queue = meta.queue
    if Inventory.find_index(stealer, ITEM_IDS.steal) and queue[next_index] then
      local spec = Steal.build_prompt_spec(game, stealer, queue, next_index)
      assert(spec ~= nil, "missing steal prompt spec")
      dispatch_intent(game, { kind = "need_choice", choice_spec = spec })
      return { stay = true }
    end

    return finish_choice(game, false)
  end

  local function handle_item_target_player(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local target_id = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    local item_id = assert(meta.item_id, "missing item_id")
    assert(target_id ~= nil, "missing target_id")
    local res = use_item(game, player, item_id, { target_id = target_id })
    assert(res ~= nil, "missing use_item result")
    if res.waiting then return { stay = true } end
    return finish_and_clear(game)
  end

  local function handle_remote_dice_value(game, choice, action)
    if is_cancel(action) then
      return finish_and_clear(game)
    end
    local value = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(value ~= nil, "missing dice value")
    local dice_count = meta.dice_count or player:dice_count()
    if meta.item_id then
      Inventory.consume(player, meta.item_id)
    end
    RemoteDice.apply(game, player, dice_count, value)
    return finish_and_clear(game)
  end

  local function handle_item_phase_choice(game, choice, action)
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
      open_discard_item_choice(game, player, phase)
      return { stay = true }
    end
    assert(item_id ~= nil, "missing item_id")

    local res = use_item(game, player, item_id)
    if type(res) == "table" and res.waiting then
      dispatch_intent(game, res.intent or {})
      return { stay = true }
    end
    finish_item_phase(game, phase)
    return finish_choice(game, false)
  end

  local function handle_discard_item(game, choice, action)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local phase = meta.phase
    if is_cancel(action) then
      finish_choice(game, false)
      return reopen_item_phase(game, player, phase)
    end
    local idx = tonumber(action.option_id)
    assert(idx ~= nil, "missing discard index")
    local dropped = assert(Inventory.remove_by_index(player, idx), "missing dropped item")
    Logger.event(player.name .. " 丢弃道具 " .. Inventory.item_name(dropped.id))
    finish_choice(game, false)
    return reopen_item_phase(game, player, phase)
  end

  return {
    item_phase_choice = handle_item_phase_choice,
    demolish_target = handle_demolish_target,
    roadblock_target = handle_roadblock_target,
    steal_item = handle_steal_item,
    steal_prompt = handle_steal_prompt,
    item_target_player = handle_item_target_player,
    remote_dice_value = handle_remote_dice_value,
    discard_item = handle_discard_item,
  }
end

return ItemChoiceHandler


