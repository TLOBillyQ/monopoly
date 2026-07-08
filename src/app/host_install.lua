local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local global_aliases = require("src.host.global_aliases")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local achievement_progress_port = require("src.rules.ports.achievement_progress")
local config_sanity = require("src.config.gameplay.config_sanity")
local runtime_assets = require("src.config.runtime_assets")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_equip = require("src.rules.cosmetics")
local achievement_runtime = require("src.app.host_integrations.achievement_runtime")
local host_runtime = require("src.host.init")
local local_actor_resolver = require("src.ui.coord.local_actor_resolver")
local sign_in = require("src.app.host_integrations.sign_in")

local M = {}

local function _reject_removed_options(opts)
  if opts.context_policy ~= nil then
    error("context_policy option removed; runtime install is strict-only")
  end
  if opts.enable_legacy_helper_fallback ~= nil then
    error("enable_legacy_helper_fallback option removed; runtime install is strict-only")
  end
end

local function _install_context(install_globals)
  local runtime_ctx = runtime_context.new({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  })
  runtime_context.set_current(runtime_ctx)
  runtime_context.install_environment(runtime_ctx)
  global_aliases.install(runtime_ctx.env)
  runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = install_globals })
  return runtime_ctx
end

local function _setup_context(opts)
  if opts.skip_context_install == true then
    runtime_context.set_current(nil)
    return
  end
  _install_context(opts.install_globals == true)
  runtime_ports.configure(default_ports.build(runtime_context))
end

local function _resolve_ui_sync_ports(state)
  local ports = state and (state._resolved_gameplay_loop_ports or state.gameplay_loop_ports) or nil
  local ui_sync = type(ports) == "table" and ports.ui_sync or nil
  if type(ui_sync) ~= "table" or type(ui_sync.refresh_from_dirty) ~= "function" then
    return nil
  end
  return ui_sync
end

local function _refresh_sign_in_reward_ui(game, state)
  if game == nil or state == nil or type(game.consume_dirty) ~= "function" then
    return false
  end
  local ui_sync = _resolve_ui_sync_ports(state)
  if ui_sync == nil then
    return false
  end
  local dirty = game:consume_dirty()
  return ui_sync.refresh_from_dirty(game, state, dirty)
end

-- Subscribe the host's RewardDay1..7 sign-in events to coin grants. The game and
-- app state only exist after bootstrap, so app/init injects lazy accessors that
-- resolve at event-fire time; without them (e.g. context-only test installs) the
-- wiring is skipped. The claiming player is resolved from the event payload via
-- the shared local-actor resolver (payload.role, then client/local fallback).
local function _wire_sign_in_rewards(opts)
  local get_current_game = opts.get_current_game
  local get_app_state = opts.get_app_state
  if type(get_current_game) ~= "function" or type(get_app_state) ~= "function" then
    return
  end
  sign_in.install({
    register_event = host_runtime.register_custom_event,
    get_game = get_current_game,
    resolve_role_id = function(data)
      return local_actor_resolver.resolve_from_event(get_app_state(), data)
    end,
    after_grant = function(game)
      return _refresh_sign_in_reward_ui(game, get_app_state())
    end,
  })
end

local function _load_required_modules(opts)
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  achievement_progress_port.configure(achievement_runtime.build_port())
  skin_panel.configure_equip(function(role_id, skin)
    local model = skin and runtime_assets.skin_model_for_product(skin.product_id) or nil
    local resource_id = model and model.asset_id or nil
    local equipped = skin_equip.equip(role_id, resource_id)
    if equipped then
      achievement_progress_port.skin_equipped(nil, role_id, skin)
    end
    return equipped
  end)
  skin_panel.configure_unequip(function(role_id)
    return skin_equip.unequip(role_id, runtime_assets.default_skin_model().asset_id)
  end)
  _wire_sign_in_rewards(opts)
  require "src.rules.endgame"
  require "src.computer.agent"
  require "src.app.compose_game"
end

function M.install(opts)
  opts = opts or {}
  config_sanity.validate()
  _reject_removed_options(opts)
  runtime_ports.reset_for_tests()
  paid_purchase_port.reset_for_tests()
  achievement_progress_port.reset_for_tests()
  _setup_context(opts)
  _load_required_modules(opts)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=97f163a815f54bde
scope.0.id=chunk:src/app/host_install.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=103
scope.0.semanticHash=1e6b54f0165416a3
scope.0.lastMutatedAt=2026-06-24T20:06:55Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=15
scope.0.lastMutationKilled=15
scope.1.id=function:_reject_removed_options:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=26
scope.1.semanticHash=b31081e96ea26d15
scope.1.lastMutatedAt=2026-06-24T20:06:55Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_install_context:28
scope.2.kind=function
scope.2.startLine=28
scope.2.endLine=38
scope.2.semanticHash=6b7b072b72a9395c
scope.2.lastMutatedAt=2026-06-24T20:06:55Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_setup_context:40
scope.3.kind=function
scope.3.startLine=40
scope.3.endLine=47
scope.3.semanticHash=b9ec207b26d00b67
scope.3.lastMutatedAt=2026-06-24T20:06:55Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:anonymous@63:63
scope.4.kind=function
scope.4.startLine=63
scope.4.endLine=65
scope.4.semanticHash=792efb48e5525723
scope.5.id=function:_wire_sign_in_rewards:54
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=67
scope.5.semanticHash=78d94fd5e75025d7
scope.5.lastMutatedAt=2026-06-24T20:06:55Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
scope.6.id=function:anonymous@72:72
scope.6.kind=function
scope.6.startLine=72
scope.6.endLine=80
scope.6.semanticHash=06bdecb7c351271c
scope.7.id=function:anonymous@81:81
scope.7.kind=function
scope.7.startLine=81
scope.7.endLine=83
scope.7.semanticHash=da02a876b9e3c6bf
scope.8.id=function:_load_required_modules:69
scope.8.kind=function
scope.8.startLine=69
scope.8.endLine=89
scope.8.semanticHash=db6aa869d0dde430
scope.8.lastMutatedAt=2026-06-24T20:06:55Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=9
scope.8.lastMutationKilled=9
scope.9.id=function:M.install:91
scope.9.kind=function
scope.9.startLine=91
scope.9.endLine=100
scope.9.semanticHash=f22621e541bce19b
scope.9.lastMutatedAt=2026-06-24T20:06:55Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=8
scope.9.lastMutationKilled=8
]]
