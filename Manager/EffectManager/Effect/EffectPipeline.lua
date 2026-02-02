local Effect = require("Manager.EffectManager.Effect.Effect")
local MonopolyEvent = require("Globals.MonopolyEvents")

local Pipeline = {}

local function resolve_event_name(kind)
  assert(MonopolyEvent ~= nil, "missing MONOPOLY_EVENT")
  local intent = assert(MonopolyEvent.intent, "missing MONOPOLY_EVENT.intent")
  assert(kind ~= nil, "missing event kind")
  return intent[kind] or kind
end

local function dispatch_intent(game, payload)
  assert(payload ~= nil, "missing payload")
  local intent = payload.intent or payload
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
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = resolve_event_name("need_choice")
    TriggerCustomEvent(event_name, { game = game, choice = entry, choice_spec = spec })
    return
  end
  if intent and intent.kind == "push_popup" and intent.payload then
    local ui_port = assert(game.ui_port, "missing ui_port")
    assert(ui_port.push_popup ~= nil, "missing ui_port.push_popup")
    ui_port:push_popup(intent.payload)
    assert(TriggerCustomEvent ~= nil, "missing TriggerCustomEvent")
    local event_name = resolve_event_name("push_popup")
    TriggerCustomEvent(event_name, { game = game, payload = intent.payload })
  end
end

local function build_optional_choice(optional, player, tile, game_ctx, opts)
  local body_lines = {}
  local options = {}
  local effect_ids = {}
  for _, eff in ipairs(optional) do
    local label = eff.label or eff.id
    table.insert(body_lines, label)
    table.insert(options, { id = eff.id, label = label })
    table.insert(effect_ids, eff.id)
  end

  local meta = {
    effect_ids = effect_ids,
    player_id = player.id,
    tile_id = tile.id,
    move_result = game_ctx.move_result,
  }

  local choice_spec = {
    kind = opts.optional_choice_kind or "landing_optional_effect",
    title = opts.optional_title,
    body_lines = body_lines,
    options = options,
    allow_cancel = opts.optional_allow_cancel,
    cancel_label = opts.optional_cancel_label,
    meta = meta,
  }

  local out = {
    waiting = true,
    reason = opts.optional_reason or "optional_effect",
    resume_state = opts.resume_state,
    resume_args = opts.resume_args,
  }

  dispatch_intent(game_ctx.game, { kind = "need_choice", choice_spec = choice_spec })
  return out
end

function Pipeline.run(effect_defs, player, tile, game_ctx, opts)
  opts = opts or {}
  local scanned = Effect.scan(effect_defs, player, tile, game_ctx)
  local mandatory = {}
  local optional = {}

  for _, entry in ipairs(scanned) do
    if entry.ok then
      if entry.mandatory then
        table.insert(mandatory, entry.effect)
      else
        table.insert(optional, entry.effect)
      end
    end
  end

  for _, eff in ipairs(mandatory) do
    local res = Effect.execute(eff, player, tile, game_ctx)
    local out = res and res.result

    if opts.on_need_landing and type(out) == "table" and out.kind == "need_landing" then
      out = opts.on_need_landing(out) or out
    end

    local payload = out or res
    if payload then
      dispatch_intent(game_ctx.game, payload)
    end

    if type(out) == "table" and out.waiting then
      out.resume_state = out.resume_state or opts.resume_state
      out.resume_args = out.resume_args or opts.resume_args
      out.intent = nil
      return out
    end

    if opts.stop_if and opts.stop_if(out, res) then
      return out
    end
  end

  if opts.allow_optional == false or #optional == 0 then
    return nil
  end

  return build_optional_choice(optional, player, tile, game_ctx, opts)
end

return Pipeline
