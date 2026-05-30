---@diagnostic disable: need-check-nil, different-requires, undefined-field, duplicate-set-field

local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local host_types = require("src.foundation.host_types")

describe("host_types", function()
  it("vec3 returns plain-table fallback in host without math.Vector3", function()
    local original = math.Vector3
    math.Vector3 = nil
    local v = host_types.vec3(1.0, 2.0, 3.0)
    math.Vector3 = original
    _assert_eq(v.x, 1.0, "x")
    _assert_eq(v.y, 2.0, "y")
    _assert_eq(v.z, 3.0, "z")
  end)

  it("vec3 delegates to math.Vector3 when present", function()
    local original = math.Vector3
    local captured
    math.Vector3 = function(x, y, z)
      captured = { x = x, y = y, z = z, native = true }
      return captured
    end
    local v = host_types.vec3(4.0, 5.0, 6.0)
    math.Vector3 = original
    _assert_eq(v.native, true, "result came from math.Vector3 branch")
    _assert_eq(v.x, 4.0, "x")
    _assert_eq(v.y, 5.0, "y")
    _assert_eq(v.z, 6.0, "z")
  end)

  it("quat returns plain-table fallback in host without math.Quaternion", function()
    local original = math.Quaternion
    math.Quaternion = nil
    local q = host_types.quat(7.0, 8.0, 9.0)
    math.Quaternion = original
    _assert_eq(q.x, 7.0, "x")
    _assert_eq(q.y, 8.0, "y")
    _assert_eq(q.z, 9.0, "z")
  end)

  it("quat delegates to math.Quaternion when present", function()
    local original = math.Quaternion
    local captured
    math.Quaternion = function(x, y, z)
      captured = { x = x, y = y, z = z, native = true }
      return captured
    end
    local q = host_types.quat(10.0, 11.0, 12.0)
    math.Quaternion = original
    _assert_eq(q.native, true, "result came from math.Quaternion branch")
    _assert_eq(q.x, 10.0, "x")
    _assert_eq(q.y, 11.0, "y")
    _assert_eq(q.z, 12.0, "z")
  end)
end)
