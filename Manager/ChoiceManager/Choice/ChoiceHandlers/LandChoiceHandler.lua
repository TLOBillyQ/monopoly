local LandChoiceSpecs = require("Manager.LandManager.Land.LandChoiceSpecs")
local Inventory = require("Manager.ItemManager.Item.ItemInventory")
local gameplay_constants = require("Config.GameplayConstants")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local LandChoiceHandler = {}
local ITEM_IDS = gameplay_constants.item_ids

local function resolve_event_name(kind)
  local intent = MONOPOLY_EVENT and MONOPOLY_EVENT.intent
  return kind and ((intent and intent[kind]) or kind) or nil
end

local function dispatch_intent(game, payload)
  local intent = payload and (payload.intent or payload) or nil
  if intent and intent.kind == "need_choice" and intent.choice_spec then
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
  if intent and intent.kind == "push_popup" and intent.payload then
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

function LandChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice
  local LandActions = require("Manager.LandManager.Land.LandActions")

  local function handle_rent_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id
    local tile_id = meta.tile_id
    local card_kind = meta.card_kind

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card and card_kind == "strong" then
      LandActions.execute_strong_card(game, player_id, tile_id)
    elseif use_card and card_kind == "free" then
      LandActions.execute_free_card(game, player_id, tile_id)
    else
      if card_kind == "strong" then
        local player = game.players[player_id]
        if Inventory.find_index(player, ITEM_IDS.free_rent) then
          dispatch_intent(game, {
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

  local function handle_tax_prompt(game, choice, action)
    local meta = choice.meta
    local player_id = meta.player_id

    local use_card = (action and action.option_id == "use") and not is_cancel(action)

    if use_card then
      LandActions.execute_tax_free_card(game, player_id)
    else
      LandActions.execute_pay_tax(game, player_id)
    end

    return finish_choice(game, false)
  end

  return {
    rent_card_prompt = handle_rent_prompt,
    tax_card_prompt = handle_tax_prompt,
  }
end

return LandChoiceHandler

