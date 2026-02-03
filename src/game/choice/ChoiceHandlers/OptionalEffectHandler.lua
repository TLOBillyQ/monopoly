local effect = require("src.game.effect.Effect")
local logger = require("src.core.Logger")
local monopoly_event = require("src.game.MonopolyEvents")

local optional_effect_handler = {}

local function _resolve_event_name(kind)
  assert(monopoly_event ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(monopoly_event.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function _dispatch_intent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
  if intent.kind == "need_choice" and intent.choice_spec then
    assert(game ~= nil and game.store ~= nil, "Choice.open requires game.store")
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
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { choice = entry, choice_spec = spec })
    return
  end
  if intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = _resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { payload = intent.payload })
  end
end

function optional_effect_handler.build(helpers)
  local contains = helpers.contains
  local build_game_ctx = helpers.build_game_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id
  local finish_choice = helpers.finish_choice

  local function _handle_optional_landing_effect(game, choice, action)
    local effect_id = assert(action.option_id, "missing effect_id")
    local meta = choice.meta

    if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
      logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local effect_defs = get_container_defs_by_choice_kind(choice.kind)
    local target_eff = assert(find_effect_by_id(effect_defs, effect_id), "missing target effect: " .. tostring(effect_id))

    local player = assert(game.players[meta.player_id], "missing player: " .. tostring(meta.player_id))
    local tile = assert(game.board:get_tile_by_id(meta.tile_id), "missing tile: " .. tostring(meta.tile_id))
    local move_result = meta.move_result
    local game_ctx = build_game_ctx(game, move_result)

    local res = effect.execute(target_eff, player, tile, game_ctx)
    _dispatch_intent(game, res.result or res)
    if res.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
    end
    return finish_choice(game, false)
  end

  return {
    landing_optional_effect = _handle_optional_landing_effect,
    land_optional_effect = _handle_optional_landing_effect,
  }
end

return optional_effect_handler

