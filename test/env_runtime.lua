require("test.bootstrap")

local test_env = require("test.support.env")
local project = require("test.guards.config.env_runtime")

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
    camera_helper = camera_helper,
  })
end

local function refresh_runtime_services()
  return project.refresh_services(refresh_runtime_context)
end

function M.refresh()
  test_env.install_defaults()
  refresh_runtime_context()
  refresh_runtime_services()
end

M.refresh_runtime_context = refresh_runtime_context
M.refresh_runtime_services = refresh_runtime_services

return M
