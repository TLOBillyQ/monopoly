-- enode.lua branch-dense coverage: __custom_index / __new_custom_index role domain + fallback,
-- visible/disabled 的定向与广播分支,名称查询(含 DFS)与 listen 的事件注册/分发。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local ENode = require("src.ui.manager.enode")
local host_events = require("src.ui.seams.host_events")
local support = require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 按钩子边界拍平成四个 Test* 类——外层(含无钩子的
-- attributes 子描述)为 TestENode;带钩子的嵌套 describe(visible/disabled、name
-- queries、listen)拆子类,子类 setUp 首行调父 setUp、tearDown 末行调父 tearDown;
-- 共享 local 收成 self 字段(role_a/role_b)或文件级(children_map/names 等只读
-- 数据、registered 等 setUp 重置变量),用例数与改写前一致(8+2 + 6 + 10 + 6 = 32 例)。

local function _clear_context()
  support.clear_context()
end

TestENode = {}

function TestENode:setUp()
  _clear_context()
end

function TestENode:tearDown()
  _clear_context()
end

function TestENode:test_custom_index_reads_role_domain_protected_data()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(201, "role_node")
  node.client_data[7] = { __protected_test_value = "role_value" }

  lu.assertEvalToTrue(node.__protected_test_value == "role_value",
    "should read protected value from client_data[roleid]")
end

function TestENode:test_custom_index_falls_back_to_client_data_neg_1_when_role_data_missing()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(202, "fallback_node")
  node.client_data[-1].__protected_test_value = "shared_value"

  lu.assertEvalToTrue(node.__protected_test_value == "shared_value",
    "should fall back to client_data[-1] when role data absent")
end

function TestENode:test_custom_index_falls_back_to_client_data_neg_1_when_role_data_lacks_key()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(203, "partial_node")
  node.client_data[7] = {}
  node.client_data[-1].__protected_test_value = "shared_value"

  lu.assertEvalToTrue(node.__protected_test_value == "shared_value",
    "should fall back to client_data[-1] when role data lacks the key")
end

function TestENode:test_custom_index_reads_client_data_neg_1_when_no_client_role()
  local node = ENode:new(204, "global_node")
  node.client_data[-1].__protected_test_value = "shared_value"

  lu.assertEvalToTrue(node.__protected_test_value == "shared_value",
    "should read from client_data[-1] when client_role is nil")
end

function TestENode:test_new_custom_index_writes_role_domain_protected_data()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(205, "write_role_node")

  ENode.__new_custom_index(node, "__protected_test_value", "role_value")

  lu.assertEvalToTrue(node.client_data[7].__protected_test_value == "role_value",
    "should write protected value into client_data[roleid]")
  lu.assertEvalToTrue(node.client_data[-1].__protected_test_value == nil,
    "shared fallback should remain untouched")
end

-- 第二次写同一角色时,__new_custom_index 必须复用已有的 client_data[roleid],
-- 而不是重建空表——否则先写的字段会被后写的字段抹掉。
function TestENode:test_new_custom_index_keeps_earlier_role_data_when_a_second_key_is_written()
  local role = { get_roleid = function() return 7 end }
  context.client_role = role
  local node = ENode:new(208, "role_multi_write_node")

  ENode.__new_custom_index(node, "__protected_first", "one")
  ENode.__new_custom_index(node, "__protected_second", "two")

  lu.assertEvalToTrue(node.client_data[7].__protected_first == "one",
    "the first protected write must survive a later write for the same role")
  lu.assertEvalToTrue(node.client_data[7].__protected_second == "two",
    "the later protected write should land in the same role bucket")
end

function TestENode:test_new_custom_index_writes_client_data_neg_1_when_no_client_role()
  local node = ENode:new(206, "write_global_node")

  ENode.__new_custom_index(node, "__protected_test_value", "shared_value")

  lu.assertEvalToTrue(node.client_data[-1].__protected_test_value == "shared_value",
    "should write protected value into client_data[-1] when client_role is nil")
end

function TestENode:test_new_custom_index_rawsets_non_protected_keys()
  local node = ENode:new(207, "rawset_node")

  ENode.__new_custom_index(node, "foo", "bar")

  lu.assertEvalToTrue(node.foo == "bar", "non __protected_ key should be rawset on instance")
end

