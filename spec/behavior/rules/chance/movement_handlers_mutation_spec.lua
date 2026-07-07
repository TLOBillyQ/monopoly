-- Mutation-pinning spec for src/rules/chance/movement_handlers.lua.
-- Kills the L20 survivor: `if res and res.move_result then` mutated to `or`.
-- When move_steps returns a truthy result WITHOUT a move_result field, the
-- original `and` short-circuits and leaves the result untouched; the `or` mutant
-- evaluates `res.move_result.allow_optional` and crashes on the nil index.
local movement_handlers = require("src.rules.chance.movement_handlers")

describe("chance movement_handlers mutation pins", function()
  it("move_backward tolerates a result with no move_result field (L20 'and')", function()
    local handlers = {}
    local common = {
      move_steps = function()
        return { marker = "no_move_result" } -- truthy res, but move_result is nil
      end,
    }
    movement_handlers.register(handlers, common)

    local ok, res = pcall(handlers.move_backward, {}, {}, { steps = 1 }, nil)
    assert(ok, "original 'and' must skip the block when move_result is nil; "
      .. "the 'or' mutant indexes nil and errors")
    assert(res ~= nil and res.marker == "no_move_result",
      "the untouched result must be returned verbatim")
  end)

  it("move_backward stamps allow_optional when a move_result is present (guard positive arm)", function()
    local handlers = {}
    local common = {
      move_steps = function()
        return { move_result = { visited = {} } }
      end,
    }
    movement_handlers.register(handlers, common)

    local res = handlers.move_backward({}, {}, { steps = 2 }, {})
    assert(res.move_result.allow_optional == true,
      "with move_result present, allow_optional must be set true")
  end)
end)
