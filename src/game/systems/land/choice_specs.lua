local land_choice_specs = {}

local function _build_confirm_body(body_lines)
  if type(body_lines) ~= "table" or #body_lines == 0 then
    return "请再确认一次"
  end
  return table.concat(body_lines, "\n")
end

local function _build_use_skip(kind, title, body_lines, meta, labels)
  labels = labels or {}
  local owner_role_id = meta and meta.player_id or nil
  local skip_label = labels.skip or "放弃"
  return {
    kind = kind,
    owner_role_id = owner_role_id,
    route_key = "secondary_confirm",
    requires_confirm = true,
    title = title,
    body_lines = body_lines,
    options = {
      { id = "use", label = labels.use or "使用" },
      { id = "skip", label = skip_label },
    },
    allow_cancel = true,
    cancel_label = skip_label,
    confirm_title = labels.confirm_title or title,
    confirm_body = labels.confirm_body or _build_confirm_body(body_lines),
    meta = meta,
  }
end

land_choice_specs.build_use_skip = _build_use_skip

function land_choice_specs.rent_prompt(player_id, tile_id, card_kind, total_value, tile_name)
  if card_kind == "strong" then
    local choice = _build_use_skip(
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
  return _build_use_skip(
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
  local choice = _build_use_skip(
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
