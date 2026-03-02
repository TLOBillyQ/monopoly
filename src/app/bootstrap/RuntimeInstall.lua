local runtime_context = require("src.core.RuntimeContext")
local runtime_ports = require("src.core.RuntimePorts")
local runtime_port_defaults = require("src.app.bootstrap.runtime_install.RuntimePortDefaults")

local M = {}

function M.install(opts)
  opts = opts or {}
  local install_globals = opts.install_globals == true
  if opts.context_policy ~= nil then
    error("context_policy option removed; runtime install is strict-only")
  end
  if opts.enable_legacy_helper_fallback ~= nil then
    error("enable_legacy_helper_fallback option removed; runtime install is strict-only")
  end
  local skip_context_install = opts.skip_context_install == true

  local runtime_ctx = nil
  if not skip_context_install then
    runtime_ctx = runtime_context.new({
      GameAPI = GameAPI,
      LuaAPI = LuaAPI,
    })
    runtime_context.set_current(runtime_ctx)
    runtime_context.install_environment(runtime_ctx)
    runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = install_globals })
    runtime_context.install_editor_exports(runtime_ctx)
  else
    runtime_context.set_current(nil)
  end

  runtime_ports.configure(runtime_port_defaults.build())
  require "src.game.core.runtime.Bankruptcy"
  require "src.game.core.runtime.Agent"
  require "src.game.core.runtime.GameVictory"
  require "src.game.core.runtime.CompositionRoot"
end

return M
