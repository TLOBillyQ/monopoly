local Landing = require("Manager.LandManager.Land.Landing")
local Land = require("Manager.LandManager.Land.Land")
require "Library.ClassUtils"

local executors = {}
local landing_execs = assert(Landing.executors, "missing Landing.executors")
for id, exec in pairs(landing_execs) do
  executors[id] = exec
end
local land_execs = assert(Land.executors, "missing Land.executors")
for id, exec in pairs(land_execs) do
  executors[id] = exec
end

local function build_ctx(player, tile, game_ctx)
  local ctx = {}
  assert(game_ctx ~= nil, "missing game_ctx")
  for key, value in pairs(game_ctx) do
    ctx[key] = value
  end
  ctx.player = player
  ctx.tile = tile
  return ctx
end

local function can_apply(effect, ctx)
  assert(effect ~= nil, "missing effect")
  local exec = assert(executors[effect.id], "missing executor: " .. tostring(effect.id))
  if exec.can_apply and not exec.can_apply(ctx) then
    return false, "blocked"
  end
  return true
end


local Effect = Class("Effect")


function Effect.scan(effect_defs, player, tile, game_ctx)
  assert(effect_defs ~= nil, "missing effect_defs")
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = build_ctx(player, tile, game_ctx)
  local entries = {}
  for _, eff in ipairs(effect_defs) do
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
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = build_ctx(player, tile, game_ctx)
  local ok, reason = can_apply(effect, ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  local exec = assert(executors[effect.id], "missing executor: " .. tostring(effect.id))
  assert(exec.apply ~= nil, "missing executor apply: " .. tostring(effect.id))
  return { ok = true, result = exec.apply(ctx) }
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
