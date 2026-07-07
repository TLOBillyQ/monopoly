local placement = require("src.ui.render.board.placement")
local runtime_state = require("src.ui.state.runtime")
local move_anim = require("src.ui.render.move_anim")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed")
    .. " expected=" .. tostring(expected)
    .. " actual=" .. tostring(actual))
end

local function _ensure_vector3()
  if not math.Vector3 then
    function math.Vector3(x, y, z)
      return { x = x, y = y, z = z }
    end
  end
end

local function _with_patches(patches, fn)
  local originals = {}
  for index, patch in ipairs(patches) do
    originals[index] = patch.target[patch.key]
    patch.target[patch.key] = patch.value
  end
  local ok, result = pcall(fn)
  for index, patch in ipairs(patches) do
    patch.target[patch.key] = originals[index]
  end
  if not ok then
    error(result)
  end
  return result
end

local function _reload_with(module_name, overrides, fn)
  local original_module = package.loaded[module_name]
  local originals = {}
  for key, value in pairs(overrides or {}) do
    originals[key] = package.loaded[key]
    package.loaded[key] = value
  end
  package.loaded[module_name] = nil

  local ok, result = pcall(function()
    return fn(require(module_name))
  end)

  package.loaded[module_name] = original_module
  for key, value in pairs(originals) do
    package.loaded[key] = value
  end
  if not ok then
    error(result)
  end
  return result
end

local function _based(x, y, z)
  return setmetatable({ x = x, y = y, z = z }, {
    __add = function(a, b) return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z } end,
  })
end

