local vehicle_runtime_source = require("src.state.vehicle_runtime_source")

local _resolve_module = vehicle_runtime_source._M_test._resolve_module

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("runtime vehicle runtime source", function()
  it("resolve module returns value for non-empty string", function()
    _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = "my.module" }), "my.module", "resolve module non-empty string")
  end)

  it("resolve module returns nil for empty string", function()
    _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = "" }), nil, "resolve module empty string")
  end)

  it("resolve module returns nil for nil value", function()
    _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = nil }), nil, "resolve module nil field")
  end)

  it("resolve module returns nil when globals nil", function()
    _assert_eq(_resolve_module(nil), nil, "resolve module nil globals")
  end)

  it("resolve module returns nil for empty globals", function()
    _assert_eq(_resolve_module({}), nil, "resolve module empty globals")
  end)

  it("resolve module returns nil for number value", function()
    _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = 42 }), nil, "resolve module number field")
  end)

  it("resolve module returns nil for boolean value", function()
    _assert_eq(_resolve_module({ VEHICLE_RUNTIME_MODULE = true }), nil, "resolve module boolean field")
  end)
end)
