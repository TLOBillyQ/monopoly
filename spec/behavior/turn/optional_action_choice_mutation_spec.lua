-- Mutation-pinning specs for src/turn/optional_action_choice.lua.
-- The predicate is pure, so choices are built inline (no runtime setup) and the
-- nil-vs-explicit-field discrimination is the contract under test.

local optional_action_choice = require("src.turn.optional_action_choice")

describe("optional_action_choice.is_pre_action_item_phase_choice passive_origin exclusion", function()
  local function _pre_action_choice(overrides)
    local choice = {
      kind = "item_phase_passive",
      allow_cancel = true,
      meta = { phase = "pre_action" },
    }
    for key, value in pairs(overrides or {}) do
      choice[key] = value
    end
    return choice
  end

  it("excludes a pre_action passive whose meta.passive_origin is true (L25 'passive_origin ~= true')", function()
    -- Item target selection (passive_origin) keeps its own 取消 affordance, so it
    -- must NOT be routed to the 行动 button. Mutant '~= true' -> '~= false' would
    -- accept passive_origin == true and wrongly report it as a pre_action choice.
    local choice = _pre_action_choice({ meta = { phase = "pre_action", passive_origin = true } })
    assert(optional_action_choice.is_pre_action_item_phase_choice(choice) == false,
      "passive_origin==true must be excluded from pre_action item-phase routing")
  end)

  it("includes a pre_action passive without passive_origin (positive control)", function()
    assert(optional_action_choice.is_pre_action_item_phase_choice(_pre_action_choice()) == true,
      "a cancelable pre_action item_phase_passive without passive_origin must qualify")
  end)
end)
