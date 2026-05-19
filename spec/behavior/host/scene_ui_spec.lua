local scene_ui = require("src.host.scene_ui")

describe("scene_ui (no GameAPI)", function()
  it("set_scene_ui_visible returns false without GameAPI", function()
    local result = scene_ui.set_scene_ui_visible(1, "role", true)
    assert(result == false, "expected false without GameAPI")
  end)

  it("destroy_scene_ui returns false without GameAPI", function()
    local result = scene_ui.destroy_scene_ui(1)
    assert(result == false, "expected false without GameAPI")
  end)

  it("has_scene_ui_support returns false without GameAPI", function()
    local result = scene_ui.has_scene_ui_support()
    assert(result == false, "expected false without GameAPI")
  end)

  it("get_eui_node_at_scene_ui returns nil without GameAPI", function()
    local result = scene_ui.get_eui_node_at_scene_ui(1, "node")
    assert(result == nil, "expected nil without GameAPI")
  end)
end)