function TestENode:test_set_attribute_and_get_attribtue_round_trip_custom_data()
  local node = ENode:new(220, "attr_node")

  node:set_attribute("slot", 3)

  lu.assertEvalToTrue(node:get_attribtue("slot") == 3, "stored attribute should be readable")
  lu.assertEvalToTrue(node:get_attribtue("missing") == nil, "unset attribute should read nil")
end

function TestENode:test_custom_data_getter_and_setter_round_trip()
  local node = ENode:new(221, "custom_data_node")

  node.custom_data = { kind = "tile" }

  lu.assertEvalToTrue(node.custom_data.kind == "tile", "custom_data should round-trip through the accessor")
end

-- -------------------------------------------------- visible / disabled propagation

TestENodeVisibleDisabledPropagation = {}

function TestENodeVisibleDisabledPropagation:setUp()
  TestENode.setUp(self)
  self.role_a = support.make_role(1)
  self.role_b = support.make_role(2)
end

function TestENodeVisibleDisabledPropagation:tearDown()
  TestENode.tearDown(self)
end

function TestENodeVisibleDisabledPropagation:test_visible_targets_only_the_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local node = ENode:new(210, "visible_node")

  node.visible = false

  local calls = support.calls_of(self.role_a, "set_node_visible")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_node_visible once")
  lu.assertEvalToTrue(calls[1].args[1] == 210, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == false, "host call should carry the new visibility")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the visibility update")
  lu.assertEvalToTrue(node.visible == false, "visible getter should report the stored value")
end

function TestENodeVisibleDisabledPropagation:test_visible_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local node = ENode:new(211, "visible_all_node")

  node.visible = true

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_node_visible")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == true, "every role should receive the visibility update")
  end
end

