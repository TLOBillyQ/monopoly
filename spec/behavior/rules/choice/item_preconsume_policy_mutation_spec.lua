-- Mutation-pinning spec for src/rules/choice/item_preconsume_policy.lua.
-- Kills the normalize_cancel_action return-table survivors (L44/L45/L47):
--   * L44 type = "choice_select"           mutated to nil
--   * L45 choice_id = choice and choice.id or nil    `or` -> `and` (=> nil)
--   * L47 actor_role_id = action and action.actor_role_id or nil  `or` -> `and`
-- Reaching the return requires: cancel action + preconsumed choice + a first option.
local policy = require("src.rules.choice.item_preconsume_policy")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("item_preconsume_policy normalize_cancel_action mutation pins", function()
  it("rewrites a cancel into a choice_select carrying every field (L44/L45/L47)", function()
    local choice = {
      id = "C1",
      meta = { item_preconsumed = true },
      options = { { id = "OPT_A" }, { id = "OPT_B" } },
    }
    local action = { type = "choice_cancel", actor_role_id = 7 }

    local result = policy.normalize_cancel_action(choice, action)

    _assert_eq(result.type, "choice_select", "rewritten action type must be 'choice_select' (L44)")
    _assert_eq(result.choice_id, "C1", "choice_id must be forwarded from choice.id (L45 'or')")
    _assert_eq(result.option_id, "OPT_A", "option_id must be the first option id (L46)")
    _assert_eq(result.actor_role_id, 7, "actor_role_id must be forwarded from the action (L47 'or')")
  end)
end)
