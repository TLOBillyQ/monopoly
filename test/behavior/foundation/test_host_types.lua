---@diagnostic disable: need-check-nil, different-requires, undefined-field, duplicate-set-field

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local host_types = require("src.foundation.host_types")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 Test* 类(无钩子不拆),断言仍走
-- shared_support.assert_eq(实参序已对),用例数与改写前一一对应(9 例)。
TestHostTypes = {}

function TestHostTypes:test_vec3_returns_plain_table_fallback_in_host_without_math_vector3()
  local original = math.Vector3
  math.Vector3 = nil
  local v = host_types.vec3(1.0, 2.0, 3.0)
  math.Vector3 = original
  _assert_eq(v.x, 1.0, "x")
  _assert_eq(v.y, 2.0, "y")
  _assert_eq(v.z, 3.0, "z")
end

function TestHostTypes:test_vec3_delegates_to_math_vector3_when_present()
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
end

function TestHostTypes:test_quat_returns_plain_table_fallback_in_host_without_math_quaternion()
  local original = math.Quaternion
  math.Quaternion = nil
  local q = host_types.quat(7.0, 8.0, 9.0)
  math.Quaternion = original
  _assert_eq(q.x, 7.0, "x")
  _assert_eq(q.y, 8.0, "y")
  _assert_eq(q.z, 9.0, "z")
end

function TestHostTypes:test_quat_delegates_to_math_quaternion_when_present()
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
end

-- 宿主对象的 type() 返回宿主类名而不是 "table"（真机取证 #266：Role 是
-- "CampRole"），所以 field / method 一律鸭子判定。本机造不出 CampRole，
-- 但 io.stdout 是货真价实的 userdata，type() 同样不是 "table"，用它当替身
-- 就能钉死「不靠 type(x) == \"table\" 把门」这条契约。
function TestHostTypes:test_method_resolves_a_method_on_a_non_table_host_object()
  _assert_eq(type(io.stdout) ~= "table", true, "io.stdout stands in for a host object")
  _assert_eq(type(host_types.method(io.stdout, "write")), "function", "userdata method resolved")
end

function TestHostTypes:test_field_reads_a_value_from_a_non_table_host_object()
  _assert_eq(host_types.field(io.stdout, "write") ~= nil, true, "userdata field resolved")
end

function TestHostTypes:test_field_returns_nil_instead_of_raising_when_indexing_throws()
  local exploding = setmetatable({}, {
    __index = function()
      error("host object refused indexing")
    end,
  })
  _assert_eq(host_types.field(exploding, "anything"), nil, "throwing __index yields nil")
  _assert_eq(host_types.method(exploding, "anything"), nil, "throwing __index yields no method")
end

function TestHostTypes:test_field_and_method_return_nil_for_nil_and_scalar_subjects()
  _assert_eq(host_types.field(nil, "x"), nil, "nil subject")
  _assert_eq(host_types.field(42, "x"), nil, "number subject")
  _assert_eq(host_types.method(nil, "x"), nil, "nil subject has no method")
  _assert_eq(host_types.method("text", "x"), nil, "string subject has no arbitrary method")
end

function TestHostTypes:test_method_rejects_a_field_that_is_not_callable()
  local obj = { ready = true, run = function() end }
  _assert_eq(host_types.field(obj, "ready"), true, "plain field still readable")
  _assert_eq(host_types.method(obj, "ready"), nil, "non-function field is not a method")
  _assert_eq(type(host_types.method(obj, "run")), "function", "function field is a method")
end


return TestHostTypes
