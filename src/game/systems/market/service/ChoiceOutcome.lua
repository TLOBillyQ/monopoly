local choice_session = require("src.game.systems.market.service.ChoiceSession")
local intent_dispatcher = require("src.game.flow.intent.IntentDispatcher")

local outcome = {}

local function _should_keep_market_open(entry, result)
  if type(result) ~= "table" or result.ok ~= true then
    return false
  end
  if result.deferred_fulfillment == true then
    return true
  end
  return entry and entry.kind == "item" and result.fulfilled_now == true
end

function outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  assert(type(finish_choice) == "function", "missing finish_choice")

  if _should_keep_market_open(entry, result) then
    local rebuilt = choice_session.rebuild_pending(game, choice, player)
    if not rebuilt then
      return finish_choice(game, false)
    end
    if entry
        and entry.kind == "item"
        and result.fulfilled_now == true
        and result.inventory_full_after == true then
      intent_dispatcher.dispatch(game, {
        kind = "push_popup",
        payload = { title = "黑市", body = "卡槽已满，自动退出黑市" },
      })
      return finish_choice(game, false)
    end
    return { stay = true }
  end

  if type(result) == "table" then
    local intent = result.intent or {}
    intent_dispatcher.dispatch(game, intent)
    if intent.kind == "need_choice" then
      return { stay = true }
    end
  end

  return finish_choice(game, false)
end

return outcome
