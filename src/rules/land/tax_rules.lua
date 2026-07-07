local constants = require("src.config.content.constants")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local use_broadcast = require("src.rules.items.use_broadcast")
local achievement_progress = require("src.rules.ports.achievement_progress")
local number_utils = require("src.foundation.number")

local tax_rules = {}

local function _build_land_event(event_key, payload, extra)
  local result = {
    ok = true,
    event = event_key,
    payload = payload,
  }
  if extra then
    for key, value in pairs(extra) do
      result[key] = value
    end
  end
  return result
end

function tax_rules.execute_tax_free_card(game, player_id)
  local player = game:find_player_by_id(player_id)
  assert(inventory.consume(player, item_ids.tax_free) == true, "consume tax_free failed")
  achievement_progress.item_used(game, player)
  use_broadcast.dispatch(game, player, item_ids.tax_free)
  return _build_land_event("tax_free", {
    player = player,
    text = player.name .. " 出示免税卡，本次免税",
  })
end

function tax_rules.execute_pay_tax(game, player_id)
  local player = game:find_player_by_id(player_id)
  local cash = game:player_cash(player)
  local fee = math.floor(cash * constants.tax_rate)
  if cash < fee then fee = cash end

  game:deduct_player_cash(player, fee)
  achievement_progress.tax_paid(game, player, fee)
  local result = _build_land_event("tax_paid", {
    player = player,
    amount = fee,
    text = player.name .. " 在税务局支付税金 " .. number_utils.format_integer_part(fee),
  })
  if game:player_cash(player) <= 0 then
    result.bankrupt_reason = player.name .. " 支付税金后破产"
  end
  return result
end

return tax_rules
