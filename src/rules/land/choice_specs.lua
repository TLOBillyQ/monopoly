local use_skip_choice = require("src.rules.choices.use_skip_choice")

local land_choice_specs = {}

function land_choice_specs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  if card_kind == "strong" then
    local choice = use_skip_choice.build(
      "rent_card_prompt",
      "是否使用强征卡",
      { "支付 " .. tostring(total_value) .. " 强制购入 " .. tile_name },
      { player_id = player_id, tile_id = tile_id, card_kind = card_kind },
      { skip = "不用" }
    )
    choice.route_key = "secondary_confirm"
    choice.requires_confirm = true
    choice.allow_cancel = true
    choice.cancel_label = "不用"
    choice.confirm_title = "强征卡"
    choice.confirm_body = "支付 " .. tostring(total_value) .. " 强制购入 " .. tile_name
    return choice
  end
  return use_skip_choice.build(
    "rent_card_prompt",
    "是否使用免费卡",
    { "免除本次租金" },
    { player_id = player_id, tile_id = tile_id, card_kind = card_kind },
    {
      skip = "不用",
      confirm_title = "免费卡",
      confirm_body = "这次要用免费卡吗？",
    }
  )
end

function land_choice_specs.tax_prompt(player_id)
  local choice = use_skip_choice.build(
    "tax_card_prompt",
    "是否使用免税卡",
    { "使用免税卡可免除本次税金" },
    { player_id = player_id },
    { skip = "不用" }
  )
  choice.allow_cancel = true
  choice.cancel_label = "不用"
  choice.route_key = "secondary_confirm"
  choice.requires_confirm = true
  choice.confirm_title = "税务局"
  choice.confirm_body = "这次要用免税卡吗？"
  return choice
end

return land_choice_specs
