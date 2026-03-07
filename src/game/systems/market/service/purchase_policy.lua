local land_choice_specs = require("src.game.systems.land.land_choice_specs")
local context = require("src.game.systems.market.service.context")

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

function policy.build_vehicle_replace_intent(player, entry, price, currency)
  local current_name = context.vehicle_name(player.seat_id)
  local next_name = context.entry_name(entry)
  return {
    kind = "need_choice",
    choice_spec = land_choice_specs.build_use_skip(
      "market_vehicle_replace",
      "是否更换座驾",
      {
        "当前座驾：" .. current_name,
        "新座驾：" .. next_name,
        "价格：" .. tostring(price) .. " " .. currency,
      },
      { player_id = player.id, product_id = entry.product_id },
      { use = "更换", skip = "算了" }
    ),
  }
end

return policy
