local market_service = require("src.game.systems.market.MarketService")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")
local number_utils = require("src.core.NumberUtils")
local market_context = require("src.game.systems.market.service.Context")

local market_choice_handler = {}

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
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    assert(product_id ~= nil, "missing product_id")
    local entry = market_context.entry_by_id(product_id)
    assert(entry ~= nil, "missing market entry: " .. tostring(product_id))
    local res = market_service.purchase.execute(game, player, product_id, nil)
    if entry.kind == "item" and type(res) == "table" and res.ok == true and res.fulfilled_now == true then
      if res.inventory_full_after == true then
        intent_dispatcher.dispatch(game, {
          kind = "push_popup",
          payload = { title = "黑市", body = "卡槽已满，自动退出黑市" },
        })
        return finish_choice(game, false)
      end
      local active_tab = choice.active_tab or (meta and meta.active_tab) or nil
      local page_index = choice.page_index or (meta and meta.page_index) or nil
      local spec = market_service.choice.build(player, game, {
        active_tab = active_tab,
        page_index = page_index,
      })
      choice.title = spec.title
      choice.body_lines = spec.body_lines
      choice.options = spec.options
      choice.allow_cancel = spec.allow_cancel
      choice.cancel_label = spec.cancel_label
      choice.active_tab = spec.active_tab
      choice.page_index = spec.page_index
      choice.page_count = spec.page_count
      choice.meta = spec.meta
      game.dirty.turn = true
      game.dirty.any = true
      return { stay = true }
    end
    if type(res) == "table" then
      local intent = res.intent or {}
      intent_dispatcher.dispatch(game, intent)
      if intent.kind == "need_choice" then
        return { stay = true }
      end
      return finish_choice(game, false)
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
    local player = assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
    local product_id = assert(number_utils.to_integer(meta.product_id), "missing product_id")
    if use then
      market_service.purchase.execute(game, player, product_id, { skip_vehicle_prompt = true })
    end
    return finish_choice(game, false)
  end

  return {
    market_buy = _handle_market_buy,
    market_vehicle_replace = _handle_vehicle_replace,
  }
end

return market_choice_handler
