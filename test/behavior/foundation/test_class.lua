-- Real busted pilot: the same five class behaviors and identity assertions.
require("test.bootstrap").install_package_paths()
local luassert = assert
local Class = require("src.foundation.class")
local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end

describe("TestClass", function()
  it("test_class_name_returns_a_class_table_tagged_with_name_and_a_new_factory", function()
    local Widget = Class("Widget")
    _assert_eq(Widget.__name, "Widget", "class carries its name")
    _assert_eq(type(Widget.new), "function", "class exposes a :new factory")
  end)
  it("test_new_instances_resolve_methods_defined_on_the_class_table", function()
    local Counter = Class("Counter")
    function Counter:bump() return "bumped" end
    local instance = Counter:new()
    _assert_eq(instance:bump(), "bumped", "instance method resolves via metatable")
  end)
  it("test_new_runs_the_lowercase_init_constructor_with_the_instance_as_self", function()
    local Point = Class("Point")
    function Point:init(x, y) self.x = x; self.y = y end
    local point = Point:new(3, 4)
    _assert_eq(point.x, 3, "init received first arg")
    _assert_eq(point.y, 4, "init received second arg")
  end)
  it("test_new_works_for_classes_without_any_init_constructor", function()
    local Bare = Class("Bare")
    local instance = Bare:new()
    _assert_eq(type(instance), "table", "instance is created even with no init")
  end)
  it("test_distinct_instances_hold_independent_state", function()
    local Box = Class("Box")
    function Box:init(value) self.value = value end
    local first, second = Box:new("a"), Box:new("b")
    _assert_eq(first.value, "a", "first instance keeps its own value")
    _assert_eq(second.value, "b", "second instance keeps its own value")
    luassert.is_not(second, first, "instances are distinct references")
  end)
end)
