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

local function _cancel_fallback(_, choice)
  return { type = "choice_cancel", choice_id = choice and choice.id }
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

local function _is_release_build(build_mode)
  return build_mode == "release"
end

local function _resolve_startup_map(startup)
  if _is_release_build(startup and startup.build_mode) then
    return default_map
  end
  return require("src.app.profile_source").resolve_map()
end

local function _apply_startup_bootstrap(game, startup)
  if _is_release_build(startup and startup.build_mode) then
    return
  end
  local bootstrap = require("src.app.profile_bootstrap")
  local startup_profile_source = require("src.app.profile_source")
  bootstrap.apply_bootstrap(game, startup_profile_source.resolve_bootstrap(startup))
end

function M.build_game_factory(state, opts)
  assert(state ~= nil, "missing state")
  opts = opts or {}
  local build_mode = opts.build_mode
  local profile_name = opts.profile_name
  local auto_all = opts.auto_all == true
  return function()
    local startup = {
      build_mode = build_mode,
      profile_name = profile_name,
    }
    local map_cfg = _resolve_startup_map(startup)
    local role_roster = roster_roles.build_startup_roster(max_player_count)
    local forced_ai = roster_roles.build_startup_ai_map(role_roster)
    local auto_players = roster_debug.build_auto_players(role_roster, build_mode)
    logger.info("[Eggy]", "使用四槽角色驱动初始化，角色数量:", tostring(#role_roster))
    local created_game = composition_root.new_game(default_ports.resolve_game_opts({
      role_roster = role_roster,
      ai = forced_ai,
      auto_all = auto_all,
      auto_players = auto_players,
      map = map_cfg,
      tiles = tiles_cfg,
    }), app)
    created_game.startup_synthetic_players = roster_roles.build_synthetic_player_specs(role_roster)
    _apply_startup_bootstrap(created_game, startup)
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
version=2
projectHash=8a4c3ad20a4d2d3e
scope.0.id=chunk:src/app/roster.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=85
scope.0.semanticHash=6b6adf733ce6588a
scope.1.id=function:_cancel_fallback:13
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=15
scope.1.semanticHash=1cbbf2b6451d9e7c
scope.2.id=function:_register_default_choice_fallbacks:17
scope.2.kind=function
scope.2.startLine=17
scope.2.endLine=22
scope.2.semanticHash=eace481149fa692a
scope.3.id=function:_is_release_build:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=31
scope.3.semanticHash=057ba3a16cba7256
scope.4.id=function:_resolve_startup_map:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=38
scope.4.semanticHash=c3dc633a818ed107
scope.5.id=function:_apply_startup_bootstrap:40
scope.5.kind=function
scope.5.startLine=40
scope.5.endLine=47
scope.5.semanticHash=dfc7c8ea48b9d3e1
scope.6.id=function:anonymous@54:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=75
scope.6.semanticHash=74b5fadab402f277
scope.7.id=function:M.build_game_factory:49
scope.7.kind=function
scope.7.startLine=49
scope.7.endLine=76
scope.7.semanticHash=65f6a3fd8a8f6f14
scope.8.id=function:M.build_auto_runner:78
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=82
scope.8.semanticHash=e0cc5842194d2bcc
]]
