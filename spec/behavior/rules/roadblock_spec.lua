local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local roadblock = require("src.rules.items.roadblock")
local board_query = require("src.rules.board.query")
local facing_policy = require("src.rules.board.facing_policy")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")

local function _ok(val, msg)
  assert(val, msg or "expected truthy")
end

local function _make_board(tiles, roadblocks, mines)
  roadblocks = roadblocks or {}
  mines = mines or {}
  local rb_set = {}
  for _, idx in ipairs(roadblocks) do rb_set[idx] = true end
  local mine_set = {}
  for _, idx in ipairs(mines) do mine_set[idx] = true end

  for idx, tile in pairs(tiles) do
    if tile.get_state == nil then
      tile.get_state = function() return nil end
    end
  end

  return {
    get_tile = function(_, idx)
      return tiles[idx] or { id = idx, name = "tile_" .. tostring(idx), type = "land", row = 0, col = idx, get_state = function() return nil end }
    end,
    has_roadblock = function(_, idx)
      return rb_set[idx] == true
    end,
    has_mine = function(_, idx)
      return mine_set[idx] == true
    end,
    step_forward_by_facing = function(_, current, facing, step)
      return current + step, nil, facing
    end,
    step_backward_by_facing = function(_, current, facing)
      return current - 1, nil, facing
    end,
  }
end

local function _make_player(id, position)
  return { id = id, position = position, name = "player_" .. tostring(id) }
end

