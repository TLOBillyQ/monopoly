require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- Mutation-pinning specs for src/foundation/chain_args.lua.
-- State shapes kept inline; the discrimination is "table left untouched" vs
-- "defaults injected", which flips when L4's `or` becomes `and`.

local chain_args = require("src.foundation.chain_args")

describe("TestChainArgsMutation", function()

  it("test_L4 guard short-circuits on next_state mismatch (kills 'or'->'and')", function()
    -- next_state ("stateA") ~= match_state ("matchB") is TRUE, and next_args IS a
    -- table with no next_state/next_args keys.
    -- Original guard `A or B`: A true -> return early -> next_args untouched.
    -- Mutant `A and B`: A(true) and B(type(table)~="table" == false) -> false ->
    --   falls through and injects default_next_state / default_next_args.
    local next_args = {}
    local state, args = chain_args.patch(
      "stateA", next_args, "matchB", "default_state", "default_args")
    luassert.is.equal("stateA", state, "next_state must pass through unchanged; got " .. tostring(state))
    luassert.is.equal(next_args, args, "next_args table identity must pass through")
    luassert.is_nil(args.next_state, "on state mismatch the table must NOT be mutated with defaults; got next_state="
        .. tostring(args.next_state))
    luassert.is_nil(args.next_args, "on state mismatch the table must NOT be mutated with defaults; got next_args="
        .. tostring(args.next_args))
  end)


end)
