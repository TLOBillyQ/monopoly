local inventory = require("src.rules.items.inventory")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local bankruptcy_port = require("src.rules.ports.bankruptcy")
local event_feed = require("src.rules.ports.event_feed")
local number_utils = require("src.foundation.number")
local achievement_progress = require("src.rules.ports.achievement_progress")
local angel_feedback = require("src.rules.items.angel_feedback")

local target_cash_effects = {}

local function _should_emit_share_wealth_cash_receive(context)
  local mode = context and context.share_wealth_cash_receive_mode or nil
  if mode == "item_target_player_only" then
    return false
  end
  return not (context and context.suppress_cash_receive_anim == true)
end

local function _apply_share_wealth_cash(game, user, target, deltas, next_values, should_emit)
  local user_delta = deltas.user
  local target_delta = deltas.target
  if should_emit and type(game.transfer_player_cash) == "function" then
    if user_delta < 0 then
      game:transfer_player_cash(user, target, -user_delta)
    elseif target_delta < 0 then
      game:transfer_player_cash(target, user, -target_delta)
    end
    return
  end
  if should_emit and type(game.add_player_cash) == "function" then
    game:add_player_cash(user, user_delta)
    game:add_player_cash(target, target_delta)
    return
  end
  game:set_player_cash(user, next_values.user)
  game:set_player_cash(target, next_values.target)
end

target_cash_effects.share_wealth = {
  apply = function(game, user, target, context)
    if game:angel_immune_to_item(target, item_ids.share_wealth) then
      angel_feedback.publish(game, target, "均富")
      return true
    end
    local user_cash = game:player_balance(user, "金币")
    local target_cash = game:player_balance(target, "金币")
    local total = user_cash + target_cash
    local half = math.floor(total / 2)
    local user_delta = half - user_cash
    local target_delta = (total - half) - target_cash
    local should_emit_cash_receive = _should_emit_share_wealth_cash_receive(context)
    _apply_share_wealth_cash(game, user, target, {
      user = user_delta,
      target = target_delta,
    }, {
      user = half,
      target = total - half,
    }, should_emit_cash_receive)
    if user_delta > 0 then
      achievement_progress.cash_received(game, user, user_delta)
    end
    if target_delta > 0 then
      achievement_progress.cash_received(game, target, target_delta)
    end
    event_feed.publish(game, {
      kind = event_kinds.equality_card,
      text = user.name .. " 使用均富卡，与 " .. target.name .. " 平分资金",
    })
    return true
  end,
}

target_cash_effects.tax = {
  apply = function(game, user, target)
    if game:angel_immune_to_item(target, item_ids.tax) then
      angel_feedback.publish(game, target, "查税")
      return true
    end
    local tax_free_idx = inventory.find_index(target, item_ids.tax_free)
    if tax_free_idx then
      inventory.remove_by_index(target, tax_free_idx)
      event_feed.publish(game, {
        kind = event_kinds.tax_immune,
        text = target.name .. " 使用免税卡抵消查税",
      })
      return true
    end
    local fee = math.floor(game:player_balance(target, "金币") * 0.5)
    game:deduct_player_cash(target, fee)
    achievement_progress.tax_paid(game, target, fee)
    event_feed.publish(game, {
      kind = event_kinds.tax_card,
      text = user.name .. " 使用查税卡，" .. target.name .. " 支付 " .. number_utils.format_integer_part(fee) .. " 税金",
    })
    if game:player_balance(target, "金币") <= 0 then
      bankruptcy_port.eliminate(game, target, { reason = target.name .. " 支付查税费用后破产" })
    end
    return true
  end,
}

return target_cash_effects

--[[ mutate4lua-manifest
version=2
projectHash=a92136bcaf4cf131
scope.0.id=chunk:src/rules/items/target_cash_effects.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=70e991f0995dec5f
scope.1.id=function:_should_emit_share_wealth_cash_receive:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=18
scope.1.semanticHash=2ce73e689ff694c0
scope.2.id=function:_apply_share_wealth_cash:20
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=38
scope.2.semanticHash=0c965c68b46c969a
scope.3.id=function:anonymous@41:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=71
scope.3.semanticHash=dcf1fb0236681d4a
scope.4.id=function:anonymous@75:75
scope.4.kind=function
scope.4.startLine=75
scope.4.endLine=100
scope.4.semanticHash=685b06b7d1c7520c
]]
