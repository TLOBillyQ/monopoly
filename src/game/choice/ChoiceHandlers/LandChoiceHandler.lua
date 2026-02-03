local land_choice_specs = require("src.game.land.LandChoiceSpecs")
local inventory = require("src.game.item.ItemInventory")
local gameplay_rules = require("Config.GameplayRules")
local monopoly_event = require("src.game.MonopolyEvents")

local land_choice_handler = {}
local item_ids = gameplay_rules.item_ids

local function _resolve_event_name(kind)
  assert(monopoly_event ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(monopoly_event.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _dispatch_intent(game, payload)
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
    local event_name = _resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { payload = intent.payload })
  end
end

function land_choice_handler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local land_actions = require("src.game.land.LandActions")

  local function _handle_rent_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind

    assert(action ~= nil, "missing action")
    local use_card = (action.option_id == "use") and not is_cancel(action)

    if use_card and card_kind == "strong" then
      land_actions.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      land_actions.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = game.players[player_id]
        if inventory.find_index(player, item_ids.free_rent) then
          _dispatch_intent(game, {
            kind = "need_choice",
            choice_spec = land_choice_specs.rent_prompt(player_id, tile_id, "free"),
          })
          return { stay = true }
        end
      end
      land_actions.execute_pay_rent(game, player_id, tile_id)
    end

    return finish_choice(game, false)
  end

  local function _handle_tax_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id

    assert(action ~= nil, "missing action")
    local use_card = (action.option_id == "use") and not is_cancel(action)

    if use_card then
      land_actions.execute_tax_free_card(game, player_id)
    else
      land_actions.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = _handle_rent_prompt,
    tax_card_prompt = _handle_tax_prompt,
  }
end

return land_choice_handler

