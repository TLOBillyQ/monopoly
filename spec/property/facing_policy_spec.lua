local property = require("spec.support.property")
local facing_policy = require("src.rules.board.facing_policy")

-- Pool of direction-like values. The policy treats move_dir as an opaque token,
-- so any distinct non-nil values exercise the pass-through paths; nil exercises
-- the "no direction" fallbacks.
local DIRECTIONS = { "left", "right", "up", "down", "forward", "backward" }

local function _maybe_direction(rng)
  if rng:bool() then
    return rng:pick(DIRECTIONS)
  end
  return nil
end

-- player is sometimes absent / status-less so _player_move_dir's nil guards run.
local function _gen_player(rng)
  local shape = rng:int(1, 3)
  if shape == 1 then
    return nil
  end
  if shape == 2 then
    return {}
  end
  return { status = { move_dir = _maybe_direction(rng) } }
end

local function _player_move_dir(player)
  local status = player and player.status or nil
  return status and status.move_dir or nil
end

describe("facing_policy.resolve_initial_facing facing-mode properties", function()
  it("fresh_forward resolves to nil for any player and opts.direction", function()
    property.for_all(function(rng)
      return { player = _gen_player(rng), direction = _maybe_direction(rng) }
    end, function(case)
      local result = facing_policy.resolve_initial_facing("fresh_forward", case.player, {
        direction = case.direction,
      })
      assert(result == nil, "fresh_forward must ignore inputs and return nil, got " .. tostring(result))
    end)
  end)

  it("resume_forward round-trips opts.direction unchanged", function()
    property.for_all(function(rng)
      return { player = _gen_player(rng), direction = rng:pick(DIRECTIONS) }
    end, function(case)
      local result = facing_policy.resolve_initial_facing("resume_forward", case.player, {
        direction = case.direction,
      })
      assert(result == case.direction,
        "resume_forward must echo opts.direction " .. tostring(case.direction) .. ", got " .. tostring(result))
    end)
  end)

  it("resume_forward without opts.direction is rejected", function()
    property.for_all(_gen_player, function(player)
      local ok = pcall(facing_policy.resolve_initial_facing, "resume_forward", player, {})
      assert(not ok, "resume_forward must require opts.direction")
    end)
  end)

  it("relative modes prefer opts.direction, else fall back to the player's move_dir", function()
    property.for_all(function(rng)
      return {
        mode = rng:pick({ "relative_forward", "relative_backward" }),
        player = _gen_player(rng),
        direction = _maybe_direction(rng),
      }
    end, function(case)
      local result = facing_policy.resolve_initial_facing(case.mode, case.player, {
        direction = case.direction,
      })
      local expected = case.direction
      if expected == nil then
        expected = _player_move_dir(case.player)
      end
      assert(result == expected,
        "relative mode expected " .. tostring(expected) .. ", got " .. tostring(result))
    end)
  end)

  it("opts defaults to empty so a nil opts behaves like no direction", function()
    property.for_all(function(rng)
      return { mode = rng:pick({ "relative_forward", "relative_backward" }), player = _gen_player(rng) }
    end, function(case)
      local result = facing_policy.resolve_initial_facing(case.mode, case.player)
      assert(result == _player_move_dir(case.player),
        "nil opts must resolve to the player's move_dir, got " .. tostring(result))
    end)
  end)

  it("rejects any mode outside the valid set", function()
    property.for_all(function(rng)
      -- Random tokens that are never one of the four valid modes.
      return "mode_" .. tostring(rng:int(0, 1000000)) .. (rng:bool() and "" or "_x")
    end, function(mode)
      local ok = pcall(facing_policy.resolve_initial_facing, mode, nil, {})
      assert(not ok, "invalid mode " .. tostring(mode) .. " must be rejected")
    end)
  end)
end)

describe("facing_policy.should_skip_inner_entry predicate properties", function()
  -- Board where tile index i carries id i; entry_points holds a random subset of
  -- those ids. Positions may run past the board so get_tile can return nil.
  local function _gen_case(rng)
    local tile_count = rng:int(1, 8)
    local entry_points = {}
    for id = 1, tile_count do
      if rng:bool() then
        entry_points[id] = true
      end
    end
    return {
      tile_count = tile_count,
      entry_points = entry_points,
      position = rng:int(1, tile_count + 2),
      has_map = rng:bool(),
      skip = rng:bool(),
      has_status = rng:bool(),
    }
  end

  local function _build_board(case)
    local path = {}
    for i = 1, case.tile_count do
      path[i] = { id = i }
    end
    local map = nil
    if case.has_map then
      map = { entry_points = case.entry_points }
    end
    return {
      map = map,
      get_tile = function(_, idx) return path[idx] end,
    }
  end

  local function _build_player(case)
    local status = nil
    if case.has_status then
      status = { skip_next_inner_entry = case.skip }
    end
    return { position = case.position, status = status }
  end

  it("returns true exactly when the skip flag is set on an entry-point tile", function()
    property.for_all(_gen_case, function(case)
      local board = _build_board(case)
      local player = _build_player(case)

      local result = facing_policy.should_skip_inner_entry(board, player)

      local tile = board:get_tile(case.position)
      local flag_set = case.has_status and case.skip == true
      local on_entry_point = case.has_map and tile ~= nil and case.entry_points[tile.id] ~= nil
      local expected = flag_set and on_entry_point

      assert(result == expected,
        "expected " .. tostring(expected) .. ", got " .. tostring(result))
    end)
  end)

  it("never skips when the skip flag is absent or false", function()
    property.for_all(_gen_case, function(case)
      case.skip = false
      local result = facing_policy.should_skip_inner_entry(_build_board(case), _build_player(case))
      assert(result == false, "no skip flag must never skip, got " .. tostring(result))
    end)
  end)

  it("is false for any missing structural prerequisite", function()
    property.for_all(function(rng)
      return { missing = rng:pick({ "board", "map", "player", "position" }) }
    end, function(case)
      local board = { map = { entry_points = { [1] = true } }, get_tile = function(_, _) return { id = 1 } end }
      local player = { position = 1, status = { skip_next_inner_entry = true } }
      if case.missing == "board" then board = nil end
      if case.missing == "map" then board.map = nil end
      if case.missing == "player" then player = nil end
      if case.missing == "position" then player.position = nil end
      assert(facing_policy.should_skip_inner_entry(board, player) == false,
        "missing " .. case.missing .. " must yield false")
    end)
  end)
end)
