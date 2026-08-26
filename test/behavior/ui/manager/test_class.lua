-- class.lua branch-dense coverage: multi-inheritance lookup, getter/setter resolution.
local lu = require("luaunit")
local Class = require("src.ui.manager.class")

TestClass = {}

function TestClass:test_resolves_methods_from_multiple_parent_classes()
  local A = Class("A")
  function A:a_method() return "A" end
  local B = Class("B")
  function B:b_method() return "B" end
  local C = Class("C", A, B)

  local instance = C:new()

  lu.assertEvalToTrue(instance:a_method() == "A", "should resolve method from first parent")
  lu.assertEvalToTrue(instance:b_method() == "B", "should resolve method from second parent")
end

function TestClass:test_uses_get_as_getter_and_set_as_setter()
  local Widget = Class("Widget")
  function Widget:__get_value() return self._value end
  function Widget:__set_value(v) self._value = v end

  local w = Widget:new()
  w._value = 42

  lu.assertEvalToTrue(w.value == 42, "getter should expose _value")
  w.value = 100
  lu.assertEvalToTrue(w._value == 100, "setter should update _value")
end

function TestClass:test_inherits_get_and_set_from_parent_classes()
  local Base = Class("Base")
  function Base:__get_value() return self._value end
  function Base:__set_value(v) self._value = v end
  local Derived = Class("Derived", Base)

  local d = Derived:new()
  d._value = 7

  lu.assertEvalToTrue(d.value == 7, "derived instance should inherit base getter")
  d.value = 14
  lu.assertEvalToTrue(d._value == 14, "derived instance should inherit base setter")
end

function TestClass:test_prefers_own_getter_setter_over_inherited_ones()
  local Base = Class("Base")
  function Base:__get_value() return "base" end
  function Base:__set_value(v) self._base_value = v end
  local Derived = Class("Derived", Base)
  function Derived:__get_value() return "derived" end
  function Derived:__set_value(v) self._derived_value = v end

  local d = Derived:new()

  lu.assertEvalToTrue(d.value == "derived", "own getter should shadow inherited getter")
  d.value = 1
  lu.assertEvalToTrue(d._derived_value == 1, "own setter should shadow inherited setter")
  lu.assertEvalToTrue(d._base_value == nil, "inherited setter should not run")
end

function TestClass:test_resolves_methods_and_getters_across_more_than_one_inheritance_level()
  local Grand = Class("Grand")
  function Grand:grand_method() return "grand" end
  function Grand:__get_depth() return "grand_depth" end
  local Mid = Class("Mid", Grand)
  local Leaf = Class("Leaf", Mid)

  local leaf = Leaf:new()

  lu.assertEvalToTrue(leaf:grand_method() == "grand", "grandparent method must resolve through the middle class")
  lu.assertEvalToTrue(leaf.depth == "grand_depth", "grandparent getter must resolve through the middle class")
end

function TestClass:test_prefers_the_first_declared_parent_when_both_parents_define_a_member()
  local First = Class("First")
  function First:tag() return "first" end
  function First:__get_label() return "first_label" end
  local Second = Class("Second")
  function Second:tag() return "second" end
  function Second:__get_label() return "second_label" end
  local Both = Class("Both", First, Second)

  local instance = Both:new()

  lu.assertEvalToTrue(instance:tag() == "first", "declaration order must decide which parent wins")
  lu.assertEvalToTrue(instance.label == "first_label", "declaration order must decide which parent getter wins")
end

function TestClass:test_falls_back_to_rawset_when_no_setter_is_found()
  local Box = Class("Box")
  local b = Box:new()
  b.color = "red"

  lu.assertEvalToTrue(b.color == "red", "plain field should be readable after rawset")
  lu.assertEvalToTrue(rawget(b, "color") == "red", "plain field should be stored on instance")
end


return TestClass
