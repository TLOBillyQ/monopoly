-- array_read_only.lua 直测:只读视图透传底层 Array 的元素读、变更方法 fail-fast 报错。
-- #267：append/pop 报错（不穿透、不静默），索引写仅遮蔽视图实例。
-- 宿主无关(纯数据结构),底座仅用于窄车道共享基线自备(#217)。
local lu = require("luaunit")
local luax = require("test.support.luax")
local Array = require("src.ui.manager.array")
local ArrayReadOnly = require("src.ui.manager.array_read_only")
require("test.support.ui_manager_nodes_support")

TestArrayReadOnly = {}

do
  local function _make_backing()
    local arr = Array:new()
    arr:append("a")
    arr:append("b")
    return arr
  end

  function TestArrayReadOnly:test_reads_pass_through_to_the_backing_array()
    local ro = ArrayReadOnly:new(_make_backing())

    lu.assertEvalToTrue(ro.length == 2, "length mirrors backing array")
    lu.assertEvalToTrue(ro[1] == "a", "index 1 passes through")
    lu.assertEvalToTrue(ro[2] == "b", "index 2 passes through")
  end

  function TestArrayReadOnly:test_length_tracks_backing_array_growth()
    local backing = _make_backing()
    local ro = ArrayReadOnly:new(backing)

    backing:append("c")

    lu.assertEvalToTrue(ro.length == 3, "length reflects later appends on the backing array")
  end

  function TestArrayReadOnly:test_append_raises_and_leaves_the_backing_array_untouched()
    -- #267:穿透曾借到 Array.append 写坏共享 backing(data 与 length 脱节);
    -- 裁定为 fail-fast 报错(与 Array:__set_length 同款)。
    local backing = _make_backing()
    local ro = ArrayReadOnly:new(backing)

    luax.has_error(function()
      ro:append("z")
    end, "ArrayReadOnly is read-only")

    lu.assertEvalToTrue(backing.length == 2, "backing length unchanged")
    lu.assertEvalToTrue(backing[1] == "a" and backing[2] == "b", "backing elements unchanged")
  end

  function TestArrayReadOnly:test_pop_raises_and_leaves_the_backing_array_untouched()
    local backing = _make_backing()
    local ro = ArrayReadOnly:new(backing)

    luax.has_error(function()
      ro:pop()
    end, "ArrayReadOnly is read-only")

    lu.assertEvalToTrue(backing.length == 2, "backing length unchanged")
  end

  function TestArrayReadOnly:test_read_methods_resolve_from_the_views_own_class_chain_not_the_backing_instance()
    -- __custom_index 只代理数值下标（元素读），方法名落回类链（#267）；
    -- forEach 等只读方法经父类 Array 解析,行为与穿透期一致。
    local backing = _make_backing()
    local ro = ArrayReadOnly:new(backing)

    local seen = {}
    ro:forEach(function(e)
      seen[#seen + 1] = e
    end)

    lu.assertEvalToTrue(#seen == 2 and seen[1] == "a" and seen[2] == "b", "forEach iterates backing elements")
    lu.assertEvalToTrue(ro.forEach == ArrayReadOnly.forEach, "read method resolves from the view's own class")
  end

  function TestArrayReadOnly:test_index_assignment_shadows_on_the_view_without_touching_the_backing_array()
    -- class.lua 的 __newindex 无 __set_<key> 时 rawset 到视图实例上, backing 不受污染(现状钉死)。
    local backing = _make_backing()
    local ro = ArrayReadOnly:new(backing)

    ro[1] = "z"

    lu.assertEvalToTrue(ro[1] == "z", "instance shadow wins on read")
    lu.assertEvalToTrue(backing[1] == "a", "backing array untouched")
  end

  function TestArrayReadOnly:test_length_assignment_raises_via_the_inherited_array_setter()
    -- __set_length 未覆写,经父类链接解析到 Array 的报错 setter;此 case 同时钉住
    -- IS-A 父类链接本身(Array 父类被剪掉时此处不报错,退化为 rawset 静默成功)。
    local ro = ArrayReadOnly:new(_make_backing())

    luax.has_error(function()
      ro.length = 99
    end, "Array length is read-only")

    lu.assertEvalToTrue(ro.length == 2, "length still mirrors the backing array")
  end

  function TestArrayReadOnly:test_the_class_keeps_the_array_parent_link_while_owning_its_method_surface()
    -- 父类链接是声明式 IS-A 契约(类表 parents 链);方法面由视图类自带:
    -- forEach 委托 backing,append/pop 覆写为报错,均不再等于父类实现(#267)。
    lu.assertEvalToTrue(ArrayReadOnly.forEach ~= Array.forEach, "forEach is owned by the view class")
    lu.assertEvalToTrue(ArrayReadOnly.append ~= Array.append, "mutator is overridden on the view class")
    lu.assertEvalToTrue(ArrayReadOnly.pop ~= Array.pop, "mutator is overridden on the view class")
  end
end


return TestArrayReadOnly
