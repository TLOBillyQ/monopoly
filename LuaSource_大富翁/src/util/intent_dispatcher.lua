local IntentDispatcher = {}
local listeners = {}

function IntentDispatcher.on(kind, fn)
  if not kind or not fn then
    return
  end
  listeners[kind] = listeners[kind] or {}
  table.insert(listeners[kind], fn)
end

local function emit(kind, payload)
  local list = listeners[kind]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    fn(payload)
  end
end

function IntentDispatcher.dispatch(game, payload)
  if not payload then
    return
  end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game and game.store, "Choice.open requires game.store")
    local spec = intent.choice_spec
    local seq = game.store:get({ "turn", "choice_seq" }) or 0
    seq = seq + 1
    game.store:set({ "turn", "choice_seq" }, seq)
    local entry = {
      id = seq,
      kind = spec.kind,
      title = spec.title or "请选择",
      body_lines = spec.body_lines or {},
      options = spec.options or {},
      allow_cancel = spec.allow_cancel ~= false,
      cancel_label = spec.cancel_label or "取消",
      meta = spec.meta,
    }
    game.store:set({ "turn", "pending_choice" }, entry)
    emit("need_choice", { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = game and game.ui_port
    if ui_port and ui_port.push_popup then
      ui_port:push_popup(intent.payload)
    end
  end
end

return IntentDispatcher