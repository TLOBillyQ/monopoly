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

function choice.build_choice_view(pending, opts)
  assert(pending ~= nil, "missing pending choice")
  opts = opts or {}
  local option_label = opts.option_label or _default_option_label
  local title = pending.title or "请选择"
  local body = _resolve_choice_body(pending, opts)

  local options = {}
  for _, opt in ipairs(pending.options or {}) do
    local label = option_label(opt)
    assert(label ~= nil, "missing option label")
    options[#options + 1] = _copy_option_view(opt, label)
  end

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

return choice

--[[ mutate4lua-manifest
version=2
projectHash=7ad603c131b9c6ac
scope.0.id=chunk:src/ui/view/choice_builder.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=79
scope.0.semanticHash=7d73ea4f744fe680
scope.1.id=function:_copy_option_view:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=21
scope.1.semanticHash=79fc7e628ee63478
scope.2.id=function:_join_lines:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=26
scope.2.semanticHash=393cdc1d43fa9546
scope.3.id=function:_default_option_label:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=38
scope.3.semanticHash=25b356b892d34f65
scope.4.id=function:_resolve_choice_body:40
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=48
scope.4.semanticHash=477991b2623ff497
]]
