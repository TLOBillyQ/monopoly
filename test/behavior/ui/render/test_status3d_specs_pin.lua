-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
-- status3d/specs.lua 直测:状态 3D 规格表(场景键/剩余回合字段)与
-- get_layout_id 查询契约。宿主按 scene_eui_key 找布局,remaining_field
-- 决定读玩家哪个状态字段,配置面必须钉住。

local specs = require("src.ui.render.status3d.specs")
local status3d_nodes = require("src.ui.schema.status3d")
local Prefab = require("Data.Prefab")

describe("TestStatus3dSpecsPin", function()

  it("test_init_status_constant_is_pinned", function()
    luassert.truthy(specs.INIT_STATUS == "__init__", "the init marker must be pinned")
  end)

  -- 每类状态的场景键与剩余回合字段一一钉住。
  it("test_status_specs_pin_scene_keys_and_remaining_fields", function()
    local expected = {
      hospital = { key = "医院状态", field = "stay_turns", node = status3d_nodes.hospital.text_node_name },
      mountain = { key = "深山状态", field = "stay_turns", node = status3d_nodes.mountain.text_node_name },
      roadblock = { key = "路障状态", field = "stay_turns", node = status3d_nodes.roadblock.text_node_name },
      rich = { key = "财神状态", field = "deity_remaining", node = status3d_nodes.rich.text_node_name },
      poor = { key = "穷神状态", field = "deity_remaining", node = status3d_nodes.poor.text_node_name },
      angel = { key = "天使状态", field = "deity_remaining", node = status3d_nodes.angel.text_node_name },
    }
    for status_key, exp in pairs(expected) do
      local spec = specs.status_specs[status_key]
      luassert.truthy(spec ~= nil, "spec must exist for " .. status_key)
      luassert.truthy(spec.scene_eui_key == exp.key, "scene key must be pinned for " .. status_key)
      luassert.truthy(spec.remaining_field == exp.field, "remaining field must be pinned for " .. status_key)
      luassert.truthy(spec.text_node_name == exp.node, "text node must be pinned for " .. status_key)
    end
    luassert.truthy(next(specs.status_specs) ~= nil, "the spec table must not be empty")
  end)

  -- 叠加优先级顺序钉住。
  it("test_status_priority_order_is_pinned", function()
    luassert.truthy(table.concat(specs.status_priority, ",") ==
      "hospital,mountain,roadblock,poor,rich,angel", "the priority order must be pinned")
  end)

  -- get_layout_id:已知状态映射到 Prefab 场景键,未知状态返回 nil。
  it("test_get_layout_id_resolves_scene_eui", function()
    for status_key, spec in pairs(specs.status_specs) do
      local layout = specs.get_layout_id(status_key)
      luassert.truthy(layout == (Prefab.scene_eui and Prefab.scene_eui[spec.scene_eui_key]), "the layout id must resolve for " .. status_key)
    end
    luassert.truthy(specs.get_layout_id("unknown_status") == nil, "an unknown status must resolve to nil")
  end)

end)
