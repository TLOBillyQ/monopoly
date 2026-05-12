local M = {}

function M.unpack_next(args)
  args = args or {}
  return args.next_state, args.next_args
end

function M.mark_dirty(game)
  if game and game.dirty then
    game.dirty.turn = true
    game.dirty.any = true
  end
end

return M
