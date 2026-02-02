local LandChoiceSpecs = require("Manager.LandManager.LandChoiceSpecs")
local Inventory = require("Manager.ItemManager.ItemInventory")
local GameplayRules = require("Config.GameplayRules")
local MonopolyEvent = require("Globals.MonopolyEvents")

local LandChoiceHandler = {}
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

function LandChoiceHandler.Build(helpers)
  local is_cancel = helpers.IsCancel
  local finish_choice = helpers.FinishChoice
  local LandActions = require("Manager.LandManager.LandActions")

  local function _HandleRentPrompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind

    assert(action ~= nil, "missing action")
    local use_card = (action.option_id == "use") and not is_cancel(action)

    if use_card and card_kind == "strong" then
      LandActions.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      LandActions.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = game.players[player_id]
        if Inventory.find_index(player, ITEM_IDS.free_rent) then
          _DispatchIntent(game, {
            kind = "need_choice",
            choice_spec = LandChoiceSpecs.rent_prompt(player_id, tile_id, "free"),
          })
          return { stay = true }
        end
      end
      LandActions.execute_pay_rent(game, player_id, tile_id)
    end

    return finish_choice(game, false)
  end

  local function _HandleTaxPrompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id

    assert(action ~= nil, "missing action")
    local use_card = (action.option_id == "use") and not is_cancel(action)

    if use_card then
      LandActions.execute_tax_free_card(game, player_id)
    else
      LandActions.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = _HandleRentPrompt,
    tax_card_prompt = _HandleTaxPrompt,
  }
end

return LandChoiceHandler

