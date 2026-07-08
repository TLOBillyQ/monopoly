-- secondary_confirm 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + registry 注册。
local registry = require("src.ui.screens.registry")
local secondary_screen = require("src.ui.screens.secondary_confirm")
local schema = require("src.ui.schema.secondary_confirm")

describe("ui.screens.secondary_confirm", function()
  it("exposes a descriptor with the pinned secondary_confirm fields", function()
    local d = secondary_screen.descriptor()
    assert(d.key == "secondary_confirm", "descriptor key is secondary_confirm")
    assert(d.root ~= nil, "has root/canvas node")
    assert(d.title ~= nil, "has title")
    assert(d.body ~= nil, "has body")
    assert(d.confirm ~= nil, "has confirm node")
    assert(d.cancel ~= nil, "has cancel node")
  end)

  it("registers itself into the registry under its key", function()
    assert(registry.build_choice_screens().secondary_confirm ~= nil, "registry aggregates secondary_confirm descriptor")
    assert(registry.canvas_for("secondary_confirm") == secondary_screen.canvas, "registry maps secondary_confirm canvas")
    assert(registry.opener_for("secondary_confirm") == secondary_screen.open, "registry maps secondary_confirm opener")
  end)

  it("builds a confirm route spec that uses choice_confirm_intent", function()
    local specs = secondary_screen.build_route_specs({})
    local confirm_spec
    for _, s in ipairs(specs) do
      if s.name == schema.confirm then confirm_spec = s end
    end
    assert(confirm_spec ~= nil, "confirm node has a route spec")
    assert(confirm_spec.build_intent ~= nil, "confirm spec has build_intent")
  end)

  it("builds a cancel route spec that uses choice_cancel_intent", function()
    local specs = secondary_screen.build_route_specs({})
    local cancel_spec
    for _, s in ipairs(specs) do
      if s.name == schema.cancel then cancel_spec = s end
    end
    assert(cancel_spec ~= nil, "cancel node has a route spec")
    assert(cancel_spec.build_intent ~= nil, "cancel spec has build_intent")
  end)
end)
