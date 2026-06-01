require "vendor.third_party.ClassUtils"

local effect_runner = Class("EffectRunner")

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

function effect_runner.scan(effect_defs, player, tile, game_ctx)
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

function effect_runner.execute(eff, player, tile, game_ctx)
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = _build_ctx(player, tile, game_ctx)
  local ok, reason = _can_apply(eff, ctx, game_ctx)
  if not ok then
    return { ok = false, reason = reason }
  end
  local exec = _resolve_executor(eff.id, game_ctx)
  return { ok = true, result = exec.apply(ctx) }
end

local function _resolve_phase(game, opts)
  if opts.phase then
    return opts.phase
  end
  return game.turn.phase or opts.phase_default or "wait_choice"
end

local function _resolve_effect_registry(game, opts)
  if opts.effect_registry then
    return opts.effect_registry
  end
  local registries = game and game.registries
  return registries and registries.effects
end

function effect_runner.build_game_ctx(game, move_result, opts)
  opts = opts or {}
  return {
    game = game,
    rng = game.rng,
    phase = _resolve_phase(game, opts),
    move_result = move_result,
    on_landing = opts.on_landing,
    effect_registry = _resolve_effect_registry(game, opts),
  }
end

return effect_runner

--[[ mutate4lua-manifest
version=2
projectHash=53e7cdc71cc59176
scope.0.id=chunk:src/rules/effects/runner.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=100
scope.0.semanticHash=9992d7eef390e916
scope.0.lastMutatedAt=2026-05-30T13:30:07Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_resolve_registry:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=25
scope.1.semanticHash=198341fd932fe40b
scope.1.lastMutatedAt=2026-05-30T13:30:07Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_resolve_executor:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=31
scope.2.semanticHash=3790815b613edf54
scope.2.lastMutatedAt=2026-05-30T13:30:07Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:_can_apply:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=48d807ff6b092b5f
scope.3.lastMutatedAt=2026-05-30T13:30:07Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=8
scope.4.id=function:effect_runner.execute:61
scope.4.kind=function
scope.4.startLine=61
scope.4.endLine=70
scope.4.semanticHash=1318439fc8db58e0
scope.4.lastMutatedAt=2026-05-30T13:30:07Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=8
scope.4.lastMutationKilled=8
scope.5.id=function:_resolve_phase:72
scope.5.kind=function
scope.5.startLine=72
scope.5.endLine=77
scope.5.semanticHash=b3bdc0b51d4f2445
scope.5.lastMutatedAt=2026-05-30T13:30:07Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:_resolve_effect_registry:79
scope.6.kind=function
scope.6.startLine=79
scope.6.endLine=85
scope.6.semanticHash=048f0f768a7a4599
scope.6.lastMutatedAt=2026-05-30T13:30:07Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=2
scope.6.lastMutationKilled=2
scope.7.id=function:effect_runner.build_game_ctx:87
scope.7.kind=function
scope.7.startLine=87
scope.7.endLine=97
scope.7.semanticHash=4c7cf7c4c04e1c09
scope.7.lastMutatedAt=2026-05-30T13:30:07Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=3
scope.7.lastMutationKilled=3
]]
