local bootstrap = require("spec.bootstrap")

bootstrap.install_package_paths()

local function _assert(condition, message)
  if not condition then
    error(message or "assertion failed", 2)
  end
end

local function _test_helper_loads()
  local ok, mod = pcall(require, "spec.helper")
  _assert(ok, "spec.helper should load without error: " .. tostring(mod))
  _assert(mod ~= nil, "spec.helper should return a non-nil value")
end

local function _test_env_runtime_loads()
  package.loaded["spec.env_runtime"] = nil
  local ok, mod = pcall(require, "spec.env_runtime")
  _assert(ok, "spec.env_runtime should load without error: " .. tostring(mod))
  _assert(type(mod) == "table", "spec.env_runtime should return a table")
  _assert(type(mod.refresh) == "function", "spec.env_runtime.refresh should be a function")
end

local function _test_log_warns_handler_syntax_valid()
  local chunk, err = loadfile("spec/log_warns_handler.lua")
  _assert(chunk ~= nil, "spec/log_warns_handler.lua should be syntactically valid: " .. tostring(err))
end

local function _test_behavior_warns_data_has_entries()
  local chunk, err = loadfile("docs/reports/behavior_warns_data.lua")
  _assert(chunk ~= nil, "behavior_warns_data.lua should load: " .. tostring(err))
  local data = chunk()
  _assert(type(data) == "table", "behavior_warns_data should return a table")
  _assert(type(data.whitelist) == "table", "behavior_warns_data.whitelist should be a table")
  local count = 0
  for _ in pairs(data.whitelist) do
    count = count + 1
  end
  _assert(count > 0, "behavior_warns_data.whitelist should have at least one entry")
end

return {
  name = "busted_infra_tooling",
  tests = {
    { name = "spec_helper_loads", run = _test_helper_loads },
    { name = "env_runtime_loads", run = _test_env_runtime_loads },
    { name = "log_warns_handler_syntax_valid", run = _test_log_warns_handler_syntax_valid },
    { name = "behavior_warns_data_has_entries", run = _test_behavior_warns_data_has_entries },
  },
}
