-- Mutation-pinning spec for src/rules/chance/movement_handlers.lua.
-- Kills the L20 survivor: `if res and res.move_result then` mutated to `or`.
-- When move_steps returns a truthy result WITHOUT a move_result field, the
-- original `and` short-circuits and leaves the result untouched; the `or` mutant
-- evaluates `res.move_result.allow_optional` and crashes on the nil index.
local lu = require("luaunit")
local movement_handlers = require("src.rules.chance.movement_handlers")

TestMovementHandlersMutation = {}

function TestMovementHandlersMutation:test_move_backward_tolerates_a_result_with_no_move_result_field_l20_and()
  local handlers = {}
  local common = {
    move_steps = function()
      return { marker = "no_move_result" } -- truthy res, but move_result is nil
    end,
  }
  movement_handlers.register(handlers, common)

  local ok, res = pcall(handlers.move_backward, {}, {}, { steps = 1 }, nil)
  lu.assertEvalToTrue(ok, "original 'and' must skip the block when move_result is nil; "
    .. "the 'or' mutant indexes nil and errors")
  lu.assertEvalToTrue(res ~= nil and res.marker == "no_move_result",
    "the untouched result must be returned verbatim")
end

function TestMovementHandlersMutation:test_move_backward_stamps_allow_optional_when_a_move_result_is_present_guard_positive_arm()
  local handlers = {}
  local common = {
    move_steps = function()
      return { move_result = { visited = {} } }
    end,
  }
  movement_handlers.register(handlers, common)

  local res = handlers.move_backward({}, {}, { steps = 2 }, {})
  lu.assertEvalToTrue(res.move_result.allow_optional == true,
    "with move_result present, allow_optional must be set true")
end


return TestMovementHandlersMutation
