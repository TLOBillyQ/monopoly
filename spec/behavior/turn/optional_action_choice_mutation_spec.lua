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

describe("optional_action_choice.is_item_usage_phase_choice guards", function()
  -- A genuine item-usage-phase choice: cancelable item_phase_passive with a named
  -- item, no passive_origin (not target selection) and no phase (not a skip gate).
  local function _usage_choice(meta_overrides)
    local meta = { item_name = "炸弹" }
    for key, value in pairs(meta_overrides or {}) do
      meta[key] = value
    end
    return { kind = "item_phase_passive", allow_cancel = true, meta = meta }
  end

  it("qualifies a named item usage on the base screen (positive control)", function()
    assert(optional_action_choice.is_item_usage_phase_choice(_usage_choice()) == true,
      "cancelable item_phase_passive with item_name and no origin/phase is item usage")
  end)

  it("rejects a non-cancelable choice (L43 'return false')", function()
    -- allow_cancel=false makes it non-cancelable; mutant 'return true' would accept it.
    local choice = { kind = "item_phase_passive", allow_cancel = false, meta = { item_name = "炸弹" } }
    assert(optional_action_choice.is_item_usage_phase_choice(choice) == false,
      "non-cancelable choice must not be an item usage phase")
  end)

  it("rejects a choice whose meta is not a table (L50 'return false')", function()
    local choice = { kind = "item_phase_passive", allow_cancel = true, meta = nil }
    assert(optional_action_choice.is_item_usage_phase_choice(choice) == false,
      "absent meta table must not be an item usage phase")
  end)

  it("rejects target selection (passive_origin) even with an item_name (L52 '== true')", function()
    -- passive_origin==true owns its own screen; mutant '== false' would let it through.
    assert(optional_action_choice.is_item_usage_phase_choice(_usage_choice({ passive_origin = true })) == false,
      "passive_origin target selection is not the base item usage phase")
  end)

  it("rejects a phase-gated choice even with an item_name (L52 'or' branch)", function()
    -- meta.phase ~= nil means a pre/post-action skip gate (行动/结束), not base cancel.
    -- Mutant 'or' -> 'and' would only exclude when BOTH origin and phase disqualify.
    assert(optional_action_choice.is_item_usage_phase_choice(_usage_choice({ phase = "post_action" })) == false,
      "a phase-gated choice is driven by 行动/结束, not the base cancel")
  end)
end)
