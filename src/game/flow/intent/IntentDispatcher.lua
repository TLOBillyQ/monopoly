local monopoly_event = require("src.game.core.runtime.MonopolyEvents")

local intent_dispatcher = {}
local emit = monopoly_event.emit

local function _resolve_option_id(option)
  if type(option) == "table" then
    return option.id
  end
  return option
end

local function _is_building_route(choice_spec)
  local kind = choice_spec and choice_spec.kind
  if kind ~= "landing_optional_effect" and kind ~= "land_optional_effect" then
    return false
  end
  local options = choice_spec.options or {}
  if #options == 0 then
    return false
  end
  for _, option in ipairs(options) do
    local option_id = _resolve_option_id(option)
    if option_id ~= "buy_land" and option_id ~= "upgrade_land" then
      return false
    end
  end
  return true
end

local function _infer_legacy_route_key(choice_spec)
  local kind = choice_spec and choice_spec.kind
  if kind == "market_buy" then
    return "market"
  end
  if kind == "remote_dice_value" then
    return "remote"
  end
  if kind == "item_target_player" then
    return "player"
  end
  if kind == "roadblock_target" or kind == "demolish_target" then
    return "target"
  end
  if _is_building_route(choice_spec) then
    return "building"
  end
  return "target"
end

local function _resolve_choice_route(choice_spec)
  local route = choice_spec and choice_spec.route or nil
  if type(route) == "table" and route.route_key ~= nil then
    return route.route_key, route.requires_confirm
  end
  if choice_spec and choice_spec.route_key ~= nil then
    return choice_spec.route_key, choice_spec.requires_confirm
  end
  local meta = choice_spec and choice_spec.meta or nil
  if type(meta) == "table" and meta.route_key ~= nil then
    return meta.route_key, meta.requires_confirm
  end
  local route_key = _infer_legacy_route_key(choice_spec)
  return route_key, route_key == "building"
end

function intent_dispatcher.open_choice(game, choice_spec, opts)
  assert(game and game.turn, "Choice.open requires game.turn")
  assert(choice_spec ~= nil, "missing choice_spec")
  opts = opts or {}

  local seq = game.turn.choice_seq or 0
  seq = seq + 1
  game.turn.choice_seq = seq

  local route_key, requires_confirm = _resolve_choice_route(choice_spec)
  local entry = {
    id = seq,
    kind = choice_spec.kind,
    title = choice_spec.title or "请选择",
    body_lines = choice_spec.body_lines or {},
    options = choice_spec.options or {},
    allow_cancel = choice_spec.allow_cancel ~= false,
    cancel_label = choice_spec.cancel_label or "取消",
    meta = choice_spec.meta,
    route_key = route_key,
    requires_confirm = requires_confirm == true,
  }
  game.turn.pending_choice = entry
  game.dirty.turn = true
  game.dirty.any = true

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
