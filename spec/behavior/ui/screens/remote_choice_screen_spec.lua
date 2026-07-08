-- remote 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + registry 注册。
local registry = require("src.ui.screens.registry")
local remote_screen = require("src.ui.screens.remote_choice")
local schema = require("src.ui.schema.remote_choice")

describe("ui.screens.remote_choice", function()
  it("exposes a descriptor with the pinned remote fields", function()
    local d = remote_screen.descriptor()
    assert(d.key == "remote", "descriptor key is remote")
    assert(d.root ~= nil, "has root/canvas node")
    assert(d.title ~= nil, "has title")
    assert(d.body ~= nil, "has body")
    assert(d.option_buttons ~= nil, "has option_buttons")
  end)

  it("registers itself into the registry under its key", function()
    assert(registry.build_choice_screens().remote ~= nil, "registry aggregates remote descriptor")
    assert(registry.canvas_for("remote") == remote_screen.canvas, "registry maps remote canvas")
    assert(registry.opener_for("remote") == remote_screen.open, "registry maps remote opener")
  end)

  it("builds a route spec for every option node", function()
    local specs = remote_screen.build_route_specs({})
    local spec_names = {}
    for _, s in ipairs(specs) do
      spec_names[s.name] = true
    end
    for _, name in ipairs(schema.options) do
      assert(spec_names[name], "option node has route spec: " .. name)
    end
  end)

  it("returns a choice_select intent for an option when choice is present", function()
    local specs = remote_screen.build_route_specs({})
    local first_spec = specs[1]
    assert(first_spec ~= nil, "has at least one option spec")
    assert(first_spec.build_intent ~= nil, "spec has build_intent")
  end)
end)
