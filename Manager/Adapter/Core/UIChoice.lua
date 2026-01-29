local Phase = require("Manager.Adapter.Core.UIPhase")

local Choice = {}

local function join_lines(lines)
  if not lines then
    return ""
  end
  return table.concat(lines, "\n")
end

local function default_option_label(opt)
  if opt and opt.label then
    return opt.label
  end
  if opt and opt.id ~= nil then
    return tostring(opt.id)
  end
  return tostring(opt)
end

function Choice.build_choice_view(pending, opts)
  if not pending then
    return nil
  end
  opts = opts or {}
  local option_label = opts.option_label or default_option_label
  local title = Phase.build_phase_title(opts.game, pending.title or "请选择")
  local body = ""
  if pending.body_lines then
    body = join_lines(pending.body_lines)
  elseif not opts.body_lines_only and pending.body then
    body = pending.body
  end

  local options = {}
  for _, opt in ipairs(pending.options or {}) do
    local label = option_label(opt)
    if label == nil then
      label = ""
    end
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
