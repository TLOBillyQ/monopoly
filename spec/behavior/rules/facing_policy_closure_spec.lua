-- Branch/boundary coverage for src/rules/board/facing_policy.lua.
-- movement_spec already covers sync_move_dir's forced_move/clear value cases
-- and the resume_forward error contract; this pins the gaps:
--   * should_skip_inner_entry (scope.4) had no direct coverage at all,
--   * resolve_initial_facing (scope.5) only had its error path tested
--     (roadblock_spec stubs the function rather than exercising it),
--   * sync_move_dir_after_position_change's preserve branch, the
--     _set_move_dir changed/unchanged return value, and the invalid-mode guard.
local facing_policy = require("src.rules.board.facing_policy")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- A minimal game whose set_player_status records writes onto player.status and
-- returns a sentinel so callers' return values can be observed.
local function _make_game(tiles)
  local calls = {}
  local game = {
    set_player_status = function(_, p, key, value)
      p.status = p.status or {}
      p.status[key] = value
      calls[#calls + 1] = { key = key, value = value }
      return { key = key, value = value }
    end,
    board = {
      get_tile = function(_, idx) return tiles and tiles[idx] or nil end,
    },
  }
  return game, calls
end

local function _player(move_dir)
  return { id = 1, status = { move_dir = move_dir } }
end

describe("facing_policy.sync_move_dir_after_position_change closure", function()
  it("preserve mode keeps the current heading and reports no change", function()
    local g = _make_game()
    local p = _player("left")
    local changed = facing_policy.sync_move_dir_after_position_change(g, p, 1, "preserve")
    _assert_eq(p.status.move_dir, "left", "preserve must not alter move_dir")
    _assert_eq(changed, false, "setting move_dir to its current value reports no change")
  end)

  it("defaults a nil mode to preserve", function()
    local g = _make_game()
    local p = _player("up")
    facing_policy.sync_move_dir_after_position_change(g, p, 1, nil)
    _assert_eq(p.status.move_dir, "up", "a nil mode behaves like preserve")
  end)

  it("forced_move onto market overrides heading and reports the change", function()
    local g = _make_game({ [9] = { type = "market" } })
    local p = _player("left")
    local changed = facing_policy.sync_move_dir_after_position_change(g, p, 9, "forced_move")
    _assert_eq(p.status.move_dir, "right", "market forces the default heading")
    _assert_eq(changed, true, "changing left -> right reports a change")
  end)

  it("forced_move onto market is a no-op when already facing the default", function()
    local g, calls = _make_game({ [9] = { type = "market" } })
    local p = _player("right")
    local changed = facing_policy.sync_move_dir_after_position_change(g, p, 9, "forced_move")
    _assert_eq(changed, false, "already facing right -> unchanged")
    _assert_eq(#calls, 0, "an unchanged heading must not write player status")
  end)

  it("forced_move onto an ordinary tile preserves the heading and reports no change", function()
    local g = _make_game({ [3] = { type = "land" } })
    local p = _player("down")
    local changed = facing_policy.sync_move_dir_after_position_change(g, p, 3, "forced_move")
    _assert_eq(p.status.move_dir, "down", "a tile with no override preserves the heading")
    _assert_eq(changed, false, "an unchanged heading on an ordinary tile reports the _set_move_dir result, not nil")
  end)

  it("forced_move onto a clearing tile drops the heading", function()
    local g = _make_game({ [4] = { type = "hospital" } })
    local p = _player("left")
    facing_policy.sync_move_dir_after_position_change(g, p, 4, "forced_move")
    _assert_eq(p.status.move_dir, nil, "hospital override clears the heading")
  end)

  it("forced_move onto the mountain drops the heading", function()
    local g = _make_game({ [6] = { type = "mountain" } })
    local p = _player("right")
    facing_policy.sync_move_dir_after_position_change(g, p, 6, "forced_move")
    _assert_eq(p.status.move_dir, nil, "mountain is a clearing tile type and drops the heading")
  end)

  it("clear mode drops the heading and resets skip_next_inner_entry", function()
    local g = _make_game()
    local p = _player("left")
    local ret = facing_policy.sync_move_dir_after_position_change(g, p, 1, "clear")
    _assert_eq(p.status.move_dir, nil, "clear drops move_dir")
    _assert_eq(p.status.skip_next_inner_entry, false, "clear resets skip_next_inner_entry")
    _assert_eq(ret.key, "skip_next_inner_entry", "clear returns the skip-flag write result")
  end)

  it("rejects an unknown sync mode", function()
    local g = _make_game()
    local p = _player("left")
    local ok, err = pcall(facing_policy.sync_move_dir_after_position_change, g, p, 1, "bogus")
    _assert_eq(ok, false, "an invalid sync mode must assert")
    assert(tostring(err):find("invalid move_dir sync mode", 1, true) ~= nil,
      "the assertion names the invalid-mode contract")
  end)
end)

describe("facing_policy.should_skip_inner_entry closure", function()
  -- board carrying a single entry point at tile id 7.
  local function _board(tile_at_position)
    return {
      map = { entry_points = { [7] = true } },
      get_tile = function(_, _pos) return tile_at_position end,
    }
  end

  it("is true when the flagged player stands on an entry-point tile", function()
    local board = _board({ id = 7 })
    local player = { position = 5, status = { skip_next_inner_entry = true } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), true,
      "flag set + tile is an entry point -> skip")
  end)

  it("is false when the skip flag is not set", function()
    local board = _board({ id = 7 })
    local player = { position = 5, status = { skip_next_inner_entry = false } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), false,
      "without the flag, never skip")
  end)

  it("is false when the current tile is not an entry point", function()
    local board = _board({ id = 99 })
    local player = { position = 5, status = { skip_next_inner_entry = true } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), false,
      "a non-entry tile id is not in entry_points")
  end)

  it("is false when the current tile cannot be resolved", function()
    local board = _board(nil)
    local player = { position = 5, status = { skip_next_inner_entry = true } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), false,
      "a nil tile cannot be an entry point")
  end)

  it("is false when the board has no entry-point map", function()
    local board = { map = {}, get_tile = function() return { id = 7 } end }
    local player = { position = 5, status = { skip_next_inner_entry = true } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), false,
      "missing entry_points map short-circuits to false")
  end)

  it("is false for a player with no position", function()
    local board = _board({ id = 7 })
    local player = { status = { skip_next_inner_entry = true } }
    _assert_eq(facing_policy.should_skip_inner_entry(board, player), false,
      "no position means nothing to skip")
  end)
