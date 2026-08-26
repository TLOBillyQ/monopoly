-- array.lua 直测:自定义下标读写、append/pop/length/forEach 语义、length 只读。
-- 宿主无关(纯数据结构),底座仅用于窄车道共享基线自备(#217)。
local lu = require("luaunit")
local Array = require("src.ui.manager.array")
require("test.support.ui_manager_nodes_support")

TestArray = {}

function TestArray:test_init_starts_empty_with_length_zero()
  local arr = Array:new()

  lu.assertEvalToTrue(arr.length == 0, "length should start at 0")
  lu.assertEvalToTrue(arr[1] == nil, "no element at index 1")
end

function TestArray:test_append_grows_length_and_stores_elements_in_order()
  local arr = Array:new()

  arr:append("a")
  arr:append("b")

  lu.assertEvalToTrue(arr.length == 2, "length should be 2 after two appends")
  lu.assertEvalToTrue(arr[1] == "a", "first element")
  lu.assertEvalToTrue(arr[2] == "b", "second element")
end

function TestArray:test_direct_index_assignment_shadows_on_the_instance_without_touching_the_backing_array()
  -- class.lua 的 __newindex 只路由 __set_<key>,无 setter 时 rawset 到实例上;
  -- length 由 append/pop 维护,不随实例直写变化(现状钉死)。
  local arr = Array:new()

  arr[1] = "x"

  lu.assertEvalToTrue(arr[1] == "x", "instance-level write reads back")
  lu.assertEvalToTrue(arr.length == 0, "length is maintained by append/pop only")
end

function TestArray:test_pop_returns_the_last_element_and_shrinks_length()
  local arr = Array:new()
  arr:append("a")
  arr:append("b")

  local popped = arr:pop()

  lu.assertEvalToTrue(popped == "b", "pop returns last element")
  lu.assertEvalToTrue(arr.length == 1, "length shrinks by one")
  lu.assertEvalToTrue(arr[2] == nil, "slot cleared after pop")
end

function TestArray:test_for_each_visits_every_element_in_order()
  local arr = Array:new()
  arr:append(10)
  arr:append(20)
  arr:append(30)

  local seen = {}
  arr:forEach(function(e)
    seen[#seen + 1] = e
  end)

  lu.assertEvalToTrue(#seen == 3, "forEach visits all elements")
  lu.assertEvalToTrue(seen[1] == 10 and seen[2] == 20 and seen[3] == 30, "forEach order preserved")
end

function TestArray:test_assigning_length_raises_the_read_only_error()
  local arr = Array:new()

  local ok, err = pcall(function()
    arr.length = 5
  end)

  lu.assertEvalToTrue(ok == false, "length assignment must error")
  lu.assertEvalToTrue(tostring(err):find("read%-only") ~= nil, "error mentions read-only")
end


return TestArray
