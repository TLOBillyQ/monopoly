local land_choice_specs = {}

local function _build_use_skip(kind, title, body_lines, meta, labels)
  labels = labels or {}
  local owner_role_id = meta and meta.player_id or nil
  return {
    kind = kind,
    owner_role_id = owner_role_id,
    route_key = "base_inline",
    requires_confirm = false,
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

land_choice_specs.build_use_skip = _build_use_skip

function land_choice_specs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  local body = nil
  local title = nil
  if card_kind == "strong" then
    body = { "支付 " .. tostring(total_value) .. " 强制购入 " .. tile_name }
    title = "是否使用强征卡"
  else
    body = { "免除本次租金" }
    title = "是否使用免费卡"
  end
  return _build_use_skip(
    "rent_card_prompt",
    title,
    body,
    { player_id = player_id, tile_id = tile_id, card_kind = card_kind }
  )
end

function land_choice_specs.tax_prompt(player_id)
  local choice = _build_use_skip(
    "tax_card_prompt",
    "是否使用免税卡",
    { "使用免税卡可免除本次税金" },
    { player_id = player_id }
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
