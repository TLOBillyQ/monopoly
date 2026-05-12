local dirty_tracker = require("src.state.dirty_tracker")

local M = {}

function M.unpack_next(args)
  args = args or {}
  return args.next_state, args.next_args
end

function M.mark_dirty(game)
  if game and game.dirty then
    dirty_tracker.mark(game.dirty, "turn")
  end
end

return M
