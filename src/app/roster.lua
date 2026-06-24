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
      auto_all = false,
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
projectHash=d211e1f9b5f1328f
scope.0.id=chunk:src/app/roster.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=254
scope.0.semanticHash=504be644752abfc6
scope.1.id=function:_cancel_fallback:15
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=17
scope.1.semanticHash=1cbbf2b6451d9e7c
scope.2.id=function:_register_default_choice_fallbacks:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=24
scope.2.semanticHash=eace481149fa692a
scope.3.id=function:_is_release_build:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=37
scope.3.semanticHash=057ba3a16cba7256
scope.4.id=function:_resolve_startup_map:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=44
scope.4.semanticHash=c3dc633a818ed107
scope.5.id=function:_apply_startup_bootstrap:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=53
scope.5.semanticHash=dfc7c8ea48b9d3e1
scope.6.id=function:_resolve_roles:55
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=66
scope.6.semanticHash=03c325872a09863b
scope.7.id=function:_resolve_role_id_from_role:91
scope.7.kind=function
scope.7.startLine=91
scope.7.endLine=100
scope.7.semanticHash=72691274297ca755
scope.8.id=function:_resolve_role_name:102
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=111
scope.8.semanticHash=f6fb9c5baf5759b1
scope.9.id=function:_build_synthetic_role:127
scope.9.kind=function
scope.9.startLine=127
scope.9.endLine=136
scope.9.semanticHash=717de4f8bb572882
scope.10.id=function:_warn_if_roles_truncated:147
scope.10.kind=function
scope.10.startLine=147
scope.10.endLine=157
scope.10.semanticHash=bec44c9209eabe17
scope.11.id=function:_build_startup_roster:159
scope.11.kind=function
scope.11.startLine=159
scope.11.endLine=168
scope.11.semanticHash=2eab39001cffff63
scope.12.id=function:anonymous@223:223
scope.12.kind=function
scope.12.startLine=223
scope.12.endLine=244
scope.12.semanticHash=8594f1cdcacd5071
scope.13.id=function:M.build_game_factory:218
scope.13.kind=function
scope.13.startLine=218
scope.13.endLine=245
scope.13.semanticHash=2925f3503b617ec2
scope.14.id=function:M.build_auto_runner:247
scope.14.kind=function
scope.14.startLine=247
scope.14.endLine=251
scope.14.semanticHash=e0cc5842194d2bcc
]]