end)

describe("facing_policy.resolve_initial_facing closure", function()
  it("fresh_forward always starts with no heading", function()
    _assert_eq(facing_policy.resolve_initial_facing("fresh_forward", _player("left"), { direction = "up" }),
      nil, "fresh_forward ignores any supplied direction")
  end)

  it("resume_forward returns the explicit direction", function()
    _assert_eq(facing_policy.resolve_initial_facing("resume_forward", _player(nil), { direction = "down" }),
      "down", "resume_forward echoes opts.direction")
  end)

  it("relative_forward prefers an explicit direction", function()
    _assert_eq(facing_policy.resolve_initial_facing("relative_forward", _player("left"), { direction = "right" }),
      "right", "an explicit direction wins over the player's heading")
  end)

  it("relative_backward falls back to the player's recorded heading", function()
    _assert_eq(facing_policy.resolve_initial_facing("relative_backward", _player("up"), {}),
      "up", "no explicit direction falls back to the player's move_dir")
  end)

  it("relative_forward with no direction and no heading yields nil", function()
    _assert_eq(facing_policy.resolve_initial_facing("relative_forward", _player(nil), nil),
      nil, "no direction anywhere resolves to nil")
  end)

  it("rejects an unknown facing mode", function()
    local ok, err = pcall(facing_policy.resolve_initial_facing, "sideways", _player("up"), {})
    _assert_eq(ok, false, "an invalid facing mode must assert")
    assert(tostring(err):find("invalid facing mode", 1, true) ~= nil,
      "the assertion names the invalid-mode contract")
  end)
end)
