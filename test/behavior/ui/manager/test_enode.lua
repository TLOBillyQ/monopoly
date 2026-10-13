-- enode.lua branch-dense coverage: __custom_index / __new_custom_index role domain + fallback,
-- visible/disabled 的定向与广播分支,名称查询(含 DFS)与 listen 的事件注册/分发。
local luassert = assert
local context = require("src.ui.manager.context")
local ENode = require("src.ui.manager.enode")
local host_events = require("src.ui.seams.host_events")
local support = require("test.support.ui_manager_nodes_support")

-- 四个显式测试组保留各自钩子边界，角色状态逐例重建，宿主替身逐例恢复。
-- 用例数保持 10 + 6 + 10 + 6 = 32。

local function _clear_context()
  support.clear_context()
end

describe("TestENode", function()
before_each(_clear_context)
after_each(_clear_context)

it("test_custom_index_reads_role_domain_protected_data", function()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(201, "role_node")
  node.client_data[7] = { __protected_test_value = "role_value" }

  luassert.truthy(node.__protected_test_value == "role_value",
    "should read protected value from client_data[roleid]")
end)

it("test_custom_index_falls_back_to_client_data_neg_1_when_role_data_missing", function()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(202, "fallback_node")
  node.client_data[-1].__protected_test_value = "shared_value"

  luassert.truthy(node.__protected_test_value == "shared_value",
    "should fall back to client_data[-1] when role data absent")
end)

it("test_custom_index_falls_back_to_client_data_neg_1_when_role_data_lacks_key", function()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(203, "partial_node")
  node.client_data[7] = {}
  node.client_data[-1].__protected_test_value = "shared_value"

  luassert.truthy(node.__protected_test_value == "shared_value",
    "should fall back to client_data[-1] when role data lacks the key")
end)

it("test_custom_index_reads_client_data_neg_1_when_no_client_role", function()
  local node = ENode:new(204, "global_node")
  node.client_data[-1].__protected_test_value = "shared_value"

  luassert.truthy(node.__protected_test_value == "shared_value",
    "should read from client_data[-1] when client_role is nil")
end)

it("test_new_custom_index_writes_role_domain_protected_data", function()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(205, "write_role_node")

  ENode.__new_custom_index(node, "__protected_test_value", "role_value")

  luassert.truthy(node.client_data[7].__protected_test_value == "role_value",
    "should write protected value into client_data[roleid]")
  luassert.truthy(node.client_data[-1].__protected_test_value == nil,
    "shared fallback should remain untouched")
end)

-- 第二次写同一角色时,__new_custom_index 必须复用已有的 client_data[roleid],
-- 而不是重建空表——否则先写的字段会被后写的字段抹掉。
it("test_new_custom_index_keeps_earlier_role_data_when_a_second_key_is_written", function()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(208, "role_multi_write_node")

  ENode.__new_custom_index(node, "__protected_first", "one")
  ENode.__new_custom_index(node, "__protected_second", "two")

  luassert.truthy(node.client_data[7].__protected_first == "one",
    "the first protected write must survive a later write for the same role")
  luassert.truthy(node.client_data[7].__protected_second == "two",
    "the later protected write should land in the same role bucket")
end)

it("test_new_custom_index_writes_client_data_neg_1_when_no_client_role", function()
  local node = ENode:new(206, "write_global_node")

  ENode.__new_custom_index(node, "__protected_test_value", "shared_value")

  luassert.truthy(node.client_data[-1].__protected_test_value == "shared_value",
    "should write protected value into client_data[-1] when client_role is nil")
end)

it("test_new_custom_index_rawsets_non_protected_keys", function()
  local node = ENode:new(207, "rawset_node")

  ENode.__new_custom_index(node, "foo", "bar")

  luassert.truthy(node.foo == "bar", "non __protected_ key should be rawset on instance")
end)

it("test_set_attribute_and_get_attribtue_round_trip_custom_data", function()
  local node = ENode:new(220, "attr_node")

  node:set_attribute("slot", 3)

  luassert.truthy(node:get_attribtue("slot") == 3, "stored attribute should be readable")
  luassert.truthy(node:get_attribtue("missing") == nil, "unset attribute should read nil")
end)

it("test_custom_data_getter_and_setter_round_trip", function()
  local node = ENode:new(221, "custom_data_node")

  node.custom_data = { kind = "tile" }

  luassert.truthy(node.custom_data.kind == "tile", "custom_data should round-trip through the accessor")
end)

-- -------------------------------------------------- visible / disabled propagation

end)

