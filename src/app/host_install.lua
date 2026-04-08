local runtime_context = require("src.host.context")
local default_ports = require("src.host.default_ports")
local runtime_ports = require("src.core.ports.runtime_ports")
local global_aliases = require("src.host.global_aliases")
local paid_purchase_port = require("src.rules.market.ports.paid_purchase_port")
local config_sanity = require("src.config.gameplay.config_sanity")

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
  local runtime_ctx = _install_context(opts.install_globals == true)
  runtime_ports.configure(default_ports.build(runtime_context))
end

local function _load_required_modules()
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  require "src.rules.endgame.bankruptcy"
  require "src.computer.core_agent"
  require "src.rules.endgame.game_victory"
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
