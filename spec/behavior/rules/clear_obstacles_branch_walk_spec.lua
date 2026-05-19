-- Contract tests for _handle_clear_obstacles_ahead.
-- Payload must use branch-based walk data:
-- { kind="clear_obstacles", branches=..., duration=... }.
-- luacheck: ignore 211

local support = require("spec.support.shared_support")
local default_map = require("src.config.content.default_map")
local action_anim_port = require("src.foundation.ports.action_anim")
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")

local _assert_eq = support.assert_eq

local function _new_game()
  return support.new_game({ map = default_map })
end

-- Enable action_anim so action_anim_port.queue actually captures a payload.
-- Returns the captured payload after calling fn().
local function _capture_anim_payload(game, fn)
  local captured = nil
  game.anim_gate_port = { wait_action_anim = true }
  game.queue_action_anim = function(_, payload)
    captured = payload
  end
  support.with_patches({
    {
      target = action_anim_port,
      key = "queue",
      value = function(_, payload)
        captured = payload
        return true
      end,
    },
  }, fn)
  return captured
end

describe("domain.clear_obstacles_branch_walk", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("linear_path_produces_single_branch_with_12_entries", function()
    local g = _new_game()
    local p = g:current_player()

    -- Position player at index 1 (start tile) and face "right" along outer ring.
    -- The outer ring starts at (9,9) and goes left, so first direction is "left".
    -- We set move_dir to match the natural forward direction at index 1.
    -- In default_map, outer ring goes left from (9,9), so forward = "left".
    g:update_player_position(p, 1)
    g:set_player_status(p, "move_dir", "left")

    -- Place roadblocks at indices 3, 7, 10 (ahead of player on outer ring).
    g.board:place_roadblock(3)
    g.board:place_roadblock(7)
    g.board:place_roadblock(10)

    local cfg = { distance = 12 }
    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    _assert_eq(#payload.branches, 1, "linear path should produce exactly 1 branch")

    local branch = payload.branches[1]
    assert(type(branch) == "table", "branch should be a table")
    _assert_eq(#branch, 12, "linear branch should have exactly 12 entries (full distance)")

    -- Find positions 3, 7, 10 relative to starting position 1.
    -- Entries are ordered: branch[1]=index 2, branch[2]=index 3, ..., branch[n]=index n+1
    -- (player is at index 1, walk starts from neighbor of index 1)
    local obstacle_relative_positions = { 2, 6, 9 } -- branch[2]=idx3, branch[6]=idx7, branch[9]=idx10
    for _, rel_pos in ipairs(obstacle_relative_positions) do
      assert(type(branch[rel_pos]) == "table",
        "branch entry at position " .. rel_pos .. " should be a table")
      assert(branch[rel_pos].has_obstacle == true,
        "branch entry at relative position " .. rel_pos .. " should have has_obstacle=true")
    end

    -- Spot-check: first entry should not be an obstacle
    assert(branch[1].has_obstacle == false,
      "branch[1] (index 2, no obstacle) should have has_obstacle=false")

    -- Each entry must have tile_index field
    for i, entry in ipairs(branch) do
      assert(type(entry) == "table" and entry.tile_index ~= nil,
        "branch entry " .. i .. " must have tile_index field")
    end
  end)

  it("forked_path_produces_two_branches", function()
    local g = _new_game()
    local p = g:current_player()

    -- Find the index of the tile just before the fork.
    -- In default_map, outer ring position (9,6) leads forward to (9,5),
    -- which has two forward neighbors: (9,4) and (8,5).
    -- outer_ccw_coords: {9,9},{9,8},{9,7},{9,6},{9,5},...
    -- So outer ring index 4 = (9,6), index 5 = (9,5).
    -- Place player at index 4 facing "left" (toward (9,5)).
    -- After 1 step we reach (9,5) which is the fork.
    local fork_approach_index = 4  -- tile at (9,6)
    g:update_player_position(p, fork_approach_index)
    g:set_player_status(p, "move_dir", "left")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    assert(#payload.branches >= 2,
      "forked path should produce at least 2 branches, got " .. tostring(#payload.branches))

    -- Each branch must be an ordered array of entries
    for b_idx, branch in ipairs(payload.branches) do
      assert(type(branch) == "table", "branch " .. b_idx .. " should be a table")
      assert(#branch > 0, "branch " .. b_idx .. " should be non-empty")
      for e_idx, entry in ipairs(branch) do
        assert(type(entry) == "table", "branch " .. b_idx .. " entry " .. e_idx .. " should be a table")
        assert(entry.tile_index ~= nil,
          "branch " .. b_idx .. " entry " .. e_idx .. " must have tile_index")
        assert(type(entry.has_obstacle) == "boolean",
          "branch " .. b_idx .. " entry " .. e_idx .. " must have boolean has_obstacle")
      end
    end
  end)

  it("dead_end_stops_at_board_edge", function()
    local g = _new_game()
    local p = g:current_player()

    -- Build a synthetic 6-tile linear board: tiles with ids 101..106.
    -- Neighbor chain: 101→102→103→104→105→106 (rightward).
    -- No outgoing neighbor from tile 106 (dead end).
    -- Player at index 1 (tile 101), distance=12, expect 5 entries in branch.
    local Board = require("src.rules.board")
    local tiles = {}
    local tile_lookup = {}
    local neighbors_map = {}
    local ids = {101, 102, 103, 104, 105, 106}
    for i, id in ipairs(ids) do
      local t = { id = id, name = "T" .. i, type = "land", row = i, col = 1 }
      tiles[i] = t
      tile_lookup[id] = t
      neighbors_map[id] = {}
    end
    -- Chain neighbors: 101←→102←→103←→104←→105←→106 using "right"/"left"
    for i = 1, #ids - 1 do
      neighbors_map[ids[i]]["right"] = ids[i + 1]
      neighbors_map[ids[i + 1]]["left"] = ids[i]
    end

    local synthetic_board = Board:new({
      tile_lookup = tile_lookup,
      path = tiles,
      branches = {},
      map = {
        neighbors = neighbors_map,
        outer_next = {},
        outer_prev = {},
        entry_points = {},
        start_id = ids[1],
        direction = function(from_id, to_id)
          -- simple: if to_id > from_id it's "right", else "left"
          local from_pos = 0
          local to_pos = 0
          for i, id in ipairs(ids) do
            if id == from_id then from_pos = i end
            if id == to_id then to_pos = i end
          end
          return to_pos > from_pos and "right" or "left"
        end,
      },
      overlays = {
        roadblocks = {},
        mines = {},
      },
    })

    -- Swap the game's board with our synthetic board.
    local original_board = g.board
    g.board = synthetic_board

    -- Player at index 1 (tile 101), facing "right".
    p.position = 1
    g:set_player_status(p, "move_dir", "right")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    -- Restore original board
    g.board = original_board

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    _assert_eq(#payload.branches, 1, "dead-end path should produce exactly 1 branch")

    local branch = payload.branches[1]
    assert(type(branch) == "table", "branch should be a table")
    _assert_eq(#branch, 5,
      "dead-end branch should stop at board edge with 5 entries, not padded to 12")
  end)

  it("duration_is_positive_number_in_payload", function()
    local g = _new_game()
    local p = g:current_player()

    g:update_player_position(p, 1)
    g:set_player_status(p, "move_dir", "left")

    local context = {}
    local payload = _capture_anim_payload(g, function()
      post_effects.apply_post(g, p, item_ids.clear_obstacles, context)
    end)

    assert(type(payload) == "table", "payload should be a table")
    assert(type(payload.branches) == "table",
      "payload must have 'branches' field (new contract) — got " .. tostring(payload.branches))
    assert(type(payload.duration) == "number",
      "payload.duration must be a number, got " .. type(payload.duration))
    assert(payload.duration > 0,
      "payload.duration must be positive, got " .. tostring(payload.duration))
    -- Sanity range: between 0.1s and 30s
    assert(payload.duration >= 0.1 and payload.duration <= 30,
      "payload.duration out of reasonable range [0.1, 30]: " .. tostring(payload.duration))
  end)
end)
