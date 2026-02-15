require "vendor.third_party.ClassUtils"

local effect = Class("Effect")

local function _build_ctx(player, tile, game_ctx)
  local ctx = {}
  assert(game_ctx ~= nil, "missing game_ctx")
  for key, value in pairs(game_ctx) do
    ctx[key] = value
  end
  ctx.player = player
  ctx.tile = tile
  return ctx
end

local function _resolve_registry(game_ctx)
  assert(game_ctx ~= nil, "missing game_ctx")
  if game_ctx.effect_registry then
    return game_ctx.effect_registry
  end
  local game = game_ctx.game
  assert(game ~= nil, "missing game_ctx.game")
  local registries = assert(game.registries, "missing game.registries")
  return assert(registries.effects, "missing effect registry")
end

local function _resolve_executor(effect_id, game_ctx)
  local registry = _resolve_registry(game_ctx)
  assert(registry.get ~= nil, "invalid effect registry")
  return assert(registry:get(effect_id), "missing executor: " .. tostring(effect_id))
end

local function _can_apply(eff, ctx, game_ctx)
  assert(eff ~= nil, "missing effect")
  local exec = _resolve_executor(eff.id, game_ctx)
  if exec.can_apply and not exec.can_apply(ctx) then
    return false, "blocked"
  end
  return true
end

function effect.scan(effect_defs, player, tile, game_ctx)
  assert(effect_defs ~= nil, "missing effect_defs")
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = _build_ctx(player, tile, game_ctx)
  local entries = {}
  for _, eff in ipairs(effect_defs) do
    local ok, reason = _can_apply(eff, ctx, game_ctx)
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

function effect.execute(eff, player, tile, game_ctx)
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = _build_ctx(player, tile, game_ctx)
  local ok, reason = _can_apply(eff, ctx, game_ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  local exec = _resolve_executor(eff.id, game_ctx)
  return { ok = true, result = exec.apply(ctx) }
end

function effect.build_game_ctx(game, move_result, opts)
  opts = opts or {}
  local phase = opts.phase
  if not phase then
    phase = game.turn.phase or opts.phase_default
  end
  local registries = game and game.registries or nil
  return {
    game = game,
    rng = game.rng,
    phase = phase or "wait_choice",
    move_result = move_result,
    on_landing = opts.on_landing,
    effect_registry = opts.effect_registry or (registries and registries.effects),
  }
end

return effect
