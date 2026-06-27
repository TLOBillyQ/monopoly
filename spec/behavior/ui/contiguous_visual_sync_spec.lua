local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local contiguous_count = require("src.ui.view.contiguous_count")
local visual_sync = require("src.ui.render.board.visual_sync")

local function _build_board(tiles, neighbors)
  local lookup = {}
  local index_by_id = {}
  for index, tile in ipairs(tiles) do
    lookup[tile.id] = tile
    index_by_id[tile.id] = index
  end
  local board = {
    path = tiles,
    tile_lookup = lookup,
    map = { neighbors = neighbors or {} },
  }
  function board:get_tile_by_id(tile_id)
    return lookup[tile_id]
  end
  function board:index_of_tile_id(tile_id)
    return index_by_id[tile_id]
  end
  return board
end

describe("presentation contiguous visual sync", function()
  it("contiguous_count ignores non-land neighbors when building owner components", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10 },
      { id = 39, type = "market", owner_id = 10 },
      { id = 2, type = "land", owner_id = 10 },
    }, {
      [1] = { right = 39 },
      [39] = { left = 1, right = 2 },
      [2] = { left = 39 },
    })

    local counts = contiguous_count.build_for_owner(board, 10)

    _assert_eq(contiguous_count.for_tile(board, 1, 10), 1, "non-land neighbor should not connect land tiles")
    _assert_eq(counts[1], 1, "first isolated land tile should count itself")
    _assert_eq(counts[2], 1, "second isolated land tile should count itself")
    _assert_eq(counts[39], nil, "non-land tile should not receive a contiguous count")
  end)

  it("contiguous_count falls back to the get_tile_by_id seam when no tile_lookup exists", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10 },
      { id = 2, type = "land", owner_id = 10 },
      { id = 3, type = "land", owner_id = 20 },
    }, {
      [1] = { right = 2 },
      [2] = { left = 1, right = 3 },
      [3] = { left = 2 },
    })
    board.tile_lookup = nil -- force _owner_of through the function seam

    _assert_eq(contiguous_count.for_tile(board, 1, 10), 2, "connected owner land tiles should count via get_tile_by_id")
    _assert_eq(contiguous_count.for_tile(board, 3, 20), 1, "isolated owner tile should count itself via the seam")
  end)

  it("contiguous_count returns zero for nil inputs and owner mismatches", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10 },
    }, { [1] = {} })

    _assert_eq(contiguous_count.for_tile(nil, 1, 10), 0, "nil board should yield zero")
    _assert_eq(contiguous_count.for_tile(board, nil, 10), 0, "nil tile id should yield zero")
    _assert_eq(contiguous_count.for_tile(board, 1, nil), 0, "nil owner id should yield zero")
    _assert_eq(contiguous_count.for_tile(board, 1, 99), 0, "owner mismatch should yield zero")
    _assert_eq(next(contiguous_count.build_for_owner(nil, 10)), nil, "nil board should produce no owner counts")
    _assert_eq(next(contiguous_count.build_for_owner(board, nil)), nil, "nil owner id should produce no counts")
  end)

  it("contiguous_count treats a board without a neighbour map as fully disconnected", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10 },
      { id = 2, type = "land", owner_id = 10 },
    })
    board.map = nil -- no neighbour map: land tiles cannot connect

    _assert_eq(contiguous_count.for_tile(board, 1, 10), 1, "without a neighbour map each owned tile counts only itself")
    local counts = contiguous_count.build_for_owner(board, 10)
    _assert_eq(counts[1], 1, "first tile is its own singleton component")
    _assert_eq(counts[2], 1, "second tile is its own singleton component")
  end)

  it("contiguous_count can project the same component rent total to each owned tile", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10, level = 1, price = 100, upgrade_costs = { 100 } },
      { id = 2, type = "land", owner_id = 10, level = 0, price = 100 },
      { id = 3, type = "land", owner_id = 20, level = 0, price = 100 },
    }, {
      [1] = { right = 2 },
      [2] = { left = 1, right = 3 },
      [3] = { left = 2 },
    })

    local rents = contiguous_count.build_rent_for_owner(board, 10, function(tile)
      if tile.level == 1 then return 100 end
      return 50
    end)

    _assert_eq(rents[1], 150, "first connected owner tile should receive component total rent")
    _assert_eq(rents[2], 150, "second connected owner tile should receive the same component total rent")
    _assert_eq(rents[3], nil, "other owner tile should not receive this owner's rent total")
  end)

  it("contiguous_count yields zero when neither read seam can resolve an owner", function()
    local board = { path = {}, map = { neighbors = {} } } -- no tile_lookup, no get_tile_by_id

    _assert_eq(contiguous_count.for_tile(board, 1, 10), 0, "unresolvable owner should yield zero")
    _assert_eq(next(contiguous_count.build_for_owner(board, 10)), nil, "empty board should produce no counts")
  end)

  it("visual_sync expands affected owners, dedupes explicit tiles, and renders contiguous rent totals", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10, level = 1, price = 100, upgrade_costs = { 100 } },
      { id = 2, type = "land", owner_id = 10, level = 0, price = 100 },
      { id = 3, type = "land", owner_id = 20, level = 0, price = 100 },
    }, {
      [1] = { right = 2 },
      [2] = { left = 1, right = 3 },
      [3] = { left = 2 },
    })
    local game = {
      board = board,
      turn = {},
    }
    function game:find_player_by_id(player_id)
      if player_id == 10 then
        return { id = 10, name = "Ada" }
      end
      return nil
    end
    local state = {
      game = game,
      board_scene = {
        tiles = {
          [1] = { name = "unit_1" },
          [2] = { name = "unit_2" },
          [3] = { name = "unit_3" },
        },
      },
    }
    local calls = {}

    _with_patches({
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function(unit, tile_id, owner_id, owner_name, level, contiguous_rent)
          calls[#calls + 1] = {
            unit = unit,
            tile_id = tile_id,
            owner_id = owner_id,
            owner_name = owner_name,
            level = level,
            contiguous_rent = contiguous_rent,
          }
        end,
      },
    }, function()
      local handled = visual_sync.sync_many(state, {
        tile_ids = { 1, 1 },
        affected_owner_ids = { 10, 10 },
      })
      _assert_eq(handled, true, "sync_many should handle rendered owner tiles")
    end)

    _assert_eq(#calls, 2, "explicit and expanded owner tiles should be rendered once each")
    _assert_eq(calls[1].tile_id, 1, "explicit tile should render first")
    _assert_eq(calls[1].owner_name, "Ada", "owner name should be resolved for renderer")
    _assert_eq(calls[1].level, 1, "tile level should be forwarded")
    _assert_eq(calls[1].contiguous_rent, 150, "first connected owner tile should receive total contiguous rent")
    _assert_eq(calls[2].tile_id, 2, "affected owner expansion should render second owned tile")
    _assert_eq(calls[2].contiguous_rent, 150, "second connected owner tile should receive total contiguous rent")
  end)

  it("visual_sync uses building branch when scene exposes building groups", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10, level = 2 },
    })
    local state = {
      game = { board = board },
      board_scene = {
        tiles = { [1] = { name = "unit_1" } },
        buildings = { [1] = {} },
        building_unit_groups = {},
      },
    }
    local spawned = nil

    _with_patches({
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function() end,
      },
      {
        target = require("src.ui.render.building_effects"),
        key = "spawn_upgrade_building_units",
        value = function(scene, _q, idx, level)
          spawned = { scene = scene, idx = idx, level = level }
          return true
        end,
      },
    }, function()
      local handled = visual_sync.sync_tile_visual(state, 1)
      _assert_eq(handled, true, "building branch should mark tile sync handled")
    end)

    _assert_eq(spawned.scene, state.board_scene, "building sync should use board scene")
    _assert_eq(spawned.idx, 1, "building sync should use board index")
    _assert_eq(spawned.level, 2, "building sync should forward tile level")
  end)

  it("visual_sync keeps overlay while matching trigger animation is queued", function()
    local board = {
      has_roadblock = function(_, idx)
        _assert_eq(idx, 1, "roadblock check should receive board index")
        return false
      end,
      has_mine = function(_, idx)
        _assert_eq(idx, 1, "mine check should receive board index")
        return false
      end,
    }
    local state = {
      game = {
        board = board,
        turn = {
          action_anim_queue = {
            { kind = "roadblock_trigger", tile_index = 1 },
          },
        },
      },
      board_scene = {},
    }
    local cleared = {}

    _with_patches({
      {
        target = require("src.ui.render.anim.overlay_runtime"),
        key = "clear_overlay",
        value = function(_, kind, idx)
          cleared[#cleared + 1] = kind .. ":" .. tostring(idx)
        end,
      },
    }, function()
      local handled = visual_sync.sync_overlay_visual(state, 1)
      _assert_eq(handled, true, "overlay sync should handle valid board index")
    end)

    _assert_eq(#cleared, 1, "queued roadblock trigger should suppress roadblock clear only")
    _assert_eq(cleared[1], "mine:1", "mine overlay should still clear without matching pending animation")
  end)
end)
