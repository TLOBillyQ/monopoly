local runtime_context = require("src.core.RuntimeContext")
local runtime_ports = require("src.core.RuntimePorts")

local M = {}

function M.install(opts)
  opts = opts or {}
  local install_globals = opts.install_globals == true
  local runtime_ctx = runtime_context.new({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
  })
  runtime_context.set_current(runtime_ctx)
  runtime_context.install_environment(runtime_ctx)
  runtime_context.install_runtime_helpers(runtime_ctx, { install_globals = install_globals })
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
    resolve_roles = function()
      if runtime_ctx and type(runtime_ctx.roles) == "table" then
        return runtime_ctx.roles
      end
      return {}
    end,
    mark_role_lose = function(role)
      if role and role.lose then
        role.lose()
      end
    end,
    resolve_vehicle_helper = function()
      local key = "vehicle" .. "_helper"
      return runtime_ctx and runtime_ctx[key] or nil
    end,
    resolve_camera_helper = function()
      local key = "camera" .. "_helper"
      return runtime_ctx and runtime_ctx[key] or nil
    end,
    wall_now_seconds = function()
      if GameAPI and type(GameAPI.get_timestamp) == "function" then
        local ok, ts = pcall(GameAPI.get_timestamp)
        if ok and type(ts) == "number" then
          return ts
        end
      end
      return 0
    end,
    wall_diff_seconds = function(timestamp_1, timestamp_2)
      if GameAPI
          and type(GameAPI.get_timestamp_diff) == "function"
          and type(timestamp_1) == "number"
          and type(timestamp_2) == "number" then
        local ok, diff = pcall(GameAPI.get_timestamp_diff, timestamp_1, timestamp_2)
        if ok and type(diff) == "number" then
          return diff
        end
      end
      if type(timestamp_1) == "number" and type(timestamp_2) == "number" then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
    cpu_now_seconds = function()
      if os and type(os.clock) == "function" then
        return os.clock()
      end
      return 0
    end,
    cpu_diff_seconds = function(timestamp_1, timestamp_2)
      if type(timestamp_1) == "number" and type(timestamp_2) == "number" then
        return timestamp_1 - timestamp_2
      end
      return 0
    end,
  })
  require "src.game.core.runtime.Bankruptcy"
  require "src.game.core.runtime.Agent"
  require "src.game.core.runtime.GameVictory"
  require "src.game.core.runtime.CompositionRoot"
end

return M
