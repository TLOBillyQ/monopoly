local Phase = require("src.ui.UIPhase")

local Choice = {}

local function _JoinLines(lines)
  assert(lines ~= nil, "missing body lines")
  return table.concat(lines, "\n")
end

local function _DefaultOptionLabel(opt)
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

function Choice.BuildChoiceView(pending, opts)
  assert(pending ~= nil, "missing pending choice")
  opts = opts or {}
  local option_label = opts.option_label or _DefaultOptionLabel
  local title = Phase.BuildPhaseTitle(opts.game, pending.title or "请选择")
  local body = ""
  if pending.body_lines then
    body = _JoinLines(pending.body_lines)
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

return Choice
