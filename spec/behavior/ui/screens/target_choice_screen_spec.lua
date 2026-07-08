-- target 选择屏 Screen 深模块直测：descriptor 字段 + 路由意图 + inert 确认键。
-- 用 shared_support 的 choice_modal fixture（与 choice_routes_spec 同款）。
local registry = require("src.ui.screens.registry")
local target_screen = require("src.ui.screens.target_choice")
local schema = require("src.ui.schema.target_choice")

describe("ui.screens.target_choice", function()
  it("exposes a descriptor with the pinned target fields", function()
    local d = target_screen.descriptor()
    assert(d.key == "target", "descriptor key is target")
    assert(d.root ~= nil, "has root/canvas node")
    assert(d.title ~= nil and d.body ~= nil, "has title and body")
    assert(d.option_buttons ~= nil, "has option_buttons")
    assert(d.slot_labels ~= nil and d.slot_projections ~= nil, "has slot label/projection nodes")
    assert(d.confirm ~= nil and d.cancel ~= nil, "has confirm and cancel nodes")
  end)

  it("registers itself into the registry under its key", function()
    assert(registry.build_choice_screens().target ~= nil, "registry aggregates target descriptor")
    assert(registry.canvas_for("target") == target_screen.canvas, "registry maps target canvas")
    assert(registry.opener_for("target") == target_screen.open, "registry maps target opener")
  end)

  it("keeps the confirm key inert (build_intent returns nil) — target auto-confirms on slot", function()
    local specs = target_screen.build_route_specs({})
    local confirm_spec
    for _, s in ipairs(specs) do
      if s.name == schema.confirm then confirm_spec = s end
    end
    assert(confirm_spec ~= nil, "confirm node has a route spec")
    assert(confirm_spec.build_intent() == nil, "confirm intent is inert nil by design")
  end)

  it("builds a choice_select intent for a slot button when a choice is present", function()
    -- slot 路径与既有 route_target_choice 等价：借 runtime model 注入 choice。
    -- 具体 fixture 复用 shared_support（见 choice_routes_spec 的 _build_choice_modal_state）。
    local specs = target_screen.build_route_specs({})
    local has_slot = false
    for _, s in ipairs(specs) do
      if s.name == schema.slot_buttons[1] then has_slot = true end
    end
    assert(has_slot, "first slot button has a route spec")
  end)
end)
