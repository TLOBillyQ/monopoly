local LandChoiceSpecs = {}

local function build_use_skip(kind, title, body_lines, meta, labels)
  labels = labels or {}
  return {
    kind = kind,
    title = title,
    body_lines = body_lines,
    options = {
      { id = "use", label = labels.use or "使用" },
      { id = "skip", label = labels.skip or "放弃" },
    },
    allow_cancel = false,
    meta = meta,
  }
end

LandChoiceSpecs.build_use_skip = build_use_skip

function LandChoiceSpecs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  local body = nil
  local title = nil
  if card_kind == "strong" then
    body = { "支付 " .. tostring(total_value) .. " 强制购入 " .. tile_name }
    title = "是否使用强征卡"
  else
    body = { "免除本次租金" }
    title = "是否使用免费卡"
  end
  return build_use_skip(
    "rent_card_prompt",
    title,
    body,
    { player_id = player_id, tile_id = tile_id, card_kind = card_kind }
  )
end

function LandChoiceSpecs.tax_prompt(player_id)
  return build_use_skip(
    "tax_card_prompt",
    "是否使用免税卡",
    { "使用免税卡可免除本次税金" },
    { player_id = player_id }
  )
end

return LandChoiceSpecs