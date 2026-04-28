local vehicle_runtime_source = require("src.state.vehicle_runtime_source")

local _resolve_module = vehicle_runtime_source._M_test._resolve_module

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function test_resolve_module_returns_value_for_non_empty_string()
  _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = "my.module" }), "my.module", "resolve module non-empty string")
end

local function test_resolve_module_returns_nil_for_empty_string()
  _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = "" }), nil, "resolve module empty string")
end

local function test_resolve_module_returns_nil_for_nil_value()
  _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = nil }), nil, "resolve module nil field")
end

local function test_resolve_module_returns_nil_when_globals_nil()
  _assert_eq(_resolve_module(nil), nil, "resolve module nil globals")
end

local function test_resolve_module_returns_nil_for_empty_globals()
  _assert_eq(_resolve_module({}), nil, "resolve module empty globals")
end

local function test_resolve_module_returns_nil_for_number_value()
  _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = 42 }), nil, "resolve module number field")
end

local function test_resolve_module_returns_nil_for_boolean_value()
  _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = true }), nil, "resolve module boolean field")
end

return {
  name = "runtime vehicle runtime source",
  tests = {
    { name = "resolve module returns value for non-empty string", run = test_resolve_module_returns_value_for_non_empty_string },
    { name = "resolve module returns nil for empty string", run = test_resolve_module_returns_nil_for_empty_string },
    { name = "resolve module returns nil for nil value", run = test_resolve_module_returns_nil_for_nil_value },
    { name = "resolve module returns nil when globals nil", run = test_resolve_module_returns_nil_when_globals_nil },
    { name = "resolve module returns nil for empty globals", run = test_resolve_module_returns_nil_for_empty_globals },
    { name = "resolve module returns nil for number value", run = test_resolve_module_returns_nil_for_number_value },
    { name = "resolve module returns nil for boolean value", run = test_resolve_module_returns_nil_for_boolean_value },
  },
}
