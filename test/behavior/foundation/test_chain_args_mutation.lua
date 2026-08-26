-- Mutation-pinning specs for src/foundation/chain_args.lua.
-- State shapes kept inline; the discrimination is "table left untouched" vs
-- "defaults injected", which flips when L4's `or` becomes `and`.

local lu = require("luaunit")
local chain_args = require("src.foundation.chain_args")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 Test* 类,断言切到 lu.assertXxx
-- (实参序对调 + == 转 assertIs / ==nil 转 assertNil),用例数与改写前一一对应
-- (1 例)。it 名含引号/箭头等非标识符字符,方法名用字符串键逐字保留。
TestChainArgsMutation = {}

TestChainArgsMutation["test_L4 guard short-circuits on next_state mismatch (kills 'or'->'and')"] = function(self)
  -- next_state ("stateA") ~= match_state ("matchB") is TRUE, and next_args IS a
  -- table with no next_state/next_args keys.
  -- Original guard `A or B`: A true -> return early -> next_args untouched.
  -- Mutant `A and B`: A(true) and B(type(table)~="table" == false) -> false ->
  --   falls through and injects default_next_state / default_next_args.
  local next_args = {}
  local state, args = chain_args.patch(
    "stateA", next_args, "matchB", "default_state", "default_args")
  lu.assertIs(state, "stateA", "next_state must pass through unchanged; got " .. tostring(state))
  lu.assertIs(args, next_args, "next_args table identity must pass through")
  lu.assertNil(args.next_state,
    "on state mismatch the table must NOT be mutated with defaults; got next_state="
      .. tostring(args.next_state))
  lu.assertNil(args.next_args,
    "on state mismatch the table must NOT be mutated with defaults; got next_args="
      .. tostring(args.next_args))
end


return TestChainArgsMutation
