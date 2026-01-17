local Effect = {}
Effect.__index = Effect

local function can_apply(effect, ctx)
  if effect.can_apply then
    local ok, reason = effect.can_apply(ctx)
    return ok == true, reason
  end
  return true, nil
end

local function apply(effect, ctx)
  if effect.apply then
    return effect.apply(ctx)
  end
end

function Effect.scan(effect_defs, ctx)
  local entries = {}
  for _, eff in ipairs(effect_defs or {}) do
    local ok, reason = can_apply(eff, ctx)
    table.insert(entries, {
      id = eff.id,
      label = eff.label or eff.id,
      mandatory = eff.mandatory == true,
      ok = ok,
      reason = reason,
      effect = eff,
    })
  end
  return entries
end

function Effect.execute(effect, ctx)
  local ok, reason = can_apply(effect, ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  return { ok = true, result = apply(effect, ctx) }
end

function Effect.build_ctx(game, player, tile, move_result, opts)
  opts = opts or {}
  local phase = opts.phase
  if not phase then
    phase = (game and game.store and game.store:get({ "turn", "phase" })) or opts.phase_default
  end
  return {
    game = game,
    store = game and game.store,
    rng = game and game.rng,
    services = game and game.get_services and game:get_services(),
    phase = phase or "wait_choice",
    player = player,
    tile = tile,
    move_result = move_result,
    on_landing = opts.on_landing,
  }
end

return Effect