describe("board placement mutation coverage", function()
  before_each(function()
    _ensure_vector3()
  end)

  it("build_snapshot alternates between the double-buffered snapshot tables", function()
    local players = { { id = "p1", position = 3 } }
    local first = placement.build_snapshot(players)
    local second = placement.build_snapshot(players)
    assert(first ~= second, "consecutive snapshots should use distinct buffer tables")
    local third = placement.build_snapshot(players)
    assert(third == first, "the third snapshot should reuse the first buffer")
  end)

  it("build_snapshot encodes position and eliminated flag per player", function()
    local players = {
      { id = "alive", position = 3, eliminated = false },
      { id = "dead", position = 8, eliminated = true },
    }
    local snapshot = placement.build_snapshot(players)
    _assert_eq(snapshot.alive, "3:0", "living player encodes eliminated as 0")
    _assert_eq(snapshot.dead, "8:1", "eliminated player encodes eliminated as 1")
  end)

  it("compute_need_sync stays false when snapshot matches last positions and nothing pends", function()
    local state = {
      board_runtime = {
        board_last_positions = { p1 = "3:0" },
        board_sync_pending = false,
        follow_targets = {},
      },
    }
    local snapshot = { p1 = "3:0" }
    _assert_eq(placement.compute_need_sync(state, snapshot), false,
      "no pending sync and identical positions should not require a sync")
  end)

  it("build_occupants appends active players in slot order and skips eliminated", function()
    local state = { tile_positions = { [3] = {}, [4] = {} } }
    local players = {
      { id = "a", position = 3 },
      { id = "b", position = 3 },
      { id = "c", position = 4, eliminated = true },
    }
    local occ = placement.build_occupants(state, players)
    assert(occ[3] ~= nil, "shared tile should have an occupant list")
    _assert_eq(occ[3][1], "a", "first active occupant should take slot 1")
    _assert_eq(occ[3][2], "b", "second active occupant should take slot 2")
    _assert_eq(#occ[3], 2, "shared tile should list both active occupants")
    assert(occ[4] == nil or #occ[4] == 0, "eliminated player should not be listed")
  end)

  it("build_occupants clears occupant list tables in place and reuses them", function()
    local state = { tile_positions = { [5] = {} } }
    local players = { { id = "x", position = 5 } }
    local first = placement.build_occupants(state, players)
    local list_ref = first[5]
    assert(list_ref ~= nil, "occupant list should exist after first build")
    local second = placement.build_occupants(state, players)
    assert(second[5] == list_ref, "occupant list table should be cleared in place and reused")
  end)

  it("resolve_occupant_slot defaults count to one for a nil list", function()
    local slot, count = placement._resolve_occupant_slot(nil, "p1")
    _assert_eq(slot, 1, "nil list should default slot to 1")
    _assert_eq(count, 1, "nil list should default count to 1")
  end)

  it("resolve_min_player_y adds the configured ground offset to the ground height", function()
    local scene = { ground = { get_position = function() return { x = 0.0, y = 3.0, z = 0.0 } end } }
    local result = _reload_with("src.ui.render.board.placement_snap", {
      ["src.config.gameplay.camera_follow"] = { player_min_ground_offset = 2.0 },
    }, function(snap)
      return snap.resolve_min_player_y(scene)
    end)
    _assert_eq(result, 5.0, "min player y should be ground y (3.0) plus configured offset (2.0)")
  end)

  it("place_players lays nine occupants on a centered ceil-sqrt grid", function()
    local saved_vector3 = math.Vector3
    function math.Vector3(x, y, z) return { x = x, y = y, z = z } end

    local placed = {}
    local units = {}
    local players = {}
    local occ = {}
    for n = 1, 9 do
      players[n] = { id = n, position = 7 }
      units[n] = { set_position = function(pos) placed[n] = pos end }
      occ[n] = n
    end

    _with_patches({
      { target = runtime_state, key = "set_follow_target_position", value = function() end },
      { target = move_anim, key = "stop_player_presentation", value = function() return {} end },
    }, function()
      local state = {
        tile_positions = { [7] = _based(10.0, 5.0, 20.0) },
        player_units = units,
      }
      placement.place_players(state, players, { [7] = occ }, 2.0, 0.0)
    end)

    -- per_row = ceil(sqrt(9)) = 3, spacing 2.0, centering start = -2.0.
    -- slot s -> row = floor((s-1)/3), col = (s-1)%3; ox = -2 + col*2, oz = -2 + row*2.
    local expected = {
      [1] = { x = 8.0, z = 18.0 },
      [2] = { x = 10.0, z = 18.0 },
      [3] = { x = 12.0, z = 18.0 },
      [4] = { x = 8.0, z = 20.0 },
      [5] = { x = 10.0, z = 20.0 },
      [6] = { x = 12.0, z = 20.0 },
      [7] = { x = 8.0, z = 22.0 },
      [8] = { x = 10.0, z = 22.0 },
      [9] = { x = 12.0, z = 22.0 },
    }
    for n = 1, 9 do
      _assert_eq(placed[n].x, expected[n].x, "slot " .. tostring(n) .. " x offset")
      _assert_eq(placed[n].z, expected[n].z, "slot " .. tostring(n) .. " z offset")
    end
    math.Vector3 = saved_vector3
  end)

  it("place_players separates occupants for a fractional spacing above zero", function()
    local saved_vector3 = math.Vector3
    function math.Vector3(x, y, z) return { x = x, y = y, z = z } end

    local placed = {}
    local units = {
      [1] = { set_position = function(pos) placed[1] = pos end },
      [2] = { set_position = function(pos) placed[2] = pos end },
    }
    _with_patches({
      { target = runtime_state, key = "set_follow_target_position", value = function() end },
      { target = move_anim, key = "stop_player_presentation", value = function() return {} end },
    }, function()
      local state = {
        tile_positions = { [2] = _based(4.0, 0.0, 6.0) },
        player_units = units,
      }
      placement.place_players(state,
        { { id = 1, position = 2 }, { id = 2, position = 2 } },
        { [2] = { 1, 2 } }, 1.0, 0.0)
    end)

    -- spacing 1.0 (> 0) so the offset guard does not collapse: per_row = 2, start = -0.5.
    _assert_eq(placed[1].x, 3.5, "slot 1 should shift half a spacing left of base")
    _assert_eq(placed[2].x, 4.5, "slot 2 should shift half a spacing right of base")
    math.Vector3 = saved_vector3
  end)

  it("place_players collapses offsets to base for non-positive spacing", function()
    local saved_vector3 = math.Vector3
    function math.Vector3(x, y, z) return { x = x, y = y, z = z } end

    local placed = {}
    local units = {
      [1] = { set_position = function(pos) placed[1] = pos end },
      [2] = { set_position = function(pos) placed[2] = pos end },
    }
    _with_patches({
      { target = runtime_state, key = "set_follow_target_position", value = function() end },
      { target = move_anim, key = "stop_player_presentation", value = function() return {} end },
    }, function()
      local state = {
        tile_positions = { [1] = _based(4.0, 0.0, 6.0) },
        player_units = units,
      }
      placement.place_players(state,
        { { id = 1, position = 1 }, { id = 2, position = 1 } },
        { [1] = { 1, 2 } }, -2.0, 0.0)
    end)

    -- spacing -2.0 (<= 0) hits the guard, so both occupants land on the base tile.
    _assert_eq(placed[1].x, 4.0, "non-positive spacing should keep slot 1 on base x")
    _assert_eq(placed[2].x, 4.0, "non-positive spacing should keep slot 2 on base x")
    _assert_eq(placed[1].z, 6.0, "non-positive spacing should keep slot 1 on base z")
    _assert_eq(placed[2].z, 6.0, "non-positive spacing should keep slot 2 on base z")
    math.Vector3 = saved_vector3
  end)
end)
