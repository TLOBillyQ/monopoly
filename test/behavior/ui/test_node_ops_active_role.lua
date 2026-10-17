local luassert = assert
local P = require("test.support.shared_support")
local _with_patches = P.with_patches

local runtime = require("src.ui.render.support.runtime_ui")
local node_ops = require("src.ui.render.support.node_ops")

describe("TestNodeOpsActiveRole", function()

it("test_active_role_truthy_skips_for_each_role_or_global_immediate_branch_only", function()
  local node = { text = "before" }
  local for_each_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = function() return "role-immediate" end },
    { target = runtime, key = "for_each_role_or_global", value = function(_)
      for_each_calls = for_each_calls + 1
    end },
  }, function()
    node_ops.set_text(nil, "node-name", "after-immediate")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 0,
    "L23 active_role truthy must NOT call for_each_role_or_global; got " .. tostring(for_each_calls))
  luassert.truthy(node.text == "after-immediate",
    "immediate branch must apply mutator to queried node; got " .. tostring(node.text))
end)

it("test_active_role_nil_get_client_role_returns_nil_runs_deferred_branch_only", function()
  local node = { text = "before" }
  local for_each_calls = 0
  local query_node_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function()
      query_node_calls = query_node_calls + 1
      return { node }
    end },
    { target = runtime, key = "get_client_role", value = function() return nil end },
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      for_each_calls = for_each_calls + 1
      fn()  -- invoke callback so deferred mutator runs against stubbed query_nodes
    end },
  }, function()
    node_ops.set_text(nil, "node-name-deferred", "after-deferred")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 1,
    "L23 active_role nil must call for_each_role_or_global exactly once; got " .. tostring(for_each_calls))
  luassert.truthy(node.text == "after-deferred", "deferred branch must still apply mutator via callback")
  -- lint-allow: call-count runtime.query_nodes 封装 UIManager.query_nodes_by_name,延迟回调内恰向宿主查节点一次
  luassert.truthy(query_node_calls == 1, "exactly one query_nodes lookup inside deferred callback")
end)

it("test_get_client_role_missing_entirely_deferred_branch_skip_or_nil_fallback", function()
  local node = { text = "before" }
  local for_each_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { node } end },
    { target = runtime, key = "get_client_role", value = nil },
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      for_each_calls = for_each_calls + 1
      fn()
    end },
  }, function()
    node_ops.set_text(nil, "node-no-helper", "after-no-helper")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 1,
    "L23 with get_client_role==nil must short-circuit via `and` to nil → deferred; got " .. tostring(for_each_calls))
end)

it("test_active_role_truthy_skips_for_each_role_or_global_immediate_apply_item_slot", function()
  local texture_calls = {}
  local for_each_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { {} } end },
    { target = runtime, key = "get_client_role", value = function() return "role-immediate-slot" end },
    { target = runtime, key = "for_each_role_or_global", value = function(_)
      for_each_calls = for_each_calls + 1
    end },
    { target = runtime, key = "set_node_texture_keep_size", value = function(_, key)
      texture_calls[#texture_calls + 1] = key
    end },
  }, function()
    node_ops.set_item_slot_image("slot_X", "IMG_X")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 0,
    "L107 active_role truthy must NOT call for_each_role_or_global; got " .. tostring(for_each_calls))
  luassert.truthy(#texture_calls == 1 and texture_calls[1] == "IMG_X",
    "immediate branch must apply texture once via _apply_item_slot")
end)

it("test_active_role_nil_deferred_via_for_each_role_or_global_called_per_iteration", function()
  local texture_calls = {}
  local for_each_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { {} } end },
    { target = runtime, key = "get_client_role", value = function() return nil end },
    { target = runtime, key = "for_each_role_or_global", value = function(fn)
      for_each_calls = for_each_calls + 1
      fn()  -- one iteration only, distinct from immediate single-call shape
    end },
    { target = runtime, key = "set_node_texture_keep_size", value = function(_, key)
      texture_calls[#texture_calls + 1] = key
    end },
  }, function()
    node_ops.set_item_slot_image("slot_Y", "IMG_Y")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 1,
    "L107 active_role nil must call for_each_role_or_global once; got " .. tostring(for_each_calls))
  luassert.truthy(#texture_calls == 1 and texture_calls[1] == "IMG_Y",
    "deferred branch must apply texture via callback")
end)

it("test_get_client_role_missing_entirely_deferred_branch_via_short_circuit_and_to_nil", function()
  local for_each_calls = 0
  _with_patches({
    { target = runtime, key = "query_nodes", value = function() return { {} } end },
    { target = runtime, key = "get_client_role", value = nil },
    { target = runtime, key = "for_each_role_or_global", value = function(_)
      for_each_calls = for_each_calls + 1
    end },
    { target = runtime, key = "set_node_texture_keep_size", value = function() end },
  }, function()
    node_ops.set_item_slot_image("slot_Z", "IMG_Z")
  end)
  -- lint-allow: call-count 存量:桩在内部协作者上,只能经调用次数观察路由;迁到宿主边界观察待另开单
  luassert.truthy(for_each_calls == 1,
    "L107 with get_client_role==nil must short-circuit via `and` to nil → deferred; got " .. tostring(for_each_calls))
end)

end)
