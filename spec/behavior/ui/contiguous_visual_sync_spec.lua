local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local contiguous_count = require("src.ui.view.contiguous_count")
local visual_sync = require("src.ui.render.board.visual_sync")

if not math.Vector3 then
  function math.Vector3(x, y, z)
    return { x = x, y = y, z = z }
  end
end

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

  it("shared.deps returns the presentation runtime carried by state", function()
    local shared = require("src.ui.render.board.visual_sync_shared")
    local runtime = { host = true }
    _assert_eq(shared.deps({ presentation_runtime = runtime }), runtime,
      "deps should return state.presentation_runtime")
    _assert_eq(shared.deps({}), nil, "deps should return nil when no runtime is present")
    _assert_eq(shared.deps(nil), nil, "deps should tolerate a nil state")
  end)

  it("sync_tile_visual prefers the cached tile unit over the scene tile unit", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = nil },
    })
    local cached_unit = { name = "cached" }
    local scene_unit = { name = "scene" }
    local state = {
      game = { board = board },
      tile_units = { [1] = cached_unit },
      board_scene = { tiles = { [1] = scene_unit } },
    }
    local rendered_unit = nil

    _with_patches({
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function(unit)
          rendered_unit = unit
        end,
      },
    }, function()
      local handled = visual_sync.sync_tile_visual(state, 1)
      _assert_eq(handled, true, "an existing tile unit should report the sync handled")
    end)

    _assert_eq(rendered_unit, cached_unit, "sync should render the cached tile unit, not the scene fallback")
  end)

  it("sync_tile_visual renders a zero component rent as no contiguous rent", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10, price = 100 },
    })
    local game = { board = board }
    function game:find_player_by_id(player_id)
      if player_id == 10 then
        return { id = 10, name = "Ada" }
      end
      return nil
    end
    local state = {
      game = game,
      board_scene = { tiles = { [1] = { name = "u1" } } },
    }
    local rendered_rent = "unset"

    _with_patches({
      {
        target = require("src.ui.view.contiguous_count"),
        key = "build_rent_for_owner",
        value = function()
          return { [1] = 0 }
        end,
      },
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function(_unit, _tile_id, _owner_id, _owner_name, _level, contiguous_rent)
          rendered_rent = contiguous_rent
        end,
      },
    }, function()
      visual_sync.sync_tile_visual(state, 1)
    end)

    _assert_eq(rendered_rent, nil, "a zero-sum component should render without a contiguous rent badge")
  end)

  it("sync_tile_visual forwards a positive component rent to the renderer", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = 10, price = 100 },
    })
    local game = { board = board }
    function game:find_player_by_id(player_id)
      if player_id == 10 then
        return { id = 10, name = "Ada" }
      end
      return nil
    end
    local state = {
      game = game,
      board_scene = { tiles = { [1] = { name = "u1" } } },
    }
    local rendered_rent = "unset"

    _with_patches({
      {
        target = require("src.ui.view.contiguous_count"),
        key = "build_rent_for_owner",
        value = function()
          return { [1] = 1 }
        end,
      },
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function(_unit, _tile_id, _owner_id, _owner_name, _level, contiguous_rent)
          rendered_rent = contiguous_rent
        end,
      },
    }, function()
      visual_sync.sync_tile_visual(state, 1)
    end)

    _assert_eq(rendered_rent, 1, "a positive component rent should be forwarded to the renderer")
  end)

  it("sync_tile_visual renders level 0 when the tile has no level", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = nil },
    })
    local state = {
      game = { board = board },
      board_scene = { tiles = { [1] = {} } },
    }
    local rendered_level = "unset"

    _with_patches({
      {
        target = require("src.ui.render.tile"),
        key = "render_tile",
        value = function(_unit, _tile_id, _owner_id, _owner_name, level)
          rendered_level = level
        end,
      },
    }, function()
      visual_sync.sync_tile_visual(state, 1)
    end)

    _assert_eq(rendered_level, 0, "a tile without a level should render at level 0")
  end)

  it("sync_tile_visual clears building units when the tile has no level", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = nil },
    })
    local state = {
      game = { board = board },
      board_scene = { tiles = { [1] = {} }, buildings = { [1] = {} }, building_unit_groups = {} },
    }
    local events = {}

    _with_patches({
      { target = require("src.ui.render.tile"), key = "render_tile", value = function() end },
      {
        target = require("src.ui.render.building_effects"),
        key = "spawn_upgrade_building_units",
        value = function()
          events[#events + 1] = "spawn"
          return true
        end,
      },
      {
        target = require("src.ui.render.building_effects"),
        key = "clear_building_units",
        value = function()
          events[#events + 1] = "clear"
        end,
      },
    }, function()
      local handled = visual_sync.sync_tile_visual(state, 1)
      _assert_eq(handled, true, "the clear branch should report the sync handled")
    end)

    _assert_eq(events[1], "clear", "a level-0 tile should clear building units")
    _assert_eq(#events, 1, "a level-0 tile should not spawn building units")
  end)

  it("sync_tile_visual spawns building units when the tile level is 1", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = nil, level = 1 },
    })
    local state = {
      game = { board = board },
      board_scene = { tiles = { [1] = {} }, buildings = { [1] = {} }, building_unit_groups = {} },
    }
    local events = {}

    _with_patches({
      { target = require("src.ui.render.tile"), key = "render_tile", value = function() end },
      {
        target = require("src.ui.render.building_effects"),
        key = "spawn_upgrade_building_units",
        value = function()
          events[#events + 1] = "spawn"
          return false
        end,
      },
      {
        target = require("src.ui.render.building_effects"),
        key = "clear_building_units",
        value = function()
          events[#events + 1] = "clear"
        end,
      },
    }, function()
      local handled = visual_sync.sync_tile_visual(state, 1)
      _assert_eq(handled, true, "the spawn branch should still report handled via the tile unit fallback")
    end)

    _assert_eq(events[1], "spawn", "a level-1 tile should spawn building units")
    _assert_eq(#events, 1, "a level-1 tile should not clear building units")
  end)

  it("sync_tile_visual skips building sync when only part of the building scene exists", function()
    local board = _build_board({
      { id = 1, type = "land", owner_id = nil, level = 2 },
    })
    local state = {
      game = { board = board },
      board_scene = { tiles = { [1] = {} }, buildings = { [1] = {} } }, -- no building_unit_groups
    }
    local events = {}

    _with_patches({
      { target = require("src.ui.render.tile"), key = "render_tile", value = function() end },
      {
        target = require("src.ui.render.building_effects"),
        key = "spawn_upgrade_building_units",
        value = function()
          events[#events + 1] = "spawn"
          return true
        end,
      },
      {
        target = require("src.ui.render.building_effects"),
        key = "clear_building_units",
        value = function()
          events[#events + 1] = "clear"
        end,
      },
    }, function()
      local handled = visual_sync.sync_tile_visual(state, 1)
      _assert_eq(handled, true, "an existing tile unit should still mark the sync handled")
    end)

    _assert_eq(#events, 0, "a partial building scene should neither spawn nor clear building units")
  end)

  it("sync_tile_visual returns false for a nil tile id", function()
    _assert_eq(visual_sync.sync_tile_visual({}, nil), false, "a nil tile id should not be handled")
  end)

  it("sync_tile_visual returns false when the board scene is missing", function()
    local board = _build_board({
      { id = 1, type = "land" },
    })
    local state = { game = { board = board } } -- no board_scene
    _assert_eq(visual_sync.sync_tile_visual(state, 1), false, "a missing scene should short-circuit tile sync")
  end)

  it("sync_tile_visual returns false when the tile id is not on the board", function()
    local board = _build_board({
      { id = 1, type = "land" },
    })
    local state = { game = { board = board }, board_scene = { tiles = {} } }
    _assert_eq(visual_sync.sync_tile_visual(state, 999), false, "an unknown tile id should not be handled")
  end)

  it("sync_overlay_visual returns false for a nil board index", function()
    _assert_eq(visual_sync.sync_overlay_visual({}, nil), false, "a nil board index should not be handled")
  end)

  it("sync_overlay_visual returns false when the board scene is missing", function()
    local board = {
      has_roadblock = function() return false end,
      has_mine = function() return false end,
    }
    local state = { game = { board = board } } -- no board_scene
    _with_patches({
      { target = require("src.ui.render.anim.overlay_runtime"), key = "clear_overlay", value = function() end },
    }, function()
      _assert_eq(visual_sync.sync_overlay_visual(state, 1), false, "a missing scene should short-circuit overlay sync")
    end)
  end)

  it("sync_overlay_visual clears both overlays when there is no active turn", function()
    local board = {
      has_roadblock = function() return false end,
      has_mine = function() return false end,
    }
    local state = { game = { board = board }, board_scene = {} } -- game.turn is nil
    local cleared = {}
    _with_patches({
      {
        target = require("src.ui.render.anim.overlay_runtime"),
        key = "clear_overlay",
        value = function(_scene, kind)
          cleared[#cleared + 1] = kind
        end,
      },
    }, function()
      _assert_eq(visual_sync.sync_overlay_visual(state, 1), true, "overlay sync should handle a valid board index")
    end)

    _assert_eq(#cleared, 2, "with no active turn both overlays should clear")
  end)

  it("sync_overlay_visual clears overlays when the anim queue is not a table", function()
    local board = {
      has_roadblock = function() return false end,
      has_mine = function() return false end,
    }
    -- turn is present but action_anim and action_anim_queue are nil
    local state = { game = { board = board, turn = {} }, board_scene = {} }
    local cleared = {}
    _with_patches({
      {
        target = require("src.ui.render.anim.overlay_runtime"),
        key = "clear_overlay",
        value = function(_scene, kind)
          cleared[#cleared + 1] = kind
        end,
      },
    }, function()
      visual_sync.sync_overlay_visual(state, 1)
    end)

    _assert_eq(#cleared, 2, "a nil anim queue should not suppress overlay clears")
  end)

  it("sync_overlay_visual keeps the mine overlay while a matching trigger animation plays", function()
    local board = {
      has_roadblock = function() return false end,
      has_mine = function() return false end,
    }
    local state = {
      game = {
        board = board,
        turn = {
          action_anim = { kind = "mine_trigger", tile_index = 1 },
          action_anim_queue = {},
        },
      },
      board_scene = {},
    }
    local cleared = {}
    _with_patches({
      {
        target = require("src.ui.render.anim.overlay_runtime"),
        key = "clear_overlay",
        value = function(_scene, kind)
          cleared[#cleared + 1] = kind
        end,
      },
    }, function()
      visual_sync.sync_overlay_visual(state, 1)
    end)

    _assert_eq(#cleared, 1, "only the roadblock overlay should clear")
    _assert_eq(cleared[1], "roadblock", "the mine overlay must persist while its trigger animation is active")
  end)

  it("sync_overlay_visual spawns the roadblock overlay with the host Vector3 scale", function()
    local overlay_runtime = require("src.ui.render.anim.overlay_runtime")
    local module_path = "src.ui.render.board.visual_sync_overlay"
    local saved_module = package.loaded[module_path]
    local saved_vector3 = math.Vector3
    package.loaded[module_path] = nil
    math.Vector3 = function(x, y, z)
      return { x = x, y = y, z = z, _host_vector = true }
    end
    local overlay_module = require(module_path)
    math.Vector3 = saved_vector3
    package.loaded[module_path] = saved_module

    local board = {
      has_roadblock = function() return true end,
      has_mine = function() return false end,
    }
    local state = { game = { board = board, turn = {} }, board_scene = { tiles = {} } }
    local spawned = nil

    _with_patches({
      {
        target = overlay_runtime,
        key = "spawn_overlay",
        value = function(_scene, kind, idx, _group, _unit, _pos, scale)
          if kind == "roadblock" then
            spawned = { idx = idx, scale = scale }
          end
        end,
      },
      { target = overlay_runtime, key = "clear_overlay", value = function() end },
    }, function()
      local handled = overlay_module.sync_overlay_visual(state, 1)
      _assert_eq(handled, true, "overlay sync should handle a roadblock tile")
    end)

    assert(spawned ~= nil, "a roadblock tile should spawn the roadblock overlay")
    _assert_eq(spawned.idx, 1, "roadblock overlay should target the board index")
    _assert_eq(spawned.scale.x, 4.0, "roadblock overlay scale should be the 4.0 vector")
    _assert_eq(spawned.scale._host_vector, true,
      "roadblock scale should be the host Vector3, not the plain fallback table")
  end)

  it("sync_many reports handled when an overlay index is synced", function()
    local overlay_sync = require("src.ui.render.board.visual_sync_overlay")
    local handled
    _with_patches({
      { target = overlay_sync, key = "sync_overlay_visual", value = function() return true end },
    }, function()
      handled = visual_sync.sync_many({}, { overlay_indices = { 1 } })
    end)
    _assert_eq(handled, true, "an overlay index that syncs should make sync_many report handled")
  end)

  it("sync_many reports not handled when overlay sync does nothing", function()
    local overlay_sync = require("src.ui.render.board.visual_sync_overlay")
    local handled
    _with_patches({
      { target = overlay_sync, key = "sync_overlay_visual", value = function() return false end },
    }, function()
      handled = visual_sync.sync_many({}, { overlay_indices = { 1 } })
    end)
    _assert_eq(handled, false, "overlay indices that sync nothing should not mark sync_many handled")
  end)

  it("sync_many reports not handled when tile sync does nothing", function()
    local tile_sync = require("src.ui.render.board.visual_sync_tile")
    local handled
    _with_patches({
      { target = tile_sync, key = "sync_tile_visual", value = function() return false end },
    }, function()
      handled = visual_sync.sync_many({}, { tile_ids = { 1 } })
    end)
    _assert_eq(handled, false, "tile ids that sync nothing should not mark sync_many handled")
  end)

  it("sync_many reports handled from the explicit tile ids", function()
    local tile_sync = require("src.ui.render.board.visual_sync_tile")
    local handled
    _with_patches({
      { target = tile_sync, key = "sync_tile_visual", value = function() return true end },
    }, function()
      handled = visual_sync.sync_many({}, { tile_ids = { 1 } })
    end)
    _assert_eq(handled, true, "an explicit tile id that syncs should make sync_many report handled")
  end)

  it("sync_many dedupes overlay indices before syncing", function()
    local overlay_sync = require("src.ui.render.board.visual_sync_overlay")
    local calls = {}
    _with_patches({
      {
        target = overlay_sync,
        key = "sync_overlay_visual",
        value = function(_state, idx)
          calls[#calls + 1] = idx
          return true
        end,
      },
    }, function()
      visual_sync.sync_many({}, { overlay_indices = { 1, 1 } })
    end)
    _assert_eq(#calls, 1, "duplicate overlay indices should be normalized to a single sync")
  end)

  it("sync_many surfaces no expanded tiles when the board path is not a table", function()
    local state = { game = { board = { path = nil } } }
    local handled = visual_sync.sync_many(state, { affected_owner_ids = { 10 } })
    _assert_eq(handled, false, "a non-table board path should short-circuit owner expansion")
  end)
end)
