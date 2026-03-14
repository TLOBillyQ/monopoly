local choice_session = require("src.rules.market.choice.session")
local intent_output_port = require("src.rules.ports.intent_output_port")

local outcome = {}

local function _dispatch_intent(game, intent)
  if type(intent) ~= "table" then
    return false
  end
  if intent.kind == "need_choice" and intent.choice_spec ~= nil then
    return intent_output_port.open_choice(game, intent.choice_spec, intent.opts) ~= nil
  end
  if intent.kind == "push_popup" and intent.payload ~= nil then
    return intent_output_port.push_popup(game, intent.payload, intent.popup_opts or intent.opts) == true
  end
  return false
end

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
      _dispatch_intent(game, {
        kind = "push_popup",
        payload = { title = "黑市", body = "卡槽已满，自动退出黑市" },
      })
      return finish_choice(game, false)
    end
    return { stay = true }
  end

  if type(result) == "table" then
    local intent = result.intent or {}
    _dispatch_intent(game, intent)
    if intent.kind == "need_choice" then
      return { stay = true }
    end
  end

  return finish_choice(game, false)
end

return outcome
