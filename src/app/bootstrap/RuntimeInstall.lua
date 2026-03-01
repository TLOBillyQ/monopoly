local runtime_context = require("src.core.RuntimeContext")
local runtime_ports = require("src.core.RuntimePorts")

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
  runtime_ports.configure({
    rng_next_int = function(min, max)
      assert(GameAPI and GameAPI.random_int, "missing GameAPI.random_int")
      return GameAPI.random_int(min, max)
    end,
    schedule = function(delay, fn)
      assert(type(fn) == "function", "schedule requires callback")
      assert(SetTimeOut ~= nil, "missing SetTimeOut")
      SetTimeOut(delay or 0, fn)
    end,
    resolve_role = function(player_id)
      if player_id == nil then
        return nil
      end
      if not (GameAPI and GameAPI.get_role) then
        return nil
      end
      local ok, role = pcall(GameAPI.get_role, player_id)
      if not ok then
        return nil
      end
      return role
    end,
    mark_role_lose = function(role)
      if role and role.lose then
        role.lose()
      end
    end,
  })
  require "src.game.core.runtime.Bankruptcy"
  require "src.game.core.runtime.Agent"
  require "src.game.core.runtime.GameVictory"
  require "src.game.core.runtime.CompositionRoot"
end

return M
