local Class = require("src.foundation.class")

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

local function _build_scan_entry(eff, ok, reason)
  return {
    id = eff.id,
    label = eff.label or eff.id,
    mandatory = eff.mandatory == true,
    ok = ok,
    reason = reason,
    effect = eff,
  }
end

function effect_runner.scan(effect_defs, player, tile, game_ctx)
  assert(effect_defs ~= nil, "missing effect_defs")
  assert(game_ctx ~= nil, "missing game_ctx")
  local ctx = _build_ctx(player, tile, game_ctx)
  local entries = {}
  for _, eff in ipairs(effect_defs) do
    local ok, reason = _can_apply(eff, ctx, game_ctx)
    table.insert(entries, _build_scan_entry(eff, ok, reason))
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
version=4
projectHash=e4093820871df5cd
scope.0.id=chunk:src/rules/effects/runner.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=25a8fea89c158517
scope.1.id=function:_build_ctx
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=5790b06701ca27f4
scope.2.id=function:_resolve_registry
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=25
scope.2.semanticHash=96c81d856aa3f81c
scope.3.id=function:_resolve_executor
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=31
scope.3.semanticHash=aefe25a01ccc9b12
scope.4.id=function:_can_apply
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=40
scope.4.semanticHash=648570689928653c
scope.5.id=function:_build_scan_entry
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=51
scope.5.semanticHash=c614d7e8b8b894f2
scope.6.id=function:effect_runner.scan
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=63
scope.6.semanticHash=4e3676a7b7404058
scope.7.id=function:effect_runner.execute
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=74
scope.7.semanticHash=a8815ba844738c60
scope.8.id=function:_resolve_phase
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=81
scope.8.semanticHash=9a8390f429e66ed0
scope.9.id=function:_resolve_effect_registry
scope.9.kind=function
scope.9.startLine=83
scope.9.endLine=89
scope.9.semanticHash=b613da1c648c0ada
scope.10.id=function:effect_runner.build_game_ctx
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=101
scope.10.semanticHash=29d4d3b94cb8f3bd
]]
