local choice_contract = require("src.config.choice.contract")

local choice = {}

local function _copy_option_view(opt, label)
  local view = {
    label = label,
    id = opt.id or opt,
    raw = opt,
  }
  if type(opt) ~= "table" then
    return view
  end
  view.can_buy = opt.can_buy
  view.sold_out = opt.sold_out
  view.requires_pre_confirm = opt.requires_pre_confirm == true
  view.pre_confirm_kind = opt.pre_confirm_kind
  view.confirm_title = opt.confirm_title
  view.confirm_body = opt.confirm_body
  return view
end

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

local function _resolve_choice_body(pending, opts)
  if pending.body_lines then
    return _join_lines(pending.body_lines)
  end
  if not opts.body_lines_only and pending.body then
    return pending.body
  end
  return ""
end

local function _build_options(pending, option_label)
  local options = {}
  for _, opt in ipairs(pending.options or {}) do
    local label = option_label(opt)
    assert(label ~= nil, "missing option label")
    options[#options + 1] = _copy_option_view(opt, label)
  end
  return options
end

local function _assemble_view(pending, title, body, options)
  local view = {
    id = pending.id,
    kind = pending.kind,
    title = title,
    body = body,
    options = options,
    meta = pending.meta,
    cancel_label = pending.cancel_label or "取消",
    allow_cancel = pending.allow_cancel ~= false,
  }
  choice_contract.copy_explicit_fields(pending, view)
  return view
end

function choice.build_choice_view(pending, opts)
  assert(pending ~= nil, "missing pending choice")
  opts = opts or {}
  local option_label = opts.option_label or _default_option_label
  local title = pending.title or "请选择"
  local body = _resolve_choice_body(pending, opts)
  local options = _build_options(pending, option_label)
  return _assemble_view(pending, title, body, options)
end

return choice

--[[ mutate4lua-manifest
version=4
projectHash=b559e7c54291c33d
scope.0.id=chunk:src/ui/view/choice_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=86
scope.0.semanticHash=f35751e3e1a5b7f2
scope.1.id=function:_copy_option_view
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=21
scope.1.semanticHash=85247716c1ab2c8c
scope.2.id=function:_join_lines
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=26
scope.2.semanticHash=6f9964c1be75b582
scope.3.id=function:_default_option_label
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=38
scope.3.semanticHash=c86eb59641ce8d53
scope.4.id=function:_resolve_choice_body
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=48
scope.4.semanticHash=fb324fc83ca6f19d
scope.5.id=function:_build_options
scope.5.kind=function
scope.5.startLine=50
scope.5.endLine=58
scope.5.semanticHash=fcfc3c2ab5d1f544
scope.6.id=function:_assemble_view
scope.6.kind=function
scope.6.startLine=60
scope.6.endLine=73
scope.6.semanticHash=8ace05977b0eab96
scope.7.id=function:choice.build_choice_view
scope.7.kind=function
scope.7.startLine=75
scope.7.endLine=83
scope.7.semanticHash=da24f40159631981
]]
