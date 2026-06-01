local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local global_aliases = require("src.host.global_aliases")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local config_sanity = require("src.config.gameplay.config_sanity")
local skin_panel = require("src.ui.coord.skin_panel")
local skin_equip = require("src.rules.cosmetics")
local runtime_refs = require("src.config.content.runtime_refs")
local skin_purchase = require("src.app.host_integrations.skin_purchase")
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
  })
end

local function _load_required_modules(opts)
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  skin_panel.configure_equip(function(role_id, skin)
    -- The host model setter keys off the numeric resource id in refs.skins, not
    -- the human-readable creature_key string in skins.lua; passing the string is
    -- silently ignored by the host ("付了钱没换").
    local resource_id = skin and runtime_refs.skins[tostring(skin.product_id)] or nil
    return skin_equip.equip(role_id, resource_id)
  end)
  skin_panel.configure_unequip(function(role_id)
    -- Eggy's runtime exposes reset_model for restoring the player's original
    -- appearance; refs.default_creature is kept only as a compatibility fallback.
    return skin_equip.unequip(role_id, runtime_refs.default_creature)
  end)
  skin_purchase.configure(skin_panel)
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
  _setup_context(opts)
  _load_required_modules(opts)
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=db7131fd9fd49723
scope.0.id=chunk:src/app/host_install.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=85ec6c362126a703
scope.0.lastMutatedAt=2026-05-31T03:28:49Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_reject_removed_options:17
scope.1.kind=function
scope.1.startLine=17
scope.1.endLine=24
scope.1.semanticHash=b31081e96ea26d15
scope.1.lastMutatedAt=2026-05-31T03:28:49Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_install_context:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=36
scope.2.semanticHash=6b7b072b72a9395c
scope.2.lastMutatedAt=2026-05-31T03:28:49Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_setup_context:38
scope.3.kind=function
scope.3.startLine=38
scope.3.endLine=45
scope.3.semanticHash=b9ec207b26d00b67
scope.3.lastMutatedAt=2026-05-31T03:28:49Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:anonymous@61:61
scope.4.kind=function
scope.4.startLine=61
scope.4.endLine=63
scope.4.semanticHash=792efb48e5525723
scope.4.lastMutatedAt=2026-05-31T03:28:49Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:_wire_sign_in_rewards:52
scope.5.kind=function
scope.5.startLine=52
scope.5.endLine=65
scope.5.semanticHash=78d94fd5e75025d7
scope.5.lastMutatedAt=2026-05-31T03:28:49Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
scope.6.id=function:anonymous@69:69
scope.6.kind=function
scope.6.startLine=69
scope.6.endLine=75
scope.6.semanticHash=86b325aa1ec11e55
scope.6.lastMutatedAt=2026-05-31T03:28:49Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=no_sites
scope.6.lastMutationSites=0
scope.6.lastMutationKilled=0
scope.7.id=function:anonymous@76:76
scope.7.kind=function
scope.7.startLine=76
scope.7.endLine=80
scope.7.semanticHash=f7fca92f268d55c7
scope.7.lastMutatedAt=2026-05-31T03:28:49Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=no_sites
scope.7.lastMutationSites=0
scope.7.lastMutationKilled=0
scope.8.id=function:_load_required_modules:67
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=86
scope.8.semanticHash=b07dc5086014d8a2
scope.8.lastMutatedAt=2026-05-31T03:28:49Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=8
scope.8.lastMutationKilled=8
scope.9.id=function:M.install:88
scope.9.kind=function
scope.9.startLine=88
scope.9.endLine=96
scope.9.semanticHash=e2ec9c66df7f9cd0
scope.9.lastMutatedAt=2026-05-31T13:13:42Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=7
scope.9.lastMutationKilled=7
]]
