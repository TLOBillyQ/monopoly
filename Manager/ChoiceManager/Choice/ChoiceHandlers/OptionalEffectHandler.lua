local Effect = require("Manager.EffectManager.Effect.Effect")
local logger = require("Components.Logger")
local MONOPOLY_EVENT = require("Globals.MonopolyEvents")

local OptionalEffectHandler = {}

local function resolve_event_name(kind)
  local intent = MONOPOLY_EVENT and MONOPOLY_EVENT.intent
  return kind and ((intent and intent[kind]) or kind) or nil
end

local function dispatch_intent(game, payload)
  local intent = payload and (payload.intent or payload) or nil
  if intent and intent.kind == "need_choice" and intent.choice_spec then
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
    if TriggerCustomEvent then
      local event_name = resolve_event_name("need_choice")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
      end
    end
    return
  end
  if intent and intent.kind == "push_popup" and intent.payload then
    local ui_port = game and game.ui_port
    if ui_port and ui_port.push_popup then
      ui_port:push_popup(intent.payload)
    end
    if TriggerCustomEvent then
      local event_name = resolve_event_name("push_popup")
      if event_name then
        TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
      end
    end
  end
end

function OptionalEffectHandler.build(helpers)
  local contains = helpers.contains
  local build_game_ctx = helpers.build_game_ctx
  local get_container_defs_by_choice_kind = helpers.get_container_defs_by_choice_kind
  local find_effect_by_id = helpers.find_effect_by_id
  local finish_choice = helpers.finish_choice

  local function handle_optional_landing_effect(game, choice, action)
    local effect_id = action.option_id
    if not effect_id then
      return finish_choice(game, false)
    end
    local meta = choice.meta

    if meta.effect_ids and not contains(meta.effect_ids, effect_id) then
      logger.warn("landing_optional_effect: effect not in offered list:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local effect_defs = get_container_defs_by_choice_kind(choice.kind)
    local target_eff = find_effect_by_id(effect_defs, effect_id)
    if not target_eff then
      logger.warn("landing_optional_effect: effect id not found:", tostring(effect_id))
      return finish_choice(game, false)
    end

    local player = game.players[meta.player_id]
    local tile = game.board:get_tile_by_id(meta.tile_id)
    local move_result = meta.move_result
    local game_ctx = build_game_ctx(game, move_result)

    local res = Effect.execute(target_eff, player, tile, game_ctx)
    dispatch_intent(game, res.result or res)
    if res.ok ~= true then
      logger.warn("landing_optional_effect execute blocked:", tostring(res and res.reason))
    end
    return finish_choice(game, false)
  end

  return {
    landing_optional_effect = handle_optional_landing_effect,
    land_optional_effect = handle_optional_landing_effect,
  }
end

return OptionalEffectHandler


