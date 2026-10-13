-- 属性入口覆盖 client_role 定向与 allroles 广播。
local luassert = assert
local context = require("src.ui.manager.context")
local EInputField = require("src.ui.manager.einputfield")
require("test.support.ui_manager_nodes_support")

describe("TestEInputField", function()
  local calls
  local function make_role(roleid)
    return {
      get_roleid = function() return roleid end,
      set_input_field_text = function(node_id, text)
        calls[#calls + 1] = { roleid = roleid, node_id = node_id, text = text }
      end,
    }
  end
  local function clear_context()
    for k in pairs(context.nodes_list) do context.nodes_list[k] = nil end
    for i = #context.allroles, 1, -1 do context.allroles[i] = nil end
    context.client_role = nil
  end
  before_each(function()
    clear_context()
    calls = {}
  end)
  after_each(clear_context)
  it("test_init_defaults_text_to_empty_string_without_touching_the_host", function()
    local field = EInputField:new(401, "empty_field")
    luassert.truthy(field.text == "", "text should default to empty string")
    luassert.truthy(#calls == 0, "init should not push text to the host")
  end)
  it("test_text_setter_pushes_the_text_to_the_client_role_only", function()
    context.client_role = make_role(7)
    table.insert(context.allroles, make_role(101))
    local field = EInputField:new(402, "client_field")
    field.text = "hello"
    luassert.truthy(field.text == "hello", "getter should read back the stored text")
    luassert.truthy(#calls == 1, ("expected exactly 1 host call, got %d"):format(#calls))
    luassert.truthy(calls[1].roleid == 7, "client_role should be the only receiver")
    luassert.truthy(calls[1].node_id == 402, "host should receive the node id")
    luassert.truthy(calls[1].text == "hello", "host should receive the new text")
  end)
  it("test_text_setter_broadcasts_to_all_roles_when_no_client_role", function()
    table.insert(context.allroles, make_role(101))
    table.insert(context.allroles, make_role(102))
    local field = EInputField:new(403, "broadcast_field")
    field.text = "hello"
    luassert.truthy(#calls == 2, ("expected one host call per role, got %d"):format(#calls))
    luassert.truthy(calls[1].roleid == 101 and calls[2].roleid == 102, "should broadcast in allroles order")
    luassert.truthy(calls[1].node_id == 403 and calls[2].node_id == 403, "host should receive the node id")
    luassert.truthy(calls[1].text == "hello" and calls[2].text == "hello", "host should receive the new text")
  end)
end)
