-- einputfield.lua branch-dense coverage: __update_text 双分支(client_role 定向 / allroles 广播)。
-- 双分支实现已收口到 host_push.push(见 host_push_spec),这里从属性入口穿过去覆盖。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local EInputField = require("src.ui.manager.einputfield")
-- 底座加载时自备共享运行时端口基线(#217 窄 suite 子集无全量车道加载序兜底)。
require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown,共享 local calls 留在文件级(setUp 重置,闭包共享),用例数与改写前一致(3 例)。

local calls

local function _make_role(roleid)
  return {
    get_roleid = function() return roleid end,
    set_input_field_text = function(node_id, text)
      calls[#calls + 1] = { roleid = roleid, node_id = node_id, text = text }
    end,
  }
end

local function _clear_context()
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
  -- host_push 每次推送都重读 context.allroles,原地增删即可。
  for i = #context.allroles, 1, -1 do
    context.allroles[i] = nil
  end
  context.client_role = nil
end

TestEInputField = {}

function TestEInputField:setUp()
  _clear_context()
  calls = {}
end

function TestEInputField:tearDown()
  _clear_context()
end

function TestEInputField:test_init_defaults_text_to_empty_string_without_touching_the_host()
  local field = EInputField:new(401, "empty_field")

  lu.assertEvalToTrue(field.text == "", "text should default to empty string")
  lu.assertEvalToTrue(#calls == 0, "init should not push text to the host")
end

function TestEInputField:test_text_setter_pushes_the_text_to_the_client_role_only()
  context.client_role = _make_role(7)
  table.insert(context.allroles, _make_role(101))
  local field = EInputField:new(402, "client_field")

  field.text = "hello"

  lu.assertEvalToTrue(field.text == "hello", "getter should read back the stored text")
  lu.assertEvalToTrue(#calls == 1, ("expected exactly 1 host call, got %d"):format(#calls))
  lu.assertEvalToTrue(calls[1].roleid == 7, "client_role should be the only receiver")
  lu.assertEvalToTrue(calls[1].node_id == 402, "host should receive the node id")
  lu.assertEvalToTrue(calls[1].text == "hello", "host should receive the new text")
end

function TestEInputField:test_text_setter_broadcasts_to_all_roles_when_no_client_role()
  table.insert(context.allroles, _make_role(101))
  table.insert(context.allroles, _make_role(102))
  local field = EInputField:new(403, "broadcast_field")

  field.text = "hello"

  lu.assertEvalToTrue(#calls == 2, ("expected one host call per role, got %d"):format(#calls))
  lu.assertEvalToTrue(calls[1].roleid == 101 and calls[2].roleid == 102, "should broadcast in allroles order")
  lu.assertEvalToTrue(calls[1].node_id == 403 and calls[2].node_id == 403, "host should receive the node id")
  lu.assertEvalToTrue(calls[1].text == "hello" and calls[2].text == "hello", "host should receive the new text")
end


return TestEInputField
