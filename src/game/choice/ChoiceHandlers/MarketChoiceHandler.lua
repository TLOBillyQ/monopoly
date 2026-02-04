local market_manager = require("src.game.market.MarketManager")
local monopoly_event = require("Config.MonopolyEvents")
local number_utils = require("src.core.NumberUtils")

local market_choice_handler = {}

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
    local event_name = monopoly_event.resolve_intent("need_choice")
    TriggerCustomEvent(event_name, { choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = monopoly_event.resolve_intent("push_popup")
    TriggerCustomEvent(event_name, { payload = intent.payload })
  end
end

function market_choice_handler.build(helpers)
  local is_cancel = helpers.is_cancel
  local finish_choice = helpers.finish_choice

  local function _handle_market_buy(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_buy", "invalid market choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    local product_id = number_utils.to_integer(action.option_id)
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    assert(product_id ~= nil, "missing product_id")
    local res = market_manager.buy_with_opts(game, player, product_id, nil)
    if type(res) == "table" then
      local intent = res.intent or {}
      _dispatch_intent(game, intent)
      return { stay = intent.kind == "need_choice" }
    end
    return finish_choice(game, false)
  end

  local function _handle_vehicle_replace(game, choice, action)
    assert(choice ~= nil and choice.kind == "market_vehicle_replace", "invalid vehicle replace choice")

    if is_cancel(action) then
      return finish_choice(game, false)
    end

    assert(action ~= nil, "missing action")
    local use = action.option_id == "use"
    local meta = choice.meta
    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    local product_id = assert(number_utils.to_integer(meta.product_id), "missing product_id")
    if use then
      market_manager.buy_with_opts(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = _handle_market_buy,
    market_vehicle_replace = _handle_vehicle_replace,
  }
end

return market_choice_handler
