local dirty_tracker = require("src.state.dirty_tracker")
local game_state = require("src.state.game_state")
local turn_runtime = require("src.turn.scheduler")
local bootstrap = require("src.rules.bootstrap")
local game_factory = require("src.app.game_factory")
local phase_registry = require("src.turn.phases.registry")
local status_ops = require("src.player.actions.status")
local balance_ops = require("src.player.actions.balance")
local deity_ops = require("src.player.actions.deity")
local location_ops = require("src.player.actions.location")
local game_victory = require("src.rules.endgame")
local cosmetics_port = require("src.ui.seams.cosmetics")
local cosmetics_transaction = require("src.app.cosmetics.transaction")
local cosmetics_transaction_state = require("src.app.cosmetics.transaction_state")
local game_defaults = require("src.app.game_defaults")

local function _install_class_mixin(target_class, source_table, source_name)
  for key, fn in pairs(source_table) do
    assert(target_class[key] == nil, "compose_game mixin collision: " .. tostring(source_name) .. "." .. tostring(key))
    target_class[key] = fn
  end
end

local _player_state_groups = {
  { name = "status_ops", source = status_ops },
  { name = "balance_ops", source = balance_ops },
  { name = "deity_ops", source = deity_ops },
  { name = "location_ops", source = location_ops },
}

for _, group in ipairs(_player_state_groups) do
  _install_class_mixin(game_state, group.source, group.name)
end

game_state.check_victory = game_victory.check_victory

-- cosmetics port 装配(工单 #244):ui.ports.cosmetics 是纯接口壳,transaction
-- 实现在组合根注入,与 mixin 安装同住 compose_game(ADR 0001)。
cosmetics_port.install({
  transaction = cosmetics_transaction,
  transaction_state = cosmetics_transaction_state,
})

local composition_root = {}

local function _assemble(opts, game_or_class)
  assert(opts ~= nil, "missing assemble opts")

  local board = game_factory.build_board(opts)
  local players = game_factory.build_players(opts)

  game_defaults.init_tile_state(board)

  local dirty = dirty_tracker.new()

  for _, p in ipairs(players) do
    p.inventory._on_change = function()
      dirty_tracker.mark_inventory(dirty)
    end
  end

  local registries = bootstrap.create_registries()
  local phases = phase_registry.build_default_phases()
  local game = game_or_class
  if game_defaults.is_class_like(game_or_class) then
    game = game_or_class:new(opts)
  end
  assert(game, "CompositionRoot.Assemble requires game instance or class")

  game_defaults.apply_game_defaults(game, opts, board, players, dirty)

  game.registries = registries
  game.effect_registry = registries.effects

  game:rebuild()
  game.turn_runtime = turn_runtime:new(game, phases)

  return game
end

function composition_root.new_game(opts, game_class)
  local target_game_class = game_class or game_state
  local game = target_game_class:new(opts)
  if type(game) ~= "table" or type(game.rebuild) ~= "function" then
    return game
  end
  return _assemble(opts, game)
end

return composition_root

--[[ mutate4lua-manifest
version=4
projectHash=f8e6a626bc24334f
scope.0.id=chunk:src/app/compose_game.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=91
scope.0.semanticHash=a333e5298942f2ca
scope.1.id=function:_install_class_mixin
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=22
scope.1.semanticHash=3994960082292d32
scope.2.id=function:_assemble
scope.2.kind=function
scope.2.startLine=46
scope.2.endLine=79
scope.2.semanticHash=6893c0120e013a29
scope.3.id=function:p.inventory._on_change
scope.3.kind=function
scope.3.startLine=57
scope.3.endLine=59
scope.3.semanticHash=600a75ce96a391b3
scope.4.id=function:composition_root.new_game
scope.4.kind=function
scope.4.startLine=81
scope.4.endLine=88
scope.4.semanticHash=7ed2ccc2449650ce
]]
