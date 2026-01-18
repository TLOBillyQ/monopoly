local LandChoiceSpecs = {}

function LandChoiceSpecs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  local body = card_kind == "strong"
    and { "支付 " .. tostring(total_value) .. " 强制购入 " .. tile_name }
    or { "免除本次租金" }
  return {
    kind = "rent_card_prompt",
    title = card_kind == "strong" and "是否使用强征卡" or "是否使用免费卡",
    body_lines = body,
    options = {
      { id = "use", label = "使用" },
      { id = "skip", label = "放弃" },
    },
    allow_cancel = false,
    meta = { player_id = player_id, tile_id = tile_id, card_kind = card_kind },
  }
end

function LandChoiceSpecs.tax_prompt(player_id)
  return {
    kind = "tax_card_prompt",
    title = "是否使用免税卡",
    body_lines = { "使用免税卡可免除本次税金" },
    options = {
      { id = "use", label = "使用" },
      { id = "skip", label = "放弃" },
    },
    allow_cancel = false,
    meta = { player_id = player_id },
  }
end

return LandChoiceSpecs
