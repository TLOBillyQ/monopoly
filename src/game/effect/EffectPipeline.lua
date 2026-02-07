local effect = require("src.game.effect.Effect")
local intent_dispatcher = require("src.game.intent.IntentDispatcher")

local pipeline = {}

local list_pool = {}

local function _acquire_list()
  local list = list_pool[#list_pool]
  if list then
    list_pool[#list_pool] = nil
    return list
  end
  return {}
end

local function _release_list(list)
  for i = #list, 1, -1 do
    list[i] = nil
  end
  list_pool[#list_pool + 1] = list
end

local function _build_optional_choice(optional, player, tile, game_ctx, opts)
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

  intent_dispatcher.dispatch(game_ctx.game, { kind = "need_choice", choice_spec = choice_spec })
  return out
end

function pipeline.run(effect_defs, player, tile, game_ctx, opts)
  opts = opts or {}
  local scanned = effect.scan(effect_defs, player, tile, game_ctx)
  local mandatory = _acquire_list()
  local optional = _acquire_list()

  local function _finalize(result)
    _release_list(mandatory)
    _release_list(optional)
    return result
  end

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
    local res = effect.execute(eff, player, tile, game_ctx)
    local out = res and res.result

    if opts.on_need_landing and type(out) == "table" and out.kind == "need_landing" then
      out = opts.on_need_landing(out) or out
    end

    local payload = out or res
    if payload then
      intent_dispatcher.dispatch(game_ctx.game, payload)
    end

    if type(out) == "table" and out.waiting then
      out.resume_state = out.resume_state or opts.resume_state
      out.resume_args = out.resume_args or opts.resume_args
      out.intent = nil
      return _finalize(out)
    end

    if opts.stop_if and opts.stop_if(out, res) then
      return _finalize(out)
    end
  end

  if opts.allow_optional == false or #optional == 0 then
    return _finalize(nil)
  end

  return _finalize(_build_optional_choice(optional, player, tile, game_ctx, opts))
end

return pipeline
