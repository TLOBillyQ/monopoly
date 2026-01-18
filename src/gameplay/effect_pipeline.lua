local Effect = require("src.gameplay.effect")
local IntentDispatcher = require("src.util.intent_dispatcher")

local Pipeline = {}

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
    player_id = player and player.id or nil,
    tile_id = tile and tile.id or nil,
    move_result = game_ctx and game_ctx.move_result,
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
    intent = { kind = "need_choice", choice_spec = choice_spec },
  }

  IntentDispatcher.dispatch(game_ctx and game_ctx.game, { kind = "need_choice", choice_spec = choice_spec })
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
      IntentDispatcher.dispatch(game_ctx and game_ctx.game, payload)
    end

    if type(out) == "table" and out.waiting then
      out.resume_state = out.resume_state or opts.resume_state
      out.resume_args = out.resume_args or opts.resume_args
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
