require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local land_component = require("src.state.land_component")

-- land_component 是「同主连片」的唯一走法,rules(连片租金)与 ui(连片数)共用。
-- 这里钉住的是走法本身的契约：只收编同主地块、沿邻接可达、每块地只走一次;
-- 邻接的严格程度(缺邻居是断言还是退化)属于调用方接缝,不在这里定。
local function _walk(owners, neighbors, start_tile_id, owner_id)
  return land_component.same_owner(start_tile_id, owner_id, function(tile_id)
    return owners[tile_id]
  end, function(tile_id)
    return neighbors[tile_id] or {}
  end)
end

describe("TestLandComponent", function()

  it("test_collects_the_whole_connected_run_of_same_owner_tiles", function()
    local owners = { [1] = "a", [2] = "a", [3] = "a" }
    local neighbors = { [1] = { 2 }, [2] = { 1, 3 }, [3] = { 2 } }

    luassert.is.same({ 1, 2, 3 }, _walk(owners, neighbors, 1, "a"))
  end)

  it("test_stops_at_a_tile_owned_by_someone_else_and_does_not_walk_past_it", function()
    -- 3 与 1 同主,但只能经过别人的 2 才能到达 —— 连片在 2 处断开。
    local owners = { [1] = "a", [2] = "b", [3] = "a" }
    local neighbors = { [1] = { 2 }, [2] = { 1, 3 }, [3] = { 2 } }

    luassert.is.same({ 1 }, _walk(owners, neighbors, 1, "a"))
  end)

  it("test_returns_an_empty_component_when_the_start_tile_is_not_owned_by_owner_id", function()
    local owners = { [1] = "b", [2] = "a" }
    local neighbors = { [1] = { 2 }, [2] = { 1 } }

    luassert.is.same({}, _walk(owners, neighbors, 1, "a"))
  end)

  it("test_visits_each_tile_once_in_a_cyclic_graph", function()
    -- 环形邻接：没有 visited 记账就会重复收编甚至走不完。
    local owners = { [1] = "a", [2] = "a", [3] = "a" }
    local neighbors = { [1] = { 2, 3 }, [2] = { 1, 3 }, [3] = { 1, 2 } }

    local component = _walk(owners, neighbors, 1, "a")

    table.sort(component)
    luassert.is.same({ 1, 2, 3 }, component)
  end)

  it("test_asks_each_visited_tile_for_its_owner_exactly_once", function()
    local owners = { [1] = "a", [2] = "a" }
    local neighbors = { [1] = { 2, 2 }, [2] = { 1 } } -- 重复邻居也不该被重复入队
    local calls = {}

    land_component.same_owner(1, "a", function(tile_id)
      calls[tile_id] = (calls[tile_id] or 0) + 1
      return owners[tile_id]
    end, function(tile_id)
      return neighbors[tile_id] or {}
    end)

    luassert.is.same({ [1] = 1, [2] = 1 }, calls)
  end)

  it("test_treats_a_tile_with_no_neighbors_entry_as_an_island", function()
    local owners = { [1] = "a", [2] = "a" }

    luassert.is.same({ 1 }, _walk(owners, {}, 1, "a"))
  end)


end)
