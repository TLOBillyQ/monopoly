local luassert = assert
local P = require("test.support.shared_support")
local _with_patches = P.with_patches

local runtime_ports = require("src.foundation.ports.runtime_ports")
local node_ops = require("src.ui.render.support.node_ops")

local function _make_role_fixture(active_role, roles)
  local nodes_by_role = {}
  for _, role in ipairs(roles) do
    nodes_by_role[role] = { text = "before", image_texture = "before" }
  end
  local global_node = { text = "before", image_texture = "before" }
  local manager = { client_role = active_role }
  manager.query_nodes_by_name = function(name)
    local node = global_node
    if manager.client_role ~= nil then
      node = nodes_by_role[manager.client_role]
    end
    assert(node ~= nil, "missing host node for " .. tostring(name))
    return { node }
  end
  return manager, nodes_by_role, global_node
end

local function _with_role_host(manager, roles, fn)
  _with_patches({
    { key = "UIManager", value = manager },
    { target = runtime_ports, key = "resolve_roles", value = function() return roles end },
  }, fn)
end

describe("TestNodeOpsActiveRole", function()

it("test_active_role_set_text_updates_only_that_roles_visible_node", function()
  local active_role = {}
  local other_role = {}
  local roles = { active_role, other_role }
  local manager, nodes, global_node = _make_role_fixture(active_role, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_text(nil, "node-name", "after-immediate")
  end)

  luassert.truthy(nodes[active_role].text == "after-immediate", "immediate branch must update the active role node")
  luassert.truthy(nodes[other_role].text == "before", "immediate branch must not fan out to another role")
  luassert.truthy(global_node.text == "before", "immediate branch must not update the global node")
  luassert.truthy(manager.client_role == active_role, "immediate branch must preserve the active host role")
end)

it("test_nil_active_role_set_text_updates_every_role_visible_node", function()
  local role_a = {}
  local role_b = {}
  local roles = { role_a, role_b }
  local manager, nodes, global_node = _make_role_fixture(nil, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_text(nil, "node-name-deferred", "after-deferred")
  end)

  luassert.truthy(nodes[role_a].text == "after-deferred", "deferred branch must update role A's visible text")
  luassert.truthy(nodes[role_b].text == "after-deferred", "deferred branch must update role B's visible text")
  luassert.truthy(global_node.text == "before", "a non-empty role roster must not also update the global node")
  luassert.truthy(manager.client_role == nil, "deferred branch must restore the empty active role")
end)

it("test_nil_active_role_set_text_uses_global_node_when_roster_is_empty", function()
  local roles = {}
  local manager, _, global_node = _make_role_fixture(nil, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_text(nil, "node-global", "after-global")
  end)

  luassert.truthy(global_node.text == "after-global", "empty role roster must fall back to the global visible node")
  luassert.truthy(manager.client_role == nil, "global fallback must leave the active role empty")
end)

it("test_active_role_item_slot_updates_only_that_roles_texture", function()
  local active_role = {}
  local other_role = {}
  local roles = { active_role, other_role }
  local manager, nodes, global_node = _make_role_fixture(active_role, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_item_slot_image("slot_X", "IMG_X")
  end)

  luassert.truthy(nodes[active_role].image_texture == "IMG_X", "immediate branch must update the active role texture")
  luassert.truthy(nodes[other_role].image_texture == "before", "immediate item update must not fan out to another role")
  luassert.truthy(global_node.image_texture == "before", "immediate item update must not touch the global texture")
  luassert.truthy(manager.client_role == active_role, "immediate item update must preserve the active host role")
end)

it("test_nil_active_role_item_slot_updates_every_role_texture", function()
  local role_a = {}
  local role_b = {}
  local roles = { role_a, role_b }
  local manager, nodes, global_node = _make_role_fixture(nil, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_item_slot_image("slot_Y", "IMG_Y")
  end)

  luassert.truthy(nodes[role_a].image_texture == "IMG_Y", "deferred item update must set role A's texture")
  luassert.truthy(nodes[role_b].image_texture == "IMG_Y", "deferred item update must set role B's texture")
  luassert.truthy(global_node.image_texture == "before", "a non-empty role roster must not also update the global texture")
  luassert.truthy(manager.client_role == nil, "deferred item update must restore the empty active role")
end)

it("test_nil_active_role_item_slot_uses_global_texture_when_roster_is_empty", function()
  local roles = {}
  local manager, _, global_node = _make_role_fixture(nil, roles)

  _with_role_host(manager, roles, function()
    node_ops.set_item_slot_image("slot_Z", "IMG_Z")
  end)

  luassert.truthy(global_node.image_texture == "IMG_Z", "empty role roster must update the global texture")
  luassert.truthy(manager.client_role == nil, "global item fallback must leave the active role empty")
end)

end)
