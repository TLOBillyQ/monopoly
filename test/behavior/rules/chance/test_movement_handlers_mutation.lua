-- Mutation-pinning spec for src/rules/chance/movement_handlers.lua.
-- Kills the L20 survivor: `if res and res.move_result then` mutated to `or`.
-- When move_steps returns a truthy result WITHOUT a move_result field, the
-- original `and` short-circuits and leaves the result untouched; the `or` mutant
-- evaluates `res.move_result.allow_optional` and crashes on the nil index.
require("test.bootstrap").install_package_paths()
local luassert = assert
local movement_handlers = require("src.rules.chance.movement_handlers")

describe("TestMovementHandlersMutation", function()
it("test_move_backward_tolerates_a_result_with_no_move_result_field_l20_and", function()
  local handlers = {}
  local common = {
    move_steps = function()
      return { marker = "no_move_result" } -- truthy res, but move_result is nil
    end,
  }
  movement_handlers.register(handlers, common)

  local ok, res = pcall(handlers.move_backward, {}, {}, { steps = 1 }, nil)
  luassert.truthy(ok, "original 'and' must skip the block when move_result is nil; "
    .. "the 'or' mutant indexes nil and errors")
  luassert.truthy(res ~= nil and res.marker == "no_move_result",
    "the untouched result must be returned verbatim")
end)

it("test_move_backward_stamps_allow_optional_when_a_move_result_is_present_guard_positive_arm", function()
  local handlers = {}
  local common = {
    move_steps = function()
      return { move_result = { visited = {} } }
    end,
  }
  movement_handlers.register(handlers, common)

  local res = handlers.move_backward({}, {}, { steps = 2 }, {})
  luassert.truthy(res.move_result.allow_optional == true,
    "with move_result present, allow_optional must be set true")
end)


end)