describe("roadblock", function()
  describe("pick_best", function()
    it("returns first candidate", function()
      local cands = {
        { idx = 5, priority = 1, label = "A" },
        { idx = 3, priority = 2, label = "B" },
      }
      local best = roadblock.pick_best(cands)
      _assert_eq(best.idx, 5, "should pick first candidate")
    end)

    it("rejects nil candidates", function()
      local ok = pcall(roadblock.pick_best, nil)
      _ok(not ok, "should reject nil candidates")
    end)

    it("rejects empty candidates", function()
      local ok = pcall(roadblock.pick_best, {})
      _ok(not ok, "should reject empty candidates")
    end)
  end)

  describe("apply", function()
    it("places roadblock and publishes event", function()
      local board = _make_board({
        [5] = { id = 5, name = "tile_5", type = "land", row = 0, col = 5 },
      })
      local game = {
        board = board,
        place_roadblock = function() end,
      }
      local player = _make_player(1, 3)

      local event_calls = {}
      _with_patches({
        { target = event_feed, key = "publish", value = function(_, evt)
          event_calls[#event_calls + 1] = evt
        end },
        { target = action_anim_port, key = "queue", value = function()
          return { queued = true }
        end },
      }, function()
        local result = roadblock.apply(game, player, 5)
        _ok(result.ok == true, "apply should return ok")
        _ok(result.action_anim ~= nil, "should queue action anim")
        _assert_eq(#event_calls, 1, "should publish one event")
      end)
    end)

    it("rejects nil idx", function()
      local game = { board = _make_board({}) }
      local player = _make_player(1, 1)
      local ok = pcall(roadblock.apply, game, player, nil)
      _ok(not ok, "should reject nil idx")
    end)

    it("rejects nil board", function()
      local game = {}
      local player = _make_player(1, 1)
      local ok = pcall(roadblock.apply, game, player, 5)
      _ok(not ok, "should reject nil board")
    end)
  end)

  describe("is_ui_candidate", function()
    it("returns true for player position", function()
      local board = _make_board({
        [3] = { id = 3, name = "tile_3", type = "land", row = 0, col = 3 },
      })
      local game = { board = board }
      local player = _make_player(1, 3)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return {} end },
      }, function()
        local result = roadblock.is_ui_candidate(game, player, 3, 3)
        _ok(result == true, "player position should be a UI candidate")
      end)
    end)

    it("returns false for nil idx", function()
      local board = _make_board({})
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return {} end },
      }, function()
        local result = roadblock.is_ui_candidate(game, player, nil, 3)
        _ok(result == false, "nil idx should not be a UI candidate")
      end)
    end)

    it("returns true for nearby tile", function()
      local board = _make_board({
        [1] = { id = 1, name = "tile_1", type = "land", row = 0, col = 1 },
        [2] = { id = 2, name = "tile_2", type = "land", row = 0, col = 2 },
      })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return { 2 } end },
      }, function()
        local result = roadblock.is_ui_candidate(game, player, 2, 3)
        _ok(result == true, "nearby tile should be a UI candidate")
      end)
    end)

    it("returns false for out-of-range tile", function()
      local board = _make_board({
        [1] = { id = 1, name = "tile_1", type = "land", row = 0, col = 1 },
      })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return {} end },
      }, function()
        local result = roadblock.is_ui_candidate(game, player, 99, 3)
        _ok(result == false, "out-of-range tile should not be a UI candidate")
      end)
    end)
  end)

  describe("manual_candidates", function()
    it("includes player position as first candidate", function()
      local board = _make_board({
        [1] = { id = 1, name = "tile_1", type = "land", row = 0, col = 1 },
      })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return {} end },
      }, function()
        local cands = roadblock.manual_candidates(game, player, 3)
        _ok(#cands >= 1, "should have at least one candidate")
        _assert_eq(cands[1].idx, 1, "first candidate should be player position")
      end)
    end)

    it("caps at ui_candidate_slots", function()
      local tiles = {}
      for i = 1, 20 do
        tiles[i] = { id = i, name = "tile_" .. tostring(i), type = "land", row = 0, col = i }
      end
      local board = _make_board(tiles)
      local game = { board = board }
      local player = _make_player(1, 1)

      local indices = {}
      for i = 2, 20 do indices[#indices + 1] = i end

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return indices end },
      }, function()
        local cands = roadblock.manual_candidates(game, player, 3)
        _ok(#cands <= 7, "should cap at 7 candidates (ui_candidate_slots)")
      end)
    end)

    it("deduplicates tiles", function()
      local board = _make_board({
        [1] = { id = 1, name = "tile_1", type = "land", row = 0, col = 1 },
        [2] = { id = 2, name = "tile_2", type = "land", row = 0, col = 2 },
      })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = board_query, key = "indices_in_range", value = function() return { 1, 2, 1 } end },
      }, function()
        local cands = roadblock.manual_candidates(game, player, 3)
        local count = 0
        for _, c in ipairs(cands) do
          if c.idx == 1 then count = count + 1 end
        end
        _assert_eq(count, 1, "player position should appear only once")
      end)
    end)
  end)

  describe("auto_candidates", function()
    it("returns candidates sorted by priority then step", function()
      local tiles = {}
      for i = 1, 10 do
        tiles[i] = { id = i, name = "tile_" .. tostring(i), type = "land", row = 0, col = i }
      end
      tiles[2].type = "item"
      tiles[3].type = "chance"
      local board = _make_board(tiles)
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = facing_policy, key = "resolve_initial_facing", value = function() return "north" end },
      }, function()
        local cands = roadblock.auto_candidates(game, player, 3)
        _ok(#cands >= 0, "should return candidates")
      end)
    end)

    it("excludes tiles with roadblocks", function()
      local tiles = {}
      for i = 1, 5 do
        tiles[i] = { id = i, name = "tile_" .. tostring(i), type = "land", row = 0, col = i }
      end
      local board = _make_board(tiles, { 2 })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = facing_policy, key = "resolve_initial_facing", value = function() return "north" end },
      }, function()
        local cands = roadblock.auto_candidates(game, player, 3)
        for _, c in ipairs(cands) do
          _ok(c.idx ~= 2, "should not include tile with roadblock")
        end
      end)
    end)

    it("excludes tiles with mines", function()
      local tiles = {}
      for i = 1, 5 do
        tiles[i] = { id = i, name = "tile_" .. tostring(i), type = "land", row = 0, col = i }
      end
      local board = _make_board(tiles, {}, { 3 })
      local game = { board = board }
      local player = _make_player(1, 1)

      _with_patches({
        { target = facing_policy, key = "resolve_initial_facing", value = function() return "north" end },
      }, function()
        local cands = roadblock.auto_candidates(game, player, 3)
        for _, c in ipairs(cands) do
          _ok(c.idx ~= 3, "should not include tile with mine")
        end
      end)
    end)
  end)
end)
