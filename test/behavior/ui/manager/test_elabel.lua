-- elabel.lua 映射覆盖:每个字段 -> (推送方法名, 参数序),从 ELabel 属性入口穿过去断言宿主收到的调用。
-- 「推给谁」的分支决策(client_role 定向 / allroles 广播)由 host_push.push 独占,已在 host_push_spec
-- 单点钉死;本 spec 只守映射表,不重复广播分支,单角色触发一次推送即可定位断言。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local ELabel = require("src.ui.manager.elabel")
local support = require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown,共享 local calls 留在文件级(setUp 重置,闭包共享),cases 驱动的
-- 动态用例转成 TestELabel["test_<name>"] 方法,用例数与改写前一致(14 + 5 = 19 例)。

local calls

-- 录制型 role:除 get_roleid 外任何 set_label_* 调用都记账。
local function _make_role(roleid)
  return setmetatable({
    get_roleid = function() return roleid end,
  }, {
    __index = function(_, method)
      return function(...)
        calls[#calls + 1] = { roleid = roleid, method = method, args = table.pack(...) }
      end
    end,
  })
end

local function _clear_context()
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
  -- host_push 每次推送都重读 context.allroles,原地增删即可(整表替换也能生效,但没必要)。
  for i = #context.allroles, 1, -1 do
    context.allroles[i] = nil
  end
  context.client_role = nil
end

-- 每个 case:通过公开属性赋值触发 __set_* -> __update_*,断言宿主收到的调用。
-- transition_time 默认 0.0(见 ELabel:init),所以带过渡时间的 setter 期望第三参为 0.0。
local cases = {
  { field = "text", value = "hello", method = "set_label_text", args = { "hello" } },
  {
    field = "label_background_color",
    value = 0xFF0000,
    method = "set_label_background_color",
    args = { 0xFF0000, 0.0 },
  },
  {
    field = "label_background_opacity",
    value = 0.25,
    method = "set_label_background_opacity",
    args = { 0.25, 0.0 },
  },
  { field = "text_color", value = 0x00FF00, method = "set_label_color", args = { 0x00FF00, 0.0 } },
  { field = "font_family", value = "eggy_bold", method = "set_label_font", args = { "eggy_bold" } },
  { field = "font_size", value = 24, method = "set_label_font_size", args = { 24, 0.0 } },
  { field = "outline_color", value = 0x0000FF, method = "set_label_outline_color", args = { 0x0000FF } },
  { field = "outline", value = true, method = "set_label_outline_enabled", args = { true } },
  { field = "outline_opacity", value = 0.5, method = "set_label_outline_opacity", args = { 0.5 } },
  { field = "outline_width", value = 2.0, method = "set_label_outline_width", args = { 2.0 } },
  { field = "shadow_color", value = 0x123456, method = "set_label_shadow_color", args = { 0x123456 } },
  { field = "shadow", value = true, method = "set_label_shadow_enabled", args = { true } },
  { field = "shadow_x_offset", value = 3.0, method = "set_label_shadow_x_offset", args = { 3.0 } },
  { field = "shadow_y_offset", value = 4.0, method = "set_label_shadow_y_offset", args = { 4.0 } },
}

local function _assert_call(call, expected_method, node_id, expected_args)
  lu.assertEvalToTrue(call.method == expected_method,
    ("expected host method %s, got %s"):format(expected_method, tostring(call.method)))
  lu.assertEvalToTrue(call.args[1] == node_id, "first host arg should be the node id")
  lu.assertEvalToTrue(call.args.n == #expected_args + 1,
    ("%s should receive %d args"):format(expected_method, #expected_args + 1))
  for i, expected in ipairs(expected_args) do
    lu.assertEvalToTrue(call.args[i + 1] == expected,
      ("%s arg #%d expected %s, got %s"):format(
        expected_method, i + 1, tostring(expected), tostring(call.args[i + 1])))
  end
end

TestELabel = {}

function TestELabel:setUp()
  _clear_context()
  support.install_host_math()
  calls = {}
end

function TestELabel:tearDown()
  _clear_context()
  support.restore_host_math()
end

for _, case in ipairs(cases) do
  local case_name = ("test_%s setter pushes %s with the mapped args"):format(case.field, case.method)
  TestELabel[case_name] = function(self)
    table.insert(context.allroles, _make_role(101))
    local label = ELabel:new(301, "label_" .. case.field)

    label[case.field] = case.value

    lu.assertEvalToTrue(#calls == 1, ("expected exactly 1 host call, got %d"):format(#calls))
    _assert_call(calls[1], case.method, 301, case.args)
  end
end

function TestELabel:test_getters_read_back_what_the_setters_stored()
  table.insert(context.allroles, _make_role(101))
  local label = ELabel:new(303, "getters")

  for _, case in ipairs(cases) do
    label[case.field] = case.value
    lu.assertEvalToTrue(label[case.field] == case.value,
      ("getter for %s should return the value written"):format(case.field))
  end
end

function TestELabel:test_init_defaults_text_to_empty_string_and_transition_time_to_zero()
  local label = ELabel:new(304, "defaults")

  lu.assertEvalToTrue(label.text == "", "text should default to empty string")
  lu.assertEvalToTrue(label.transition_time == 0.0, "transition_time should default to 0.0")
  lu.assertEvalToTrue(#calls == 0, "init should not touch the host")
end

function TestELabel:test_transition_time_setter_stores_a_fixed_value_without_touching_the_host()
  table.insert(context.allroles, _make_role(101))
  local label = ELabel:new(305, "transition")

  label.transition_time = 1.5

  lu.assertEvalToTrue(label.transition_time == 1.5, "transition_time should read back")
  lu.assertEvalToTrue(#calls == 0, "transition_time is not pushed to the host on its own")
end

function TestELabel:test_transition_time_is_forwarded_to_the_host_by_transitioned_setters()
  table.insert(context.allroles, _make_role(101))
  local label = ELabel:new(306, "transition_forwarded")
  label.transition_time = 2.0

  label.text_color = 0xABCDEF

  lu.assertEvalToTrue(#calls == 1, "expected one host call")
  _assert_call(calls[1], "set_label_color", 306, { 0xABCDEF, 2.0 })
end

-- label_background_opacity 曾是本类唯一一处拼写不一致的属性(#210):访问器与
-- setter 写的字段是 ...opactiy,updater 读的却是 ...opacity,两条路都设不上值。
-- 名字对齐后它与 label_background_color 同形,故由上面的通用 cases 表覆盖;
-- 这条钉住拼错的名字不再是可用属性面,防止旧写法悄悄复活。
function TestELabel:test_the_misspelled_label_background_opactiy_is_not_an_accessor_anymore()
  context.client_role = _make_role(7)
  local label = ELabel:new(307, "opacity_typo")

  label.label_background_opactiy = 0.25

  lu.assertEvalToTrue(#calls == 0, "the misspelled name must not reach the host")
end


return TestELabel
