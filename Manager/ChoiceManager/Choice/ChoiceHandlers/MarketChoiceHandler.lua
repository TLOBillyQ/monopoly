local MarketService = require("Manager.MarketManager.Market.MarketService")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local MarketChoiceHandler = {}

local function to_number(value)
  return tonumber(value)
end

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

function MarketChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function handle_market_buy(game, choice, action)
    if not choice or choice.kind ~= "market_buy" then
      return nil
    end

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local product_id = to_number(action.option_id)
    local meta = choice.meta
    local player = game.players[meta.player_id]
    if player and product_id then
      local res = MarketService.buy(game, player, product_id)
      if type(res) == "table" and res.intent then
        dispatch_intent(game, res.intent)
        return { stay = res.intent.kind == "need_choice" }
      end
    end
    return finish_choice(game, false)
  end

  local function handle_vehicle_replace(game, choice, action)
    if not choice or choice.kind ~= "market_vehicle_replace" then
      return nil
    end

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local use = action and action.option_id == "use"
    local meta = choice.meta
    local player = game.players[meta.player_id]
    local product_id = to_number(meta.product_id)
    if use and player and product_id then
      MarketService.buy_with_opts(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = handle_market_buy,
    market_vehicle_replace = handle_vehicle_replace,
  }
end

return MarketChoiceHandler
