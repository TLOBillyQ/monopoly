local runtime_context = require("src.infrastructure.runtime.context")
local default_ports = require("src.infrastructure.runtime.default_ports")
local runtime_ports = require("src.core.ports.runtime_ports")
local runtime_global_aliases = require("src.app.bootstrap.runtime.global_aliases")
local paid_purchase_port = require("src.game.systems.market.ports.paid_purchase_port")
local config_sanity = require("src.config.gameplay.config_sanity")

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

  runtime_ports.reset_for_tests()
  paid_purchase_port.reset_for_tests()
  if runtime_ctx ~= nil then
    runtime_ports.configure(default_ports.build(runtime_context))
  end
  paid_purchase_port.configure(require("src.app.bootstrap.payment.eggy_paid_purchase_gateway"))
  require "src.game.systems.endgame.bankruptcy"
  require "src.game.ai.agent"
  require "src.game.systems.endgame.game_victory"
  require "src.game.core.runtime.composition_root"
end

return M
