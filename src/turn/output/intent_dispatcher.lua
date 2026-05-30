local monopoly_event = require("src.foundation.events")
local choice_contract = require("src.config.choice.contract")
local choice_route_policy = require("src.config.choice.route_policy")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local dirty_tracker = require("src.state.dirty_tracker")

local intent_dispatcher = {}

local function _build_choice_log_text(title, body_lines)
  local text = "等待选择：" .. tostring(title or "请选择")
  if type(body_lines) == "table" then
    local first_line = body_lines[1]
    if type(first_line) == "string" and first_line ~= "" then
      text = text .. "：" .. first_line
    end
  end
  return text
end


local function _build_choice_entry(choice_id, choice_spec)
  local route_key = choice_route_policy.resolve(choice_spec)
  local requires_confirm = choice_route_policy.requires_confirm(choice_spec)
  local entry = {
    id = choice_id,
    kind = choice_spec.kind,
    title = choice_spec.title or "请选择",
    body_lines = choice_spec.body_lines or {},
    options = choice_spec.options or {},
    allow_cancel = choice_spec.allow_cancel ~= false,
    cancel_label = choice_spec.cancel_label or "取消",
    meta = choice_spec.meta,
  }
  choice_contract.copy_explicit_fields(choice_spec, entry)
  entry.route_key = route_key
  entry.requires_confirm = requires_confirm == true
  return entry
end

local function _validate_required_meta(choice_spec, required_meta)
  if type(required_meta) ~= "table" or #required_meta == 0 then
    return choice_spec.meta
  end

  local meta = choice_spec.meta
  assert(type(meta) == "table", tostring(choice_spec.kind) .. " requires meta")
  for _, key in ipairs(required_meta) do
    assert(meta[key] ~= nil, tostring(choice_spec.kind) .. " requires meta." .. tostring(key))
  end
  return meta
end

local function _validate_choice_meta(game, choice_spec)
  local registries = game and game.registries or nil
  local choice_registry = registries and registries.choices or nil
  if type(choice_registry) ~= "table" or type(choice_registry.descriptor_for) ~= "function" then
    return nil
  end
  local descriptor = choice_registry:descriptor_for(choice_spec.kind)
  if descriptor and descriptor.normalize_meta ~= nil then
    local normalized_meta = descriptor.normalize_meta(game, choice_spec.meta, choice_spec)
    if normalized_meta ~= nil then
      choice_spec.meta = normalized_meta
    end
  end
  local required_meta = descriptor and descriptor.required_meta or nil
  local meta = _validate_required_meta(choice_spec, required_meta)
  if descriptor and descriptor.meta_validator ~= nil then
    descriptor.meta_validator(game, meta, choice_spec)
  end
  return descriptor
end

function intent_dispatcher.open_choice(game, choice_spec)
  assert(game and game.turn, "Choice.open requires game.turn")
  assert(choice_spec ~= nil, "missing choice_spec")
  _validate_choice_meta(game, choice_spec)

  local seq = game.turn.choice_seq or 0
  seq = seq + 1
  game.turn.choice_seq = seq

  local entry = _build_choice_entry(seq, choice_spec)
  game.turn.pending_choice = entry
  dirty_tracker.mark(game.dirty, "turn")
  event_feed.publish(game, {
    kind = event_kinds.choice_picked,
    text = _build_choice_log_text(entry.title, entry.body_lines),
    tip = false,
  })
  monopoly_event.emit_intent("need_choice", { choice = entry, choice_spec = choice_spec })
  return entry
end

function intent_dispatcher.push_popup(game, payload, opts)
  assert(payload ~= nil, "missing popup payload")
  opts = opts or {}
  local popup_port = game and game.popup_port or nil
  if popup_port == nil and game and type(game.ensure_popup_port) == "function" then
    popup_port = game:ensure_popup_port()
  end
  assert(popup_port ~= nil, "missing popup_port")
  assert(popup_port.push_popup ~= nil, "missing popup_port.push_popup")
  popup_port:push_popup(payload, opts)
  monopoly_event.emit_intent("push_popup", { payload = payload })
  return true
end

function intent_dispatcher.dispatch(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if not intent or type(intent) ~= "table" then
    return nil
  end

  if intent.kind == "need_choice" and intent.choice_spec then
    return intent_dispatcher.open_choice(game, intent.choice_spec)
  end

  if intent.kind == "push_popup" and intent.payload then
    local popup_opts = intent.popup_opts or intent.opts or nil
    return intent_dispatcher.push_popup(game, intent.payload, popup_opts)
  end

  return nil
end

function intent_dispatcher.build_port()
  return {
    open_choice = intent_dispatcher.open_choice,
    push_popup = intent_dispatcher.push_popup,
  }
end

return intent_dispatcher

--[[ mutate4lua-manifest
version=2
projectHash=ac180f52a3d196a6
scope.0.id=chunk:src/turn/output/intent_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=137
scope.0.semanticHash=1cd311b08f47aa83
scope.1.id=function:_build_choice_log_text:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=19
scope.1.semanticHash=d2630b9f3c233271
scope.2.id=function:_build_choice_entry:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=39
scope.2.semanticHash=9cc81df44cb69d4f
scope.3.id=function:_validate_choice_meta:54
scope.3.kind=function
scope.3.startLine=54
scope.3.endLine=73
scope.3.semanticHash=9e272890fe9f9e10
scope.4.id=function:intent_dispatcher.open_choice:75
scope.4.kind=function
scope.4.startLine=75
scope.4.endLine=94
scope.4.semanticHash=f4c23bc3a874d922
scope.5.id=function:intent_dispatcher.push_popup:96
scope.5.kind=function
scope.5.startLine=96
scope.5.endLine=108
scope.5.semanticHash=8ad129129e1381ac
scope.6.id=function:intent_dispatcher.dispatch:110
scope.6.kind=function
scope.6.startLine=110
scope.6.endLine=127
scope.6.semanticHash=9c0785916467b150
scope.7.id=function:intent_dispatcher.build_port:129
scope.7.kind=function
scope.7.startLine=129
scope.7.endLine=134
scope.7.semanticHash=2d76d51e30879093
]]
