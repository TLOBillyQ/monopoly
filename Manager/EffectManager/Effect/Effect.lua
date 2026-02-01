local Landing = require("Manager.LandManager.Land.Landing")
local Land = require("Manager.LandManager.Land.Land")
require "Library.ClassUtils"

local executors = {}
for id, exec in pairs(Landing.executors or {}) do
  executors[id] = exec
end
for id, exec in pairs(Land.executors or {}) do
  executors[id] = exec
end

local function build_ctx(player, tile, game_ctx)
  local ctx = {}
  if game_ctx then
    for key, value in pairs(game_ctx) do
      ctx[key] = value
    end
  end
  ctx.player = player
  ctx.tile = tile
  return ctx
end

local function can_apply(effect, ctx)
  local exec = effect and executors[effect.id]
  if not exec then
    return false, "missing_executor"
  end
  if exec.can_apply and not exec.can_apply(ctx) then
    return false, "blocked"
  end
  return true
end


local Effect = Class("Effect")


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
