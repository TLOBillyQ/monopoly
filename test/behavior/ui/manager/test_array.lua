-- array.lua 直测:自定义下标读写、append/pop/length/forEach 语义、length 只读。
-- 宿主无关(纯数据结构),底座仅用于窄车道共享基线自备(#217)。
local luassert = assert
local Array = require("src.ui.manager.array")
require("test.support.ui_manager_nodes_support")

describe("TestArray", function()

it("test_init_starts_empty_with_length_zero", function()
  local arr = Array:new()

  luassert.truthy(arr.length == 0, "length should start at 0")
  luassert.truthy(arr[1] == nil, "no element at index 1")
end)

it("test_append_grows_length_and_stores_elements_in_order", function()
  local arr = Array:new()

  arr:append("a")
  arr:append("b")

  luassert.truthy(arr.length == 2, "length should be 2 after two appends")
  luassert.truthy(arr[1] == "a", "first element")
  luassert.truthy(arr[2] == "b", "second element")
end)

it("test_direct_index_assignment_shadows_on_the_instance_without_touching_the_backing_array", function()
  -- class.lua 的 __newindex 只路由 __set_<key>,无 setter 时 rawset 到实例上;
  -- length 由 append/pop 维护,不随实例直写变化(现状钉死)。
  local arr = Array:new()

  arr[1] = "x"

  luassert.truthy(arr[1] == "x", "instance-level write reads back")
  luassert.truthy(arr.length == 0, "length is maintained by append/pop only")
end)

it("test_pop_returns_the_last_element_and_shrinks_length", function()
  local arr = Array:new()
  arr:append("a")
  arr:append("b")

  local popped = arr:pop()

  luassert.truthy(popped == "b", "pop returns last element")
  luassert.truthy(arr.length == 1, "length shrinks by one")
  luassert.truthy(arr[2] == nil, "slot cleared after pop")
end)

it("test_for_each_visits_every_element_in_order", function()
  local arr = Array:new()
  arr:append(10)
  arr:append(20)
  arr:append(30)

  local seen = {}
  arr:forEach(function(e)
    seen[#seen + 1] = e
  end)

  luassert.truthy(#seen == 3, "forEach visits all elements")
  luassert.truthy(seen[1] == 10 and seen[2] == 20 and seen[3] == 30, "forEach order preserved")
end)

it("test_assigning_length_raises_the_read_only_error", function()
  local arr = Array:new()

  local ok, err = pcall(function()
    arr.length = 5
  end)

  luassert.truthy(ok == false, "length assignment must error")
  luassert.truthy(tostring(err):find("read%-only") ~= nil, "error mentions read-only")
end)


end)