describe("TestENodeVisibleDisabledPropagation", function()
local role_a, role_b
before_each(function()
  _clear_context()
  role_a = support.make_role(1)
  role_b = support.make_role(2)
end)
after_each(_clear_context)

it("test_visible_targets_only_the_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local node = ENode:new(210, "visible_node")

  node.visible = false

  local calls = support.calls_of(role_a, "set_node_visible")
  luassert.truthy(#calls == 1, "client role should receive set_node_visible once")
  luassert.truthy(calls[1].args[1] == 210, "host call should carry the eui node id")
  luassert.truthy(calls[1].args[2] == false, "host call should carry the new visibility")
  luassert.truthy(#role_b.calls == 0, "other roles should not receive the visibility update")
  luassert.truthy(node.visible == false, "visible getter should report the stored value")
end)

it("test_visible_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local node = ENode:new(211, "visible_all_node")

  node.visible = true

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_node_visible")
    luassert.truthy(#calls == 1 and calls[1].args[2] == true, "every role should receive the visibility update")
  end
end)

it("test_disabled_targets_only_the_client_role_and_inverts_touch_enabled", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local node = ENode:new(212, "disabled_node")

  node.disabled = true

  local calls = support.calls_of(role_a, "set_node_touch_enabled")
  luassert.truthy(#calls == 1, "client role should receive set_node_touch_enabled once")
  luassert.truthy(calls[1].args[1] == 212, "host call should carry the eui node id")
  luassert.truthy(calls[1].args[2] == false, "disabled=true should disable touch")
  luassert.truthy(#role_b.calls == 0, "other roles should not receive the disabled update")
  luassert.truthy(node.disabled == true, "disabled getter should report the stored value")
end)

it("test_disabled_broadcasts_to_all_roles_when_no_client_role", function()
  support.install_roles({ role_a, role_b })
  local node = ENode:new(213, "disabled_all_node")

  node.disabled = false

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_node_touch_enabled")
    luassert.truthy(#calls == 1 and calls[1].args[2] == true, "disabled=false should enable touch for every role")
  end
end)

it("test_for_all_roles_applies_a_setter_to_every_role_and_restores_client_role", function()
  context.client_role = role_a
  support.install_roles({ role_a, role_b })
  local node = ENode:new(214, "for_all_node")

  node:for_all_roles("visible", true)

  for _, role in ipairs({ role_a, role_b }) do
    local calls = support.calls_of(role, "set_node_visible")
    luassert.truthy(#calls == 1 and calls[1].args[2] == true, "for_all_roles should broadcast to every role")
  end
  luassert.truthy(context.client_role == role_a, "for_all_roles should restore the previous client_role")
end)

it("test_for_all_roles_ignores_unknown_keys", function()
  support.install_roles({ role_a })
  local node = ENode:new(215, "unknown_key_node")

  node:for_all_roles("no_such_property", true)

  luassert.truthy(#role_a.calls == 0, "unknown property should not reach the host")
end)

end)

-- -------------------------------------------------- name queries

-- 树: 1 root -> {2 child_a, 3 child_b}; 3 -> {4 deep, 5 child_a}
--
-- 第二棵独立的树钉 dfs 的「找到即收手」:11 自己没有 twin,两条分支各藏一个,
-- 且左分支把命中埋到孙层。只有当命中沿 dfs 一路上报、上层据此停止扫兄弟时,
-- 结果才只有一个。11 -> {12, 13}; 12 -> {14}; 14 -> {16 twin}; 13 -> {15 twin}
local children_map = {
  [1] = { 2, 3 },
  [3] = { 4, 5 },
  [11] = { 12, 13 },
  [12] = { 14 },
  [13] = { 15 },
  [14] = { 16 },
}
local names = {
  [1] = "root",
  [2] = "child_a",
  [3] = "child_b",
  [4] = "deep",
  [5] = "child_a",
  [11] = "twin_root",
  [12] = "twin_branch",
  [13] = "twin_sibling",
  [14] = "twin_mid",
  [15] = "twin",
  [16] = "twin",
}

local function _build_tree()
  for id, name in pairs(names) do
    ENode:new(id, name)
  end
  for id in pairs(children_map) do
    context.nodes_list[id]:__init_children()
  end
  return context.nodes_list[1]
end

describe("TestENodeNameQueries", function()
local original_get_children, original_get_child_by_name
before_each(function()
  _clear_context()
  _G.GameAPI = _G.GameAPI or {}
  original_get_children = _G.GameAPI.get_eui_children
  original_get_child_by_name = _G.GameAPI.get_eui_child_by_name
  _G.GameAPI.get_eui_children = function(id)
    return children_map[id] or {}
  end
  _G.GameAPI.get_eui_child_by_name = function(id, name)
    for _, child_id in ipairs(children_map[id] or {}) do
      if names[child_id] == name then
        return child_id
      end
    end
    return nil
  end
end)

after_each(function()
  _G.GameAPI.get_eui_children = original_get_children
  _G.GameAPI.get_eui_child_by_name = original_get_child_by_name
  _clear_context()
end)

it("test_init_children_links_parents_and_children", function()
  local root = _build_tree()

  luassert.truthy(root.children.length == 2, "root should own two children")
  luassert.truthy(root.children[1].name == "child_a", "children should keep host order")
  luassert.truthy(root.children[1].parent == root, "child parent should point back at root")
end)

it("test_get_first_node_by_name_returns_nil_when_no_direct_child_matches", function()
  local root = _build_tree()

  luassert.truthy(root:get_first_node_by_name("deep") == nil,
    "a grandchild should not be found by the shallow lookup")
  luassert.truthy(root:get_first_node_by_name("child_b").id == 3,
    "a direct child should be found by the shallow lookup")
end)

it("test_query_nodes_by_name_collects_every_direct_child_with_the_name", function()
  local root = _build_tree()
  local branch = context.nodes_list[3]

  luassert.truthy(#root:query_nodes_by_name("child_a") == 1, "root has one direct child_a")
  luassert.truthy(#root:query_nodes_by_name("deep") == 0, "root has no direct child named deep")
  luassert.truthy(#branch:query_nodes_by_name("child_a") == 1, "branch has one direct child_a")
end)

it("test_get_first_node_by_name_dfs_finds_a_direct_child_without_recursing", function()
  local root = _build_tree()

  local node = root:get_first_node_by_name_dfs("child_b")

  luassert.truthy(node ~= nil and node.id == 3, "direct child should be returned immediately")
end)

it("test_get_first_node_by_name_dfs_descends_into_children", function()
  local root = _build_tree()

  local node = root:get_first_node_by_name_dfs("deep")

  luassert.truthy(node ~= nil and node.id == 4, "grandchild should be found via depth-first descent")
end)

it("test_get_first_node_by_name_dfs_returns_nil_when_the_name_is_absent", function()
  local root = _build_tree()

  luassert.truthy(root:get_first_node_by_name_dfs("missing") == nil,
    "absent names should yield nil after the whole subtree is scanned")
end)

it("test_query_nodes_by_name_dfs_stops_at_the_first_matching_node", function()
  local root = _build_tree()

  local list = root:query_nodes_by_name_dfs("child_a")

  luassert.truthy(#list == 1, "dfs query should stop at the first match")
  luassert.truthy(list[1].id == 2, "the shallowest match should win")
end)

-- 命中在孙层、另一条兄弟分支也藏着同名节点:上报链一旦断掉(命中不再返回 true,
-- 或中间层不把子树的命中往上传),扫描会继续吃掉第二条分支,收到两个节点。
it("test_query_nodes_by_name_dfs_stops_scanning_siblings_once_a_deep_match_is_found", function()
  _build_tree()
  local twin_root = context.nodes_list[11]

  local list = twin_root:query_nodes_by_name_dfs("twin")

  luassert.truthy(#list == 1, "a match found deep in the first branch must stop the sibling scan")
  luassert.truthy(list[1].id == 16, "the first branch's grandchild should be the only result")
end)

it("test_query_nodes_by_name_dfs_descends_when_no_direct_child_matches", function()
  local root = _build_tree()

  local list = root:query_nodes_by_name_dfs("deep")

  luassert.truthy(#list == 1 and list[1].id == 4, "dfs query should find the grandchild")
end)

it("test_query_nodes_by_name_dfs_returns_an_empty_list_when_the_name_is_absent", function()
  local root = _build_tree()

  luassert.truthy(#root:query_nodes_by_name_dfs("missing") == 0,
    "absent names should yield an empty list")
end)

end)

-- -------------------------------------------------- listen

local registered

local function _stub_register(ok, trigger)
  _G.GameAPI = _G.GameAPI or {}
  host_events.register_custom_event = function(event, handler)
    registered[#registered + 1] = { event = event, handler = handler }
    return ok, trigger
  end
end

describe("TestENodeListen", function()
local original_register
before_each(function()
  _clear_context()
  registered = {}
  original_register = host_events.register_custom_event
end)

after_each(function()
  host_events.register_custom_event = original_register
  _clear_context()
end)

it("test_registers_the_host_event_once_and_stores_the_trigger", function()
  _stub_register(true, 999)
  local node_a = ENode:new(230, "listen_a")
  local node_b = ENode:new(231, "listen_b")

  local listener = node_a:listen("click", function() end)
  node_b:listen("click", function() end)

  luassert.truthy(#registered == 1, "the host event should only be registered for the first listener")
  luassert.truthy(registered[1].event == "click", "the host registration should carry the event name")
  luassert.truthy(context.event_handlers["click"].trigger == 999,
    "the trigger handle returned by the host should be stored")
  luassert.truthy(listener._event == "click", "the listener should remember its event")
  luassert.truthy(listener._node_id == 230, "the listener should remember its node id")
end)

it("test_stores_no_trigger_when_the_host_refuses_to_register", function()
  _stub_register(false, 999)
  local node = ENode:new(232, "listen_failed")

  node:listen("click", function() end)

  luassert.truthy(context.event_handlers["click"].trigger == nil,
    "a failed registration should not store a trigger handle")
end)

it("test_appends_further_callbacks_on_the_same_node", function()
  _stub_register(true, 999)
  local node = ENode:new(233, "listen_multi")
  local cb1 = function() end
  local cb2 = function() end

  local first = node:listen("click", cb1)
  local second = node:listen("click", cb2)

  local handler_data = context.event_handlers["click"][233]
  luassert.truthy(#handler_data.callbacks == 2, "both callbacks should be registered on the node")
  luassert.truthy(handler_data.callbacks[1] == cb1 and handler_data.callbacks[2] == cb2,
    "callbacks should keep registration order")
  luassert.truthy(first ~= second, "each listen call should return its own listener")
  luassert.truthy(second._callback == cb2, "the listener should remember its own callback")
end)

it("test_dispatches_host_events_to_the_node_callbacks_with_the_acting_role", function()
  _stub_register(true, 999)
  local node = ENode:new(234, "listen_dispatch")
  local role = { get_roleid = function() return 7 end }
  local seen = {}

  local listener = node:listen("click", function(data)
    seen[#seen + 1] = data
    seen.role_during_callback = context.client_role
  end)

  registered[1].handler(nil, nil, { eui_node_id = 234, role = role })

  luassert.truthy(#seen == 1, "the callback should fire once")
  luassert.truthy(seen[1].role == role, "the callback should receive the acting role")
  luassert.truthy(seen[1].target == node, "the callback should receive the node as target")
  luassert.truthy(seen[1].listener == listener, "the callback should receive the listener")
  luassert.truthy(seen.role_during_callback == role, "client_role should be bound during dispatch")
  luassert.truthy(context.client_role == nil, "client_role should be cleared after dispatch")
end)

it("test_ignores_host_events_for_nodes_without_handlers", function()
  _stub_register(true, 999)
  local node = ENode:new(235, "listen_other")
  local fired = 0
  node:listen("click", function() fired = fired + 1 end)

  registered[1].handler(nil, nil, { eui_node_id = 999, role = {} })

  luassert.truthy(fired == 0, "a host event for an unregistered node should not fire callbacks")
  luassert.truthy(context.client_role == nil, "client_role should stay unset for unhandled events")
end)

it("test_skips_dispatch_when_the_node_is_flagged_disabled", function()
  _stub_register(true, 999)
  local node = ENode:new(236, "listen_disabled")
  local fired = 0
  node:listen("click", function() fired = fired + 1 end)
  node._disabled = true

  registered[1].handler(nil, nil, { eui_node_id = 236, role = {} })

  luassert.truthy(fired == 0, "a disabled node should not receive event callbacks")
end)


end)
