local Effect = {}
Effect.__index = Effect

local Landing = require("src.gameplay.landing")
local Land = require("src.gameplay.land")

local executors = {}
local function merge_executors(list)
  for key, executor in pairs(list or {}) do
    executors[key] = executor
  end
end

merge_executors(Landing.executors)
merge_executors(Land.executors)

local function build_ctx(player, tile, game_ctx)
  return {
    game = game_ctx and game_ctx.game,
    store = game_ctx and game_ctx.store,
    rng = game_ctx and game_ctx.rng,
    services = game_ctx and game_ctx.services,
    phase = game_ctx and game_ctx.phase,
    player = player,
    tile = tile,
    move_result = game_ctx and game_ctx.move_result,
    on_landing = game_ctx and game_ctx.on_landing,
  }
end

local function can_apply(effect, ctx)
  local exec = executors[effect.id]
  if exec and exec.can_apply then
    local ok, reason = exec.can_apply(ctx)
    return ok == true, reason
  end
  return true, nil
end

function Effect.scan(effect_defs, player, tile, game_ctx)
  local ctx = build_ctx(player, tile, game_ctx)
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

function Effect.execute(effect, player, tile, game_ctx)
  local ctx = build_ctx(player, tile, game_ctx)
  local ok, reason = can_apply(effect, ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  local exec = executors[effect.id]
  return { ok = true, result = exec and exec.apply and exec.apply(ctx) }
end

function Effect.build_game_ctx(game, move_result, opts)
  opts = opts or {}
  local phase = opts.phase
  if not phase then
    phase = game.store:get({ "turn", "phase" }) or opts.phase_default
  end
  return {
    game = game,
    store = game.store,
    rng = game.rng,
    services = game:get_services(),
    phase = phase or "wait_choice",
    move_result = move_result,
    on_landing = opts.on_landing,
  }
end

return Effect