function TestENodeVisibleDisabledPropagation:test_disabled_targets_only_the_client_role_and_inverts_touch_enabled()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local node = ENode:new(212, "disabled_node")

  node.disabled = true

  local calls = support.calls_of(self.role_a, "set_node_touch_enabled")
  lu.assertEvalToTrue(#calls == 1, "client role should receive set_node_touch_enabled once")
  lu.assertEvalToTrue(calls[1].args[1] == 212, "host call should carry the eui node id")
  lu.assertEvalToTrue(calls[1].args[2] == false, "disabled=true should disable touch")
  lu.assertEvalToTrue(#self.role_b.calls == 0, "other roles should not receive the disabled update")
  lu.assertEvalToTrue(node.disabled == true, "disabled getter should report the stored value")
end

function TestENodeVisibleDisabledPropagation:test_disabled_broadcasts_to_all_roles_when_no_client_role()
  support.install_roles({ self.role_a, self.role_b })
  local node = ENode:new(213, "disabled_all_node")

  node.disabled = false

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_node_touch_enabled")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == true, "disabled=false should enable touch for every role")
  end
end

function TestENodeVisibleDisabledPropagation:test_for_all_roles_applies_a_setter_to_every_role_and_restores_client_role()
  context.client_role = self.role_a
  support.install_roles({ self.role_a, self.role_b })
  local node = ENode:new(214, "for_all_node")

  node:for_all_roles("visible", true)

  for _, role in ipairs({ self.role_a, self.role_b }) do
    local calls = support.calls_of(role, "set_node_visible")
    lu.assertEvalToTrue(#calls == 1 and calls[1].args[2] == true, "for_all_roles should broadcast to every role")
  end
  lu.assertEvalToTrue(context.client_role == self.role_a, "for_all_roles should restore the previous client_role")
end

function TestENodeVisibleDisabledPropagation:test_for_all_roles_ignores_unknown_keys()
  support.install_roles({ self.role_a })
  local node = ENode:new(215, "unknown_key_node")

  node:for_all_roles("no_such_property", true)

  lu.assertEvalToTrue(#self.role_a.calls == 0, "unknown property should not reach the host")
end

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

TestENodeNameQueries = {}

function TestENodeNameQueries:setUp()
  TestENode.setUp(self)
  _G.GameAPI = _G.GameAPI or {}
  self.original_get_children = _G.GameAPI.get_eui_children
  self.original_get_child_by_name = _G.GameAPI.get_eui_child_by_name
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
end

function TestENodeNameQueries:tearDown()
  _G.GameAPI.get_eui_children = self.original_get_children
  _G.GameAPI.get_eui_child_by_name = self.original_get_child_by_name
  TestENode.tearDown(self)
end

function TestENodeNameQueries:test_init_children_links_parents_and_children()
  local root = _build_tree()

  lu.assertEvalToTrue(root.children.length == 2, "root should own two children")
  lu.assertEvalToTrue(root.children[1].name == "child_a", "children should keep host order")
  lu.assertEvalToTrue(root.children[1].parent == root, "child parent should point back at root")
end

function TestENodeNameQueries:test_get_first_node_by_name_returns_nil_when_no_direct_child_matches()
  local root = _build_tree()

  lu.assertEvalToTrue(root:get_first_node_by_name("deep") == nil,
    "a grandchild should not be found by the shallow lookup")
  lu.assertEvalToTrue(root:get_first_node_by_name("child_b").id == 3,
    "a direct child should be found by the shallow lookup")
end

function TestENodeNameQueries:test_query_nodes_by_name_collects_every_direct_child_with_the_name()
  local root = _build_tree()
  local branch = context.nodes_list[3]

  lu.assertEvalToTrue(#root:query_nodes_by_name("child_a") == 1, "root has one direct child_a")
  lu.assertEvalToTrue(#root:query_nodes_by_name("deep") == 0, "root has no direct child named deep")
  lu.assertEvalToTrue(#branch:query_nodes_by_name("child_a") == 1, "branch has one direct child_a")
end

function TestENodeNameQueries:test_get_first_node_by_name_dfs_finds_a_direct_child_without_recursing()
  local root = _build_tree()

  local node = root:get_first_node_by_name_dfs("child_b")

  lu.assertEvalToTrue(node ~= nil and node.id == 3, "direct child should be returned immediately")
end

function TestENodeNameQueries:test_get_first_node_by_name_dfs_descends_into_children()
  local root = _build_tree()

  local node = root:get_first_node_by_name_dfs("deep")

  lu.assertEvalToTrue(node ~= nil and node.id == 4, "grandchild should be found via depth-first descent")
end

function TestENodeNameQueries:test_get_first_node_by_name_dfs_returns_nil_when_the_name_is_absent()
  local root = _build_tree()

  lu.assertEvalToTrue(root:get_first_node_by_name_dfs("missing") == nil,
    "absent names should yield nil after the whole subtree is scanned")
end

function TestENodeNameQueries:test_query_nodes_by_name_dfs_stops_at_the_first_matching_node()
  local root = _build_tree()

  local list = root:query_nodes_by_name_dfs("child_a")

  lu.assertEvalToTrue(#list == 1, "dfs query should stop at the first match")
  lu.assertEvalToTrue(list[1].id == 2, "the shallowest match should win")
end

-- 命中在孙层、另一条兄弟分支也藏着同名节点:上报链一旦断掉(命中不再返回 true,
-- 或中间层不把子树的命中往上传),扫描会继续吃掉第二条分支,收到两个节点。
function TestENodeNameQueries:test_query_nodes_by_name_dfs_stops_scanning_siblings_once_a_deep_match_is_found()
  _build_tree()
  local twin_root = context.nodes_list[11]

  local list = twin_root:query_nodes_by_name_dfs("twin")

  lu.assertEvalToTrue(#list == 1, "a match found deep in the first branch must stop the sibling scan")
  lu.assertEvalToTrue(list[1].id == 16, "the first branch's grandchild should be the only result")
end

function TestENodeNameQueries:test_query_nodes_by_name_dfs_descends_when_no_direct_child_matches()
  local root = _build_tree()

  local list = root:query_nodes_by_name_dfs("deep")

  lu.assertEvalToTrue(#list == 1 and list[1].id == 4, "dfs query should find the grandchild")
end

function TestENodeNameQueries:test_query_nodes_by_name_dfs_returns_an_empty_list_when_the_name_is_absent()
  local root = _build_tree()

  lu.assertEvalToTrue(#root:query_nodes_by_name_dfs("missing") == 0,
    "absent names should yield an empty list")
end

-- -------------------------------------------------- listen

local registered

local function _stub_register(ok, trigger)
  _G.GameAPI = _G.GameAPI or {}
  host_events.register_custom_event = function(event, handler)
    registered[#registered + 1] = { event = event, handler = handler }
    return ok, trigger
  end
end

TestENodeListen = {}

function TestENodeListen:setUp()
  TestENode.setUp(self)
  registered = {}
  self.original_register = host_events.register_custom_event
end

function TestENodeListen:tearDown()
  host_events.register_custom_event = self.original_register
  TestENode.tearDown(self)
end

function TestENodeListen:test_registers_the_host_event_once_and_stores_the_trigger()
  _stub_register(true, 999)
  local node_a = ENode:new(230, "listen_a")
  local node_b = ENode:new(231, "listen_b")

  local listener = node_a:listen("click", function() end)
  node_b:listen("click", function() end)

  lu.assertEvalToTrue(#registered == 1, "the host event should only be registered for the first listener")
  lu.assertEvalToTrue(registered[1].event == "click", "the host registration should carry the event name")
  lu.assertEvalToTrue(context.event_handlers["click"].trigger == 999,
    "the trigger handle returned by the host should be stored")
  lu.assertEvalToTrue(listener._event == "click", "the listener should remember its event")
  lu.assertEvalToTrue(listener._node_id == 230, "the listener should remember its node id")
end

function TestENodeListen:test_stores_no_trigger_when_the_host_refuses_to_register()
  _stub_register(false, 999)
  local node = ENode:new(232, "listen_failed")

  node:listen("click", function() end)

  lu.assertEvalToTrue(context.event_handlers["click"].trigger == nil,
    "a failed registration should not store a trigger handle")
end

function TestENodeListen:test_appends_further_callbacks_on_the_same_node()
  _stub_register(true, 999)
  local node = ENode:new(233, "listen_multi")
  local cb1 = function() end
  local cb2 = function() end

  local first = node:listen("click", cb1)
  local second = node:listen("click", cb2)

  local handler_data = context.event_handlers["click"][233]
  lu.assertEvalToTrue(#handler_data.callbacks == 2, "both callbacks should be registered on the node")
  lu.assertEvalToTrue(handler_data.callbacks[1] == cb1 and handler_data.callbacks[2] == cb2,
    "callbacks should keep registration order")
  lu.assertEvalToTrue(first ~= second, "each listen call should return its own listener")
  lu.assertEvalToTrue(second._callback == cb2, "the listener should remember its own callback")
end

function TestENodeListen:test_dispatches_host_events_to_the_node_callbacks_with_the_acting_role()
  _stub_register(true, 999)
  local node = ENode:new(234, "listen_dispatch")
  local role = { get_roleid = function() return 7 end }
  local seen = {}

  local listener = node:listen("click", function(data)
    seen[#seen + 1] = data
    seen.role_during_callback = context.client_role
  end)

  registered[1].handler(nil, nil, { eui_node_id = 234, role = role })

  lu.assertEvalToTrue(#seen == 1, "the callback should fire once")
  lu.assertEvalToTrue(seen[1].role == role, "the callback should receive the acting role")
  lu.assertEvalToTrue(seen[1].target == node, "the callback should receive the node as target")
  lu.assertEvalToTrue(seen[1].listener == listener, "the callback should receive the listener")
  lu.assertEvalToTrue(seen.role_during_callback == role, "client_role should be bound during dispatch")
  lu.assertEvalToTrue(context.client_role == nil, "client_role should be cleared after dispatch")
end

function TestENodeListen:test_ignores_host_events_for_nodes_without_handlers()
  _stub_register(true, 999)
  local node = ENode:new(235, "listen_other")
  local fired = 0
  node:listen("click", function() fired = fired + 1 end)

  registered[1].handler(nil, nil, { eui_node_id = 999, role = {} })

  lu.assertEvalToTrue(fired == 0, "a host event for an unregistered node should not fire callbacks")
  lu.assertEvalToTrue(context.client_role == nil, "client_role should stay unset for unhandled events")
end

function TestENodeListen:test_skips_dispatch_when_the_node_is_flagged_disabled()
  _stub_register(true, 999)
  local node = ENode:new(236, "listen_disabled")
  local fired = 0
  node:listen("click", function() fired = fired + 1 end)
  node._disabled = true

  registered[1].handler(nil, nil, { eui_node_id = 236, role = {} })

  lu.assertEvalToTrue(fired == 0, "a disabled node should not receive event callbacks")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestENode,
  TestENodeVisibleDisabledPropagation,
  TestENodeNameQueries,
  TestENodeListen
)
