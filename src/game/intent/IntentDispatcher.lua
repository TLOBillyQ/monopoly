local monopoly_event = require("src.game.game.MonopolyEvents")

local intent_dispatcher = {}
local emit = monopoly_event.emit

local choice_seq_path = { "turn", "choice_seq" }
local pending_choice_path = { "turn", "pending_choice" }

function intent_dispatcher.open_choice(game, choice_spec, opts)
  assert(game and game.store, "Choice.open requires game.store")
  assert(choice_spec ~= nil, "missing choice_spec")
  opts = opts or {}

  local seq = game.store:get(choice_seq_path) or 0
  seq = seq + 1
  game.store:set(choice_seq_path, seq)

  local entry = {
    id = seq,
    kind = choice_spec.kind,
    title = choice_spec.title or "请选择",
    body_lines = choice_spec.body_lines or {},
    options = choice_spec.options or {},
    allow_cancel = choice_spec.allow_cancel ~= false,
    cancel_label = choice_spec.cancel_label or "取消",
    meta = choice_spec.meta,
  }
  game.store:set(pending_choice_path, entry)

  local event_name = monopoly_event.resolve_intent("need_choice")
  emit(event_name, { choice = entry, choice_spec = choice_spec })
  return entry
end

function intent_dispatcher.push_popup(game, payload, opts)
  assert(payload ~= nil, "missing popup payload")
  opts = opts or {}
  local ui_port = assert(game.ui_port, "missing ui_port")
  assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
  ui_port:push_popup(payload)
  local event_name = monopoly_event.resolve_intent("push_popup")
  emit(event_name, { payload = payload })
  return true
end

function intent_dispatcher.dispatch(game, payload, opts)
  assert(payload ~= nil, "missing payload")
  opts = opts or {}
  local intent = payload.intent or payload
  if not intent or type(intent) ~= "table" then
    return nil
  end

  if intent.kind == "need_choice" and intent.choice_spec then
    return intent_dispatcher.open_choice(game, intent.choice_spec, opts)
  end

  if intent.kind == "push_popup" and intent.payload then
    return intent_dispatcher.push_popup(game, intent.payload, opts)
  end

  return nil
end

return intent_dispatcher
