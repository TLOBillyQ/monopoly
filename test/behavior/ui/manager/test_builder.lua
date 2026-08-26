-- builder.lua branch-dense coverage: empty config error and fallback branch.
local lu = require("luaunit")
local context = require("src.ui.manager.context")
local Builder = require("src.ui.manager.builder")
-- 底座加载时自备共享运行时端口基线(#217 窄 suite 子集无全量车道加载序兜底)。
require("test.support.ui_manager_nodes_support")

TestBuilder = {}

do
  local original_get_eui_children

  local function _clear_context()
    for k in pairs(context.nodes_list) do
      context.nodes_list[k] = nil
    end
    for k in pairs(context.name_node_mapping) do
      context.name_node_mapping[k] = nil
    end
    context.config_list = nil
  end

  function TestBuilder:setUp()
    _clear_context()
    _G.GameAPI = _G.GameAPI or {}
    original_get_eui_children = _G.GameAPI.get_eui_children
    _G.GameAPI.get_eui_children = function() return {} end
  end

  function TestBuilder:tearDown()
    _G.GameAPI.get_eui_children = original_get_eui_children
  end

  function TestBuilder:test_errors_on_empty_config()
    local ok, err = pcall(function()
      Builder:new({})
    end)

    lu.assertEvalToTrue(ok == false, "empty config should raise an error")
    lu.assertEvalToTrue(tostring(err):find("Empty config!") ~= nil,
      "error message should mention empty config")
  end

  function TestBuilder:test_falls_back_to_enode_for_unknown_build_type()
    local config = {
      [1] = { "node_one", "UnknownType" },
      [2] = { "node_two", "EButton" },
    }

    Builder:new(config)

    local node1 = context.nodes_list[1]
    local node2 = context.nodes_list[2]
    lu.assertEvalToTrue(node1 ~= nil, "unknown type node should be created")
    lu.assertEvalToTrue(node1.__name == "UIManager.ENode", "unknown type should fall back to ENode")
    lu.assertEvalToTrue(node2 ~= nil, "known type node should be created")
    lu.assertEvalToTrue(node2.__name == "UIManager.EButton", "known type should use registered class")
  end

  function TestBuilder:test_skips_duplicate_node_ids()
    local config = {
      [1] = { "node_one", "ENode" },
    }

    Builder:new(config)
    local first = context.nodes_list[1]
    Builder:new(config)
    local second = context.nodes_list[1]

    lu.assertEvalToTrue(first == second, "duplicate ids should reuse existing nodes")
  end

  function TestBuilder:test_build_node_dispatches_every_registered_node_type_to_its_class()
    local cases = {
      { id = 501, type = "ECanvas", name = "UIManager.ECanvas" },
      { id = 502, type = "ENode", name = "UIManager.ENode" },
      { id = 503, type = "ELabel", name = "UIManager.ELabel" },
      { id = 504, type = "EButton", name = "UIManager.EButton" },
      { id = 505, type = "EImage", name = "UIManager.EImage" },
      { id = 506, type = "EProgressbar", name = "UIManager.EProgressbar" },
      { id = 507, type = "EInputField", name = "UIManager.EInputField" },
    }
    local config_list = {}
    for _, case in ipairs(cases) do
      config_list[case.id] = { "node_" .. case.type, case.type }
    end

    Builder:new(config_list)

    for _, case in ipairs(cases) do
      local node = context.nodes_list[case.id]
      lu.assertEvalToTrue(node ~= nil, case.type .. " should be built")
      lu.assertEvalToTrue(node.__name == case.name,
        ("%s should dispatch to %s, got %s"):format(case.type, case.name, tostring(node.__name)))
      local mapped = context.name_node_mapping["node_" .. case.type]
      lu.assertEvalToTrue(mapped ~= nil and mapped[1] == node, case.type .. " should land in name_node_mapping")
    end
  end
end


return TestBuilder
