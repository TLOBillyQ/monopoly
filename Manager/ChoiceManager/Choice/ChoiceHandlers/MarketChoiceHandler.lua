local MarketService = require("Manager.MarketManager.Market.MarketService")
local MonopolyEvent = require("Globals.MonopolyEvents")

local MarketChoiceHandler = {}

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

function MarketChoiceHandler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function handle_market_buy(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_buy", "invalid market choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local product_id = tonumber(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(product_id ~= nil, "missing product_id")
    local res = MarketService.buy_with_opts(game, player, product_id, nil)
    if type(res) == "table" then
      local intent = res.intent or {}
      dispatch_intent(game, intent)
      return { stay = intent.kind == "need_choice" }
    end
    return finish_choice(game, false)
  end

  local function handle_vehicle_replace(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_vehicle_replace", "invalid vehicle replace choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    assert(action ~= nil, "missing action")
    local use = action.option_id == "use"
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    local product_id = assert(tonumber(meta.product_id), "missing product_id")
    if use then
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
