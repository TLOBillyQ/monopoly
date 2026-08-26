local auto_runner = require("src.turn.policies.auto_runner")
local composition_root = require("src.app.compose_game")
local app = require("src.state.game_state")
local tiles_cfg = require("src.config.content.tiles")
local default_map = require("src.config.content.default_map")
local timing = require("src.config.gameplay.timing")
local default_ports = require("src.turn.output.default_ports")
local logger = require("src.foundation.log")
local fallback_registry = require("src.rules.choice.fallback_registry")
local roster_roles = require("src.app.roster_roles")
local roster_debug = require("src.app.roster_debug")

local function _choice_id(choice)
  return choice and choice.id
end

local function _cancel_fallback(_, choice)
  return { type = "choice_cancel", choice_id = _choice_id(choice) }
end

local function _register_default_choice_fallbacks()
  fallback_registry.register("market_buy", _cancel_fallback)
  fallback_registry.register("item_target_tile", _cancel_fallback)
  fallback_registry.register("item_target_player", _cancel_fallback)
  fallback_registry.register("steal_target", _cancel_fallback)
end

_register_default_choice_fallbacks()

local max_player_count = 4
local M = {}

function M.build_game_factory(state, opts)
  assert(state ~= nil, "missing state")
  opts = opts or {}
  local auto_all = opts.auto_all == true
  return function()
    local role_roster = roster_roles.build_startup_roster(max_player_count)
    local forced_ai = roster_roles.build_startup_ai_map(role_roster)
    local auto_players = roster_debug.build_auto_players(role_roster)
    logger.info("[Eggy]", "使用四槽角色驱动初始化，角色数量:", tostring(#role_roster))
    local created_game = composition_root.new_game(default_ports.resolve_game_opts({
      role_roster = role_roster,
      ai = forced_ai,
      auto_all = auto_all,
      auto_players = auto_players,
      map = default_map,
      tiles = tiles_cfg,
    }), app)
    created_game.startup_synthetic_players = roster_roles.build_synthetic_player_specs(role_roster)
    return created_game
  end
end

function M.build_auto_runner()
  return auto_runner:new({
    interval = timing.auto_decision_delay_seconds,
  })
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=6402a9aa4f03850e
scope.0.id=chunk:src/app/roster.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=58
scope.0.semanticHash=4dc41db733734d9e
scope.1.id=function:_cancel_fallback
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=6e0309ec5f8749ad
scope.2.id=function:_register_default_choice_fallbacks
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=b7b450e2eba9b170
scope.3.id=function:M.build_game_factory
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=49
scope.3.semanticHash=318bda32eb3d0264
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=48
scope.4.semanticHash=bd5049bd3bd2ee32
scope.5.id=function:M.build_auto_runner
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=55
scope.5.semanticHash=3b21c8109bea78b9
]]
