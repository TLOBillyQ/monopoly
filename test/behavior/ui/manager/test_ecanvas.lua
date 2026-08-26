-- ecanvas.lua 直测:init 注册 nodes_list、只读属性存取、__init_children 经 GameAPI 替身组装子树。
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local ECanvas = require("src.ui.manager.ecanvas")
require("test.support.ui_manager_nodes_support")

-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,before_each/after_each 收成
-- setUp/tearDown(original_get_eui_children 收成 self 字段),用例数与改写前一致(4 例)。

local function _clear_nodes()
  for k in pairs(context.nodes_list) do
    context.nodes_list[k] = nil
  end
end

TestECanvas = {}

function TestECanvas:setUp()
  _clear_nodes()
  _G.GameAPI = _G.GameAPI or {}
  self.original_get_eui_children = _G.GameAPI.get_eui_children
end

function TestECanvas:tearDown()
  _clear_nodes()
  _G.GameAPI.get_eui_children = self.original_get_eui_children
end

function TestECanvas:test_init_registers_itself_in_nodes_list_and_exposes_read_only_fields()
  local canvas = ECanvas:new(11, "root")

  lu.assertEvalToTrue(context.nodes_list[11] == canvas, "canvas registered by id")
  lu.assertEvalToTrue(canvas.id == 11, "id read back")
  lu.assertEvalToTrue(canvas.name == "root", "name read back")
  lu.assertEvalToTrue(canvas.parent == nil, "parent starts nil")
  lu.assertEvalToTrue(canvas.children ~= nil and canvas.children.length == 0, "children starts empty")
end

function TestECanvas:test_init_evicts_a_stale_registration_for_the_same_id()
  local stale = { __name = "UIManager.ECanvas" }
  context.nodes_list[11] = stale

  local canvas = ECanvas:new(11, "root")

  lu.assertEvalToTrue(context.nodes_list[11] == canvas, "stale entry replaced")
  lu.assertEvalToTrue(context.nodes_list[11] ~= stale, "old object evicted")
end

function TestECanvas:test_init_children_pulls_child_ids_from_the_host_and_wires_parent_children()
  local parent = ECanvas:new(1, "parent")
  local child = ECanvas:new(2, "child")
  _G.GameAPI.get_eui_children = function(node_id)
    lu.assertEvalToTrue(node_id == 1, "host queried with the parent canvas id")
    return { 2 }
  end

  parent:__init_children()

  lu.assertEvalToTrue(parent.children.length == 1, "one child appended")
  lu.assertEvalToTrue(parent.children[1] == child, "child resolved via nodes_list")
  lu.assertEvalToTrue(child.parent == parent, "child parent wired back")
end

function TestECanvas:test_read_only_fields_reject_assignment()
  local canvas = ECanvas:new(21, "panel")

  -- __set_* 只 warn 不抛错;断言写入不生效即可钉死只读语义。
  canvas.name = "hacked"
  canvas.id = 99
  canvas.parent = canvas
  canvas.children = nil

  lu.assertEvalToTrue(canvas.name == "panel", "name unchanged")
  lu.assertEvalToTrue(canvas.id == 21, "id unchanged")
  lu.assertEvalToTrue(canvas.parent == nil, "parent unchanged")
  lu.assertEvalToTrue(canvas.children ~= nil, "children unchanged")
end


return TestECanvas
