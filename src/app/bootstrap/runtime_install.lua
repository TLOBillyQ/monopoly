local runtime_context = require("src.core.runtime_facade.runtime_context")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_global_aliases = require("src.app.bootstrap.runtime_install.runtime_global_aliases")
local runtime_port_defaults = require("src.app.bootstrap.runtime_install.runtime_port_defaults")
local config_sanity = require("src.core.config.config_sanity")

local M = {}

function M.install(opts)
  opts = opts or {}
  config_sanity.validate()
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
    runtime_global_aliases.install(runtime_ctx.env)
    runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = install_globals })
    runtime_context.install_editor_exports(runtime_ctx)
  else
    runtime_context.set_current(nil)
  end

  runtime_ports.configure(runtime_port_defaults.build())
  require "src.game.core.runtime.bankruptcy"
  require "src.game.core.ai.agent"
  require "src.game.core.runtime.game_victory"
  require "src.game.core.runtime.composition_root"
end

return M
