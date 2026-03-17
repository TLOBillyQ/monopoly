local use_skip_choice = require("src.rules.choices.use_skip_choice")
local context = require("src.rules.market.query.context")

local policy = {}

function policy.validate_entry(game, player, entry)
  local product_id = entry.product_id
  if not context.entry_vehicle_enabled(entry) then
    return {
      ok = false,
      reason = "vehicle_disabled",
      body = player.name .. " 当前对局已关闭载具功能",
    }
  end
  if not context.entry_market_enabled(entry) then
    return {
      ok = false,
      reason = "disabled",
      body = player.name .. " 该商品暂不可购买",
    }
  end
  local remaining = context.remaining_global_limit(game, product_id)
  if remaining <= 0 then
    return {
      ok = false,
      reason = "sold_out",
      body = player.name .. " 该商品已售罄",
    }
  end
  return { ok = true }
end

return policy
