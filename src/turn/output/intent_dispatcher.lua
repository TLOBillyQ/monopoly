local monopoly_event = require("src.foundation.events")
local choice_contract = require("src.config.choice.contract")
local choice_route_policy = require("src.config.choice.route_policy")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local dirty_tracker = require("src.state.dirty_tracker")
local choice_meta_validator = require("src.turn.output.choice_meta_validator")

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


local function _choice_labels(choice_spec)
  return choice_spec.title or "请选择", choice_spec.cancel_label or "取消"
end

local function _build_choice_entry(choice_id, choice_spec)
  local title, cancel_label = _choice_labels(choice_spec)
  local entry = {
    id = choice_id,
    kind = choice_spec.kind,
    title = title,
    body_lines = choice_spec.body_lines or {},
    options = choice_spec.options or {},
    allow_cancel = choice_spec.allow_cancel ~= false,
    cancel_label = cancel_label,
    meta = choice_spec.meta,
  }
  choice_contract.copy_explicit_fields(choice_spec, entry)
  entry.route_key = choice_route_policy.resolve(choice_spec)
  entry.requires_confirm = choice_route_policy.requires_confirm(choice_spec) == true
  return entry
end

function intent_dispatcher.open_choice(game, choice_spec, opts)
  assert(game and game.turn, "Choice.open requires game.turn")
  assert(choice_spec ~= nil, "missing choice_spec")
  choice_meta_validator.validate(game, choice_spec)

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
  local elapsed_seconds = opts and opts.elapsed_seconds or 0
  monopoly_event.emit_intent("need_choice", {
    choice = entry,
    choice_spec = choice_spec,
    elapsed_seconds = elapsed_seconds,
  })
  return entry
end

local function _resolve_popup_port(game)
  local popup_port = game and game.popup_port or nil
  assert(popup_port ~= nil, "missing popup_port")
  assert(popup_port.push_popup ~= nil, "missing popup_port.push_popup")
  return popup_port
end

function intent_dispatcher.push_popup(game, payload, opts)
  assert(payload ~= nil, "missing popup payload")
  opts = opts or {}
  local popup_port = _resolve_popup_port(game)
  popup_port:push_popup(payload, opts)
  monopoly_event.emit_intent("push_popup", { payload = payload })
  return true
end

local function _resolve_intent(payload)
  local intent = payload.intent or payload
  if not intent or type(intent) ~= "table" then
    return nil
  end
  return intent
end

local function _dispatch_push_popup(game, intent)
  local popup_opts = intent.popup_opts or intent.opts or nil
  return intent_dispatcher.push_popup(game, intent.payload, popup_opts)
end

local function _intent_matches(intent, kind, payload_key)
  return intent.kind == kind and intent[payload_key]
end

function intent_dispatcher.dispatch(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = _resolve_intent(payload)
  if intent == nil then
    return nil
  end

  if _intent_matches(intent, "need_choice", "choice_spec") then
    return intent_dispatcher.open_choice(game, intent.choice_spec)
  end

  if _intent_matches(intent, "push_popup", "payload") then
    return _dispatch_push_popup(game, intent)
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
version=4
projectHash=b23481392579f910
scope.0.id=chunk:src/turn/output/intent_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=130
scope.0.semanticHash=580b1d5eb205ba5d
scope.1.id=function:_build_choice_log_text
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=20
scope.1.semanticHash=4317469022421da1
scope.2.id=function:_choice_labels
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=c0eedc5e3a2fcb9c
scope.3.id=function:_build_choice_entry
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=43
scope.3.semanticHash=c6ae1f35bf1073f5
scope.4.id=function:intent_dispatcher.open_choice
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=69
scope.4.semanticHash=f28f8f47b2f81c88
scope.5.id=function:_resolve_popup_port
scope.5.kind=function
scope.5.startLine=71
scope.5.endLine=76
scope.5.semanticHash=6fc3b60a41725c9c
scope.6.id=function:intent_dispatcher.push_popup
scope.6.kind=function
scope.6.startLine=78
scope.6.endLine=85
scope.6.semanticHash=3d364b5e57aeb049
scope.7.id=function:_resolve_intent
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=93
scope.7.semanticHash=76e51bf540cd4ec9
scope.8.id=function:_dispatch_push_popup
scope.8.kind=function
scope.8.startLine=95
scope.8.endLine=98
scope.8.semanticHash=9efc0663addc4780
scope.9.id=function:_intent_matches
scope.9.kind=function
scope.9.startLine=100
scope.9.endLine=102
scope.9.semanticHash=85c969f980081ded
scope.10.id=function:intent_dispatcher.dispatch
scope.10.kind=function
scope.10.startLine=104
scope.10.endLine=120
scope.10.semanticHash=452623df3e526a15
scope.11.id=function:intent_dispatcher.build_port
scope.11.kind=function
scope.11.startLine=122
scope.11.endLine=127
scope.11.semanticHash=203ac6863bbbdd9e
]]
