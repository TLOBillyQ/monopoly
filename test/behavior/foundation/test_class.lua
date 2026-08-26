-- foundation.class 最小类系统直测:Class(name) 造类、:new 造实例、init 构造、实例方法解析、实例隔离。
local lu = require("luaunit")
local Class = require("src.foundation.class")
-- 窄 suite 子集(mutate 车道)没有全量车道的加载序兜底,缺共享运行时端口基线时补装
-- (#217 守卫同款 restore,基线已在位时 no-op)。
do
  local baseline_guard = require("test.support.runtime_baseline_guard")
  if #baseline_guard.missing_ports() > 0 then
    baseline_guard.restore()
  end
end

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 Test* 类(无钩子不拆),断言词汇
-- 切到 lu.assertXxx,用例数与改写前一一对应(5 例)。
TestClass = {}

function TestClass:test_class_name_returns_a_class_table_tagged_with_name_and_a_new_factory()
  local Widget = Class("Widget")
  _assert_eq(Widget.__name, "Widget", "class carries its name")
  _assert_eq(type(Widget.new), "function", "class exposes a :new factory")
end

function TestClass:test_new_instances_resolve_methods_defined_on_the_class_table()
  local Counter = Class("Counter")
  function Counter:bump()
    return "bumped"
  end
  local instance = Counter:new()
  _assert_eq(instance:bump(), "bumped", "instance method resolves via metatable")
end

function TestClass:test_new_runs_the_lowercase_init_constructor_with_the_instance_as_self()
  local Point = Class("Point")
  function Point:init(x, y)
    self.x = x
    self.y = y
  end
  local point = Point:new(3, 4)
  _assert_eq(point.x, 3, "init received first arg")
  _assert_eq(point.y, 4, "init received second arg")
end

function TestClass:test_new_works_for_classes_without_any_init_constructor()
  local Bare = Class("Bare")
  local instance = Bare:new()
  _assert_eq(type(instance), "table", "instance is created even with no init")
end

function TestClass:test_distinct_instances_hold_independent_state()
  local Box = Class("Box")
  function Box:init(value)
    self.value = value
  end
  local first = Box:new("a")
  local second = Box:new("b")
  _assert_eq(first.value, "a", "first instance keeps its own value")
  _assert_eq(second.value, "b", "second instance keeps its own value")
  lu.assertNotIs(first, second, "instances are distinct references")
end


return TestClass
