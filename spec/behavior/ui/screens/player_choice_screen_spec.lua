-- player 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + registry 注册。
local registry = require("src.ui.screens.registry")
local player_screen = require("src.ui.screens.player_choice")
local schema = require("src.ui.schema.player_choice")

describe("ui.screens.player_choice", function()
  it("exposes a descriptor with the pinned player fields", function()
    local d = player_screen.descriptor()
    assert(d.key == "player", "descriptor key is player")
    assert(d.root ~= nil, "has root/canvas node")
    assert(d.title ~= nil, "has title")
    assert(d.option_buttons ~= nil, "has option_buttons")
  end)

  it("registers itself into the registry under its key", function()
    assert(registry.build_choice_screens().player ~= nil, "registry aggregates player descriptor")
    assert(registry.canvas_for("player") == player_screen.canvas, "registry maps player canvas")
    assert(registry.opener_for("player") == player_screen.open, "registry maps player opener")
  end)

  it("builds a route spec for every slot node", function()
    local specs = player_screen.build_route_specs({})
    local spec_names = {}
    for _, s in ipairs(specs) do
      spec_names[s.name] = true
    end
    for _, name in ipairs(schema.slots) do
      assert(spec_names[name], "slot node has route spec: " .. name)
    end
  end)
end)
