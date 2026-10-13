require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local land_adjacency = require("src.state.land_adjacency")

-- land_adjacency 是 board.land_neighbors 的唯一构建者,rules(租金)与 ui(连片数)共读同一份投影。
-- 因此这里钉住的是投影本身的契约：键与值都只含 land id;冷启时的完整性前置检查只对 land 生效。
local function _make_board(tiles, neighbors)
  local by_id = {}
  for _, t in ipairs(tiles) do
    by_id[t.id] = t
  end
  return {
    map = neighbors and { neighbors = neighbors } or nil,
    path = tiles,
    get_tile_by_id = function(_, id)
      return by_id[id]
    end,
  }
end

local function _land(id)
  return { id = id, type = "land" }
end

describe("TestLandAdjacency", function()

  it("test_keys_the_projection_by_land_tile_id_and_skips_non_land_path_tiles", function()
    local shop = { id = 2, type = "toolshop" }
    local board = _make_board({ _land(1), shop }, { [1] = { 2 } })

    local adjacency = land_adjacency.ensure(board)

    -- 非 land 的 path 地块不该获得邻接槽(否则 `tile and ...` 退化成 `tile or ...`)。
    luassert.is_nil(adjacency[2])
    luassert.is_not_nil(adjacency[1])
  end)

  it("test_drops_neighbor_ids_that_do_not_resolve_to_a_land_tile", function()
    local shop = { id = 2, type = "toolshop" }
    local board = _make_board({ _land(1), shop }, { [1] = { 2, 99 } })

    -- 邻居里的商店(2)与无对应地块的 id(99)都必须被过滤掉。
    luassert.is.same({}, land_adjacency.ensure(board)[1])
  end)

  it("test_caches_the_projection_on_the_board_and_reuses_it", function()
    local board = _make_board({ _land(1) }, { [1] = {} })

    local first = land_adjacency.ensure(board)
    luassert.is.equal(first, board.land_neighbors)
    luassert.is.equal(first, land_adjacency.ensure(board))
  end)

  it("test_degrades_to_an_empty_projection_when_the_view_seam_carries_no_map", function()
    local board = _make_board({ _land(1) }, nil)

    luassert.is.same({}, land_adjacency.ensure(board))
    -- 退化路径不该把空表写回 board,否则真正的棋盘缓存会被污染。
    luassert.is_nil(board.land_neighbors)
  end)

  it("test_requires_a_complete_board_a_land_tile_missing_its_neighbors_entry_throws", function()
    local board = _make_board({ _land(1), _land(2) }, { [1] = {} }) -- 地块 2 没有邻居条目

    luassert.has_error(function()
      land_adjacency.ensure_complete(board)
    end, "missing neighbors: 2")
  end)

  it("test_requires_a_complete_board_a_missing_neighbors_map_throws", function()
    local board = _make_board({ _land(1) }, nil)

    luassert.has_error(function()
      land_adjacency.ensure_complete(board)
    end, "missing board.map.neighbors")
  end)

  it("test_ignores_non_land_tiles_when_checking_completeness", function()
    local shop = { id = 2, type = "toolshop" }
    -- 只有 land(1) 有邻居条目;商店缺条目不该触发完整性断言。
    local board = _make_board({ _land(1), shop }, { [1] = {} })

    luassert.is.same({}, land_adjacency.ensure_complete(board)[1])
  end)


end)
