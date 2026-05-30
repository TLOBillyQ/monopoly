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

local function _load_required_modules()
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  skin_panel.configure_equip(function(role_id, skin)
    -- The host model setter keys off the numeric resource id in refs.skins, not
    -- the human-readable creature_key string in skins.lua; passing the string is
    -- silently ignored by the host ("付了钱没换").
    local resource_id = skin and runtime_refs.skins[tostring(skin.product_id)] or nil
    return skin_equip.equip(role_id, resource_id)
  end)
  skin_purchase.configure(skin_panel)
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
  _load_required_modules()
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=d511dc2b72fccb45
scope.0.id=chunk:src/app/host_install.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=70
scope.0.semanticHash=681529630a845808
scope.0.lastMutatedAt=2026-05-29T12:55:43Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_reject_removed_options:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=21
scope.1.semanticHash=b31081e96ea26d15
scope.1.lastMutatedAt=2026-05-29T12:55:43Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:_install_context:23
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=33
scope.2.semanticHash=6b7b072b72a9395c
scope.2.lastMutatedAt=2026-05-29T12:55:43Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_setup_context:35
scope.3.kind=function
scope.3.startLine=35
scope.3.endLine=42
scope.3.semanticHash=b9ec207b26d00b67
scope.3.lastMutatedAt=2026-05-29T12:55:43Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=5
scope.3.lastMutationKilled=5
scope.4.id=function:anonymous@46:46
scope.4.kind=function
scope.4.startLine=46
scope.4.endLine=52
scope.4.semanticHash=86b325aa1ec11e55
scope.4.lastMutatedAt=2026-05-29T12:55:43Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:_load_required_modules:44
scope.5.kind=function
scope.5.startLine=44
scope.5.endLine=57
scope.5.semanticHash=7954a83a86290051
scope.5.lastMutatedAt=2026-05-29T12:55:43Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=6
scope.5.lastMutationKilled=6
scope.6.id=function:M.install:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=67
scope.6.semanticHash=fa9a81518e134eae
scope.6.lastMutatedAt=2026-05-29T12:55:43Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
]]
