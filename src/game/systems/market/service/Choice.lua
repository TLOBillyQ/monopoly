local context = require("src.game.systems.market.service.Context")
local eligibility = require("src.game.systems.market.service.Eligibility")

local choice = {}

function choice.build(player, game)
  local options = {}
  local body_lines = {}
  local visible, buyable = eligibility.build_visible_entries(player, game, 10)
  for _, slot in ipairs(visible) do
    local entry = slot.entry
    local name = context.entry_name(entry)
    local price = context.entry_price(entry)
    local currency = context.entry_currency(entry)
    local label = name .. " - " .. price .. " " .. currency
    body_lines[#body_lines + 1] = label
    options[#options + 1] = { id = entry.product_id, label = label, can_buy = slot.can_buy }
  end

  if #buyable == 0 then
    return nil, {
      kind = "push_popup",
      payload = { title = "黑市", body = player.name .. " 暂无可购买商品" },
    }
  end

  return {
    kind = "market_buy",
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    meta = { player_id = player.id },
  }
end

return choice
