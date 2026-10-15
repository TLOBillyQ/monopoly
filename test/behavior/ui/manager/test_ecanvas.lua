-- ecanvas.lua 直测:init 注册 nodes_list、只读属性存取、__init_children 经 GameAPI 替身组装子树。
local luassert = assert
local context = require("src.ui.manager.context")
local ECanvas = require("src.ui.manager.ecanvas")
require("test.support.ui_manager_nodes_support")

local function _clear_nodes()
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
end

describe("TestECanvas", function()
local original_get_eui_children

before_each(function()
  _clear_nodes()
  _G.GameAPI = _G.GameAPI or {}
  original_get_eui_children = _G.GameAPI.get_eui_children
end)

after_each(function()
  _clear_nodes()
  _G.GameAPI.get_eui_children = original_get_eui_children
end)

it("test_init_registers_itself_in_nodes_list_and_exposes_read_only_fields", function()
  local canvas = ECanvas:new(11, "root")

  luassert.truthy(context.nodes_list[11] == canvas, "canvas registered by id")
  luassert.truthy(canvas.id == 11, "id read back")
  luassert.truthy(canvas.name == "root", "name read back")
  luassert.truthy(canvas.parent == nil, "parent starts nil")
  luassert.truthy(canvas.children ~= nil and canvas.children.length == 0, "children starts empty")
end)

it("test_init_evicts_a_stale_registration_for_the_same_id", function()
  local stale = { __name = "UIManager.ECanvas" }
  context.nodes_list[11] = stale

  local canvas = ECanvas:new(11, "root")

  luassert.truthy(context.nodes_list[11] == canvas, "stale entry replaced")
  luassert.truthy(context.nodes_list[11] ~= stale, "old object evicted")
end)

it("test_init_children_pulls_child_ids_from_the_host_and_wires_parent_children", function()
  local parent = ECanvas:new(1, "parent")
  local child = ECanvas:new(2, "child")
  _G.GameAPI.get_eui_children = function(node_id)
    luassert.truthy(node_id == 1, "host queried with the parent canvas id")
    return { 2 }
  end

  parent:__init_children()

  luassert.truthy(parent.children.length == 1, "one child appended")
  luassert.truthy(parent.children[1] == child, "child resolved via nodes_list")
  luassert.truthy(child.parent == parent, "child parent wired back")
end)

it("test_read_only_fields_reject_assignment", function()
  local canvas = ECanvas:new(21, "panel")

  -- __set_* 只 warn 不抛错;断言写入不生效即可钉死只读语义。
  canvas.name = "hacked"
  canvas.id = 99
  canvas.parent = canvas
  canvas.children = nil

  luassert.truthy(canvas.name == "panel", "name unchanged")
  luassert.truthy(canvas.id == 21, "id unchanged")
  luassert.truthy(canvas.parent == nil, "parent unchanged")
  luassert.truthy(canvas.children ~= nil, "children unchanged")
end)


end)
