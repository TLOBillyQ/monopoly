local UI = require("src.gameplay.ui_port")

local Choice = {}

local function next_choice_id(store)
  local seq = store:get({ "turn", "choice_seq" }) or 0
  seq = seq + 1
  store:set({ "turn", "choice_seq" }, seq)
  return seq
end

function Choice.get(game)
  if not game or not game.store then
    return nil
  end
  return game.store:get({ "turn", "pending_choice" })
end

function Choice.clear(game)
  if not game or not game.store then
    return
  end
  game.store:set({ "turn", "pending_choice" }, nil)
end


function Choice.open(game, payload)
  assert(game and game.store, "Choice.open requires game.store")
  payload = payload or {}
  local id = next_choice_id(game.store)
  local entry = {
    id = id,
    kind = payload.kind,
    title = payload.title or "请选择",
    body_lines = payload.body_lines or {},
    options = payload.options or {},
    allow_cancel = payload.allow_cancel ~= false,
    cancel_label = payload.cancel_label or "取消",
    meta = payload.meta,
  }
  game.store:set({ "turn", "pending_choice" }, entry)
  return entry
end

function Choice.apply_intent(game, payload)
  if not payload then
    return
  end
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    Choice.open(game, intent.choice_spec)
  elseif intent.kind == "push_popup" and intent.payload then
    UI.push_popup(game, intent.payload)
  end
end

return Choice
