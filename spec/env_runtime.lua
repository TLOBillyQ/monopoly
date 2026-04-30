require("spec.bootstrap")

local logger = require("src.foundation.log.logger")
local tip_queue = require("src.foundation.coordination.tip_queue")
local runtime_context = require("src.host.context")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_default_ports = require("src.host.default_ports")
local paid_purchase_port = require("src.rules.market.paid_purchase_port")
local test_env = require("spec.support.test_env")

local M = {}

local function refresh_runtime_context()
  return test_env.refresh_runtime_context_for_tests({
    GameAPI = GameAPI,
    LuaAPI = LuaAPI,
    GlobalAPI = GlobalAPI,
    SetTimeOut = SetTimeOut,
    RegisterCustomEvent = RegisterCustomEvent,
    TriggerCustomEvent = TriggerCustomEvent,
    all_roles = all_roles,
    ALLROLES = ALLROLES,
    vehicle_helper = vehicle_helper,
    camera_helper = camera_helper,
  })
end

local function refresh_runtime_services()
  local ctx = runtime_context.current()
  if ctx == nil or ctx.env == nil then
    return refresh_runtime_context()
  end

  runtime_ports.reset_for_tests()
  runtime_ports.configure(runtime_default_ports.build(runtime_context))
  paid_purchase_port.reset_for_tests()
  paid_purchase_port.configure(require("src.host.paid_purchase_gateway"))
  tip_queue.clear()
  tip_queue.configure_runtime({
    presenter = function(text, duration)
      if GlobalAPI and type(GlobalAPI.show_tips) == "function" then
        return GlobalAPI.show_tips(text, duration)
      end
      return false
    end,
    scheduler = function(delay, fn)
      if type(SetTimeOut) == "function" then
        return SetTimeOut(delay, fn)
      end
      if fn then
        fn()
        return true
      end
      return false
    end,
    test_mode = logger.is_test_mode(),
  })
  if GameAPI ~= nil
      and type(GameAPI.get_timestamp) == "function"
      and type(GameAPI.get_hour) == "function"
      and type(GameAPI.get_minute) == "function"
      and type(GameAPI.get_second) == "function" then
    logger.configure_game_time(GameAPI)
  else
    logger.reset_time_runtime()
  end
  return ctx
end

function M.refresh()
  test_env.install_defaults()
  refresh_runtime_context()
  refresh_runtime_services()
end

M.refresh_runtime_context = refresh_runtime_context
M.refresh_runtime_services = refresh_runtime_services

return M
