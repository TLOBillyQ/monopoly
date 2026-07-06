local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local route_base = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")

describe("route_base intents", function()
  local function _state_with_choice(choice)
    return {
      ui_runtime = {
        ui_model = { choice = choice },
      },
    }
  end

  it("builds cancel intent for item target selection", function()
    local state = _state_with_choice({
      id = "target_choice_1",
      kind = "item_phase_passive",
      allow_cancel = true,
    })

    local specs = route_base.build(state)
    local cancel_spec = nil
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.cancel_button then
        cancel_spec = spec
        break
      end
    end

    assert(cancel_spec ~= nil, "cancel spec must exist")
    local intent = cancel_spec.build_intent()
    _assert_eq(intent.type, "choice_cancel", "cancel intent type")
    _assert_eq(intent.choice_id, "target_choice_1", "cancel intent targets current choice")
  end)

  it("omits cancel intent when no item target selection", function()
    local state = _state_with_choice({
      id = "optional_1",
      kind = "landing_optional_effect",
      allow_cancel = true,
    })

    local specs = route_base.build(state)
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.cancel_button then
        local intent = spec.build_intent()
        assert(intent == nil, "cancel intent should be nil for landing optional effect")
      end
    end
  end)

  it("keeps action intent for wait-action phase", function()
    local state = _state_with_choice(nil)

    local specs = route_base.build(state)
    local action_spec = nil
    for _, spec in ipairs(specs) do
      if spec.name == base_nodes.action_button then
        action_spec = spec
        break
      end
    end

    assert(action_spec ~= nil, "action spec must exist")
    local intent = action_spec.build_intent()
    _assert_eq(intent.type, "ui_button", "action intent type")
    _assert_eq(intent.id, "next", "action intent id")
  end)
end)
