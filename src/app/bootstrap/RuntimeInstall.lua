local runtime_context = require("src.core.RuntimeContext")

local M = {}

function M.install()
  local runtime_ctx = runtime_context.new({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  })
  runtime_context.set_current(runtime_ctx)
  runtime_context.install_environment(runtime_ctx)
  runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = true })
  runtime_context.install_editor_exports(runtime_ctx)
  require "src.game.core.runtime.Bankruptcy"
  require "src.game.core.runtime.Agent"
  require "src.game.core.runtime.GameVictory"
  require "src.game.core.runtime.CompositionRoot"
end

return M
