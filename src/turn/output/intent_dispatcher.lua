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

function intent_dispatcher.open_choice(game, choice_spec)
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
projectHash=9bcfe53f0b95886b
scope.0.id=chunk:src/turn/output/intent_dispatcher.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=d5e4722064a48b13
scope.0.lastMutatedAt=2026-07-07T02:45:05Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=7
scope.0.lastMutationKilled=7
scope.1.id=function:_build_choice_log_text:11
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=20
scope.1.semanticHash=d2630b9f3c233271
scope.1.lastMutatedAt=2026-07-07T02:45:05Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=13
scope.1.lastMutationKilled=13
scope.2.id=function:_build_choice_entry:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=40
scope.2.semanticHash=9cc81df44cb69d4f
scope.2.lastMutatedAt=2026-07-07T02:45:05Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=13
scope.2.lastMutationKilled=13
scope.3.id=function:intent_dispatcher.open_choice:42
scope.3.kind=function
scope.3.startLine=42
scope.3.endLine=61
scope.3.semanticHash=352182ad1ff16f87
scope.3.lastMutatedAt=2026-07-07T02:45:05Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=11
scope.3.lastMutationKilled=11
scope.4.id=function:intent_dispatcher.push_popup:63
scope.4.kind=function
scope.4.startLine=63
scope.4.endLine=75
scope.4.semanticHash=8ad129129e1381ac
scope.4.lastMutatedAt=2026-07-07T02:45:05Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=16
scope.4.lastMutationKilled=16
scope.5.id=function:intent_dispatcher.dispatch:77
scope.5.kind=function
scope.5.startLine=77
scope.5.endLine=94
scope.5.semanticHash=9c0785916467b150
scope.5.lastMutatedAt=2026-07-07T02:45:05Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=survived
scope.5.lastMutationSites=17
scope.5.lastMutationKilled=16
scope.6.id=function:intent_dispatcher.build_port:96
scope.6.kind=function
scope.6.startLine=96
scope.6.endLine=101
scope.6.semanticHash=2d76d51e30879093
]]
