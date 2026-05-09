local use_skip_choice = {}

local function _build_confirm_body(body_lines)
  if type(body_lines) ~= "table" or #body_lines == 0 then
    return "请再确认一次"
  end
  return table.concat(body_lines, "\n")
end

function use_skip_choice.build(kind, title, body_lines, meta, labels)
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

return use_skip_choice
