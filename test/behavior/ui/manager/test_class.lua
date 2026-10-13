-- class.lua branch-dense coverage: multi-inheritance lookup, getter/setter resolution.
local luassert = assert
local Class = require("src.ui.manager.class")

describe("TestClass", function()

it("test_resolves_methods_from_multiple_parent_classes", function()
  local A = Class("A")
  function A:a_method() return "A" end
  local B = Class("B")
  function B:b_method() return "B" end
  local C = Class("C", A, B)

  local instance = C:new()

  luassert.truthy(instance:a_method() == "A", "should resolve method from first parent")
  luassert.truthy(instance:b_method() == "B", "should resolve method from second parent")
end)

it("test_uses_get_as_getter_and_set_as_setter", function()
  local Widget = Class("Widget")
  function Widget:__get_value() return self._value end
  function Widget:__set_value(v) self._value = v end

  local w = Widget:new()
  w._value = 42

  luassert.truthy(w.value == 42, "getter should expose _value")
  w.value = 100
  luassert.truthy(w._value == 100, "setter should update _value")
end)

it("test_inherits_get_and_set_from_parent_classes", function()
  local Base = Class("Base")
  function Base:__get_value() return self._value end
  function Base:__set_value(v) self._value = v end
  local Derived = Class("Derived", Base)

  local d = Derived:new()
  d._value = 7

  luassert.truthy(d.value == 7, "derived instance should inherit base getter")
  d.value = 14
  luassert.truthy(d._value == 14, "derived instance should inherit base setter")
end)

it("test_prefers_own_getter_setter_over_inherited_ones", function()
  local Base = Class("Base")
  function Base:__get_value() return "base" end
  function Base:__set_value(v) self._base_value = v end
  local Derived = Class("Derived", Base)
  function Derived:__get_value() return "derived" end
  function Derived:__set_value(v) self._derived_value = v end

  local d = Derived:new()

  luassert.truthy(d.value == "derived", "own getter should shadow inherited getter")
  d.value = 1
  luassert.truthy(d._derived_value == 1, "own setter should shadow inherited setter")
  luassert.truthy(d._base_value == nil, "inherited setter should not run")
end)

it("test_resolves_methods_and_getters_across_more_than_one_inheritance_level", function()
  local Grand = Class("Grand")
  function Grand:grand_method() return "grand" end
  function Grand:__get_depth() return "grand_depth" end
  local Mid = Class("Mid", Grand)
  local Leaf = Class("Leaf", Mid)

  local leaf = Leaf:new()

  luassert.truthy(leaf:grand_method() == "grand", "grandparent method must resolve through the middle class")
  luassert.truthy(leaf.depth == "grand_depth", "grandparent getter must resolve through the middle class")
end)

it("test_prefers_the_first_declared_parent_when_both_parents_define_a_member", function()
  local First = Class("First")
  function First:tag() return "first" end
  function First:__get_label() return "first_label" end
  local Second = Class("Second")
  function Second:tag() return "second" end
  function Second:__get_label() return "second_label" end
  local Both = Class("Both", First, Second)

  local instance = Both:new()

  luassert.truthy(instance:tag() == "first", "declaration order must decide which parent wins")
  luassert.truthy(instance.label == "first_label", "declaration order must decide which parent getter wins")
end)

it("test_falls_back_to_rawset_when_no_setter_is_found", function()
  local Box = Class("Box")
  local b = Box:new()
  b.color = "red"

  luassert.truthy(b.color == "red", "plain field should be readable after rawset")
  luassert.truthy(rawget(b, "color") == "red", "plain field should be stored on instance")
end)


end)
