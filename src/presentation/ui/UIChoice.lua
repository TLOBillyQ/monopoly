local choice = {}

local function _join_lines(lines)
  assert(lines ~= nil, "missing body lines")
  return table.concat(lines, "\n")
end

local function _default_option_label(opt)
  assert(opt ~= nil, "missing option")
  if opt.label then
    return opt.label
  end
  local id = opt.id
  if type(id) ~= "nil" then
    return tostring(id)
  end
  return tostring(opt)
end

local function _build_phase_label(phase)
  if phase == "pre_action" then
    return "行动前"
  end
  if phase == "pre_move" then
    return "投骰后"
  end
  if phase == "post_action" then
    return "行动后"
  end
  return phase
end

local function _build_phase_title(game, base_title)
  assert(game ~= nil, "missing game")
  assert(base_title ~= nil, "missing base title")
  local phase_name = game.turn.item_phase_active
  if not phase_name or phase_name == "" then
    return base_title
  end
  local label = _build_phase_label(phase_name)
  return "[" .. label .. "] " .. base_title
end

function choice.build_choice_view(pending, opts)
  assert(pending ~= nil, "missing pending choice")
  opts = opts or {}
  local option_label = opts.option_label or _default_option_label
  local title = _build_phase_title(opts.game, pending.title or "请选择")
  local body = ""
  if pending.body_lines then
    body = _join_lines(pending.body_lines)
  elseif not opts.body_lines_only and pending.body then
    body = pending.body
  end

  local options = {}
  for _, opt in ipairs(pending.options or {}) do
    local label = option_label(opt)
    assert(label ~= nil, "missing option label")
    table.insert(options, {
      label = label,
      id = opt.id or opt,
      raw = opt,
      can_buy = opt.can_buy,
    })
  end

  return {
    title = title,
    body = body,
    options = options,
    cancel_label = pending.cancel_label or "取消",
    allow_cancel = pending.allow_cancel ~= false,
  }
end

return choice
