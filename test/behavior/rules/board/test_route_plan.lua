require("test.bootstrap").install_package_paths()
local luassert = require("luassert")
local support = require("test.support.shared_support")
local default_map = require("src.config.content.default_map")
local direction = require("src.rules.board.direction")
local route_plan = require("src.rules.board.route_plan")

local function _assert_eq(a, b, msg) luassert.is.equal(b, a, msg) end

local function _new_board()
  return support.new_game({ map = default_map }).board
end

-- 从 seat 沿外环正向走 roll 步（branch parity = roll，同回合机），返回逐步途经的
-- tile id 列表。规约只靠真实棋步模拟验证计划，不自带任何 parity 知识。
local function _walk(board, seat_id, roll)
  local map = board.map
  local current = board:index_of_tile_id(seat_id)
  local facing = map.direction(seat_id, map.outer_next[seat_id])
  local entered_inner = false
  local visited = {}
  for _ = 1, roll do
    local next_index, _, next_facing, step_entered_inner = board:step_forward_by_facing(current, facing, {
      parity = roll,
      entered_inner = entered_inner,
    })
    if step_entered_inner then
      entered_inner = true
    end
    current = next_index
    facing = next_facing
    visited[#visited + 1] = board:get_tile(current).id
  end
  return visited
end

-- 合成直链地图：e1 拐入后 i1 → i2 → i3 终止，外环 e1 ← o1 ← o2 ← o3。
-- 链在目标之后仍有延伸,钉住「到达目标即停」的步数语义。
local function _straight_chain_map()
  return {
    entry_points = { e1 = { inner_id = "i1" } },
    fresh_forward_next = { i1 = "i2", i2 = "i3" },
    outer_prev = { e1 = "o1", o1 = "o2", o2 = "o3" },
  }
end


describe("TestRoutePlan", function()
  it("test_plan_land_on：按计划落座掷骰恰好停在黑市", function()
    local board = _new_board()
    local map = board.map
    local plan = route_plan.plan_land_on(map, map.market_id)
    luassert.is_not_nil(plan, "plan should exist for the default map")
    luassert.is_not_nil(map.entry_points[plan.entry_id], "planned entry should be a real entry_point")
    luassert.is_true(plan.back >= 1, "seat should sit at least one step before the entry")
    local visited = _walk(board, plan.seat_id, plan.roll)
    _assert_eq(visited[#visited], map.market_id, "final step should land on the market")
  end)

  it("test_plan_pass_through：按计划落座掷骰途经黑市且至少剩一步", function()
    local board = _new_board()
    local map = board.map
    local plan = route_plan.plan_pass_through(map, map.market_id)
    luassert.is_not_nil(plan, "plan should exist for the default map")
    local visited = _walk(board, plan.seat_id, plan.roll)
    local market_step = nil
    for step, tile_id in ipairs(visited) do
      if tile_id == map.market_id then
        market_step = step
      end
    end
    luassert.is_not_nil(market_step, "walk should pass through the market")
    luassert.is_true(market_step < #visited, "market must not be the final step")
  end)

  it("test_plan_land_on：内圈链走到尽头仍未及目标时报错（断链地图）", function()
    -- 合成断链地图：入口拐入后 i1 → i2 即终止，目标不在链上，
    -- 覆盖 fresh_forward_next 走空的提前退出分支（默认地图内圈成环走不到）。
    local broken_map = {
      entry_points = { e1 = { inner_id = "i1" } },
      fresh_forward_next = { i1 = "i2" },
      outer_prev = {},
    }
    local plan, err = route_plan.plan_land_on(broken_map, "unreachable")
    luassert.is_nil(plan, "broken inner chain should yield no plan")
    luassert.is_not_nil(err, "broken inner chain should report an error")
  end)

  it("test_plan_land_on：目标不可经内圈到达时报错", function()
    local map = _new_board().map
    local plan, err = route_plan.plan_land_on(map, "no_such_tile")
    luassert.is_nil(plan, "unreachable target should yield no plan")
    luassert.is_not_nil(err, "unreachable target should report an error")
  end)

  it("test_plan_land_on：直链地图上产出精确的 seat/back/roll", function()
    local plan = assert(route_plan.plan_land_on(_straight_chain_map(), "i2"))
    _assert_eq(plan.entry_id, "e1", "plan should pick the only entry")
    _assert_eq(plan.back, 2, "hops=2 needs back=2 for the smallest gate-legal roll")
    _assert_eq(plan.roll, 4, "roll should be back + hops")
    _assert_eq(plan.seat_id, "o2", "seat should sit back outer steps before the entry")
  end)

  it("test_plan_pass_through：直链地图上产出精确的 seat/roll/target_step", function()
    local plan = assert(route_plan.plan_pass_through(_straight_chain_map(), "i2"))
    _assert_eq(plan.entry_id, "e1", "plan should pick the only entry")
    _assert_eq(plan.back, 1, "pass-through seats one step before the entry")
    _assert_eq(plan.target_step, 3, "target is reached at step back + hops")
    _assert_eq(plan.roll, 4, "roll should be the smallest gate-legal value beyond target_step")
    _assert_eq(plan.seat_id, "o1", "seat should sit one outer step before the entry")
  end)

  it("test_plan_pass_through：目标不可经内圈到达时报含目标名的错误", function()
    local plan, err = route_plan.plan_pass_through(_new_board().map, "no_such_tile")
    luassert.is_nil(plan, "unreachable target should yield no plan")
    luassert.is_not_nil(tostring(err):find("no entry_point routes to no_such_tile", 1, true), "error should name the unreachable target, got: " .. tostring(err))
  end)

  it("test_plan_land_on：外环长度不足以后退落座时报含入口名的错误", function()
    local short_map = {
      entry_points = { e1 = { inner_id = "i1" } },
      fresh_forward_next = { i1 = "i2" },
      outer_prev = {},
    }
    local plan, err = route_plan.plan_land_on(short_map, "i2")
    luassert.is_nil(plan, "too-short outer ring should yield no plan")
    luassert.is_not_nil(tostring(err):find("outer ring too short before entry e1", 1, true), "error should name the blocked entry, got: " .. tostring(err))
  end)

-- 门控谓词黑盒防御分支：谓词永假时窗口耗尽,报「无合法 roll」。
  it("test_门控谓词永假时报无合法 roll", function()
    local map = _straight_chain_map()
    support.with_patches({
      { target = direction, key = "parity_allows_inner", value = function() return false end },
    }, function()
      local land, land_err = route_plan.plan_land_on(map, "i2")
      luassert.is_nil(land, "all-false gate should yield no landing plan")
      luassert.is_not_nil(tostring(land_err):find("no legal roll lands on i2", 1, true), "landing error should name the target, got: " .. tostring(land_err))
      local pass, pass_err = route_plan.plan_pass_through(map, "i2")
      luassert.is_nil(pass, "all-false gate should yield no pass-through plan")
      luassert.is_not_nil(tostring(pass_err):find("no legal roll passes through i2", 1, true), "pass-through error should name the target, got: " .. tostring(pass_err))
    end)
  end)

  it("test_plan_pass_through：不允许以恰好停在目标上的 roll 冒充途经", function()
    -- target 在 hops=1（target_step=2，门控合法）:途经 roll 必须严格大于 target_step。
    local map = _straight_chain_map()
    local plan = assert(route_plan.plan_pass_through(map, "i1"))
    luassert.is_true(plan.roll > plan.target_step, "pass-through roll must overshoot the target step, got roll=" .. tostring(plan.roll))
    _assert_eq(plan.roll, 4, "smallest gate-legal roll beyond target_step=2 is 4")
  end)

  it("test_plan_land_on：内圈步数窗上限之外的目标不可规划", function()
    -- 链长恰好越过 MAX_INNER_HOPS=64:目标在第 65 步,必须判不可达而不是多走一步。
    local chain = { entry_points = { e1 = { inner_id = "i1" } }, outer_prev = { e1 = "o1" } }
    local fresh = {}
    for i = 1, 64 do
      fresh["i" .. i] = "i" .. (i + 1)
    end
    chain.fresh_forward_next = fresh
    local plan, err = route_plan.plan_land_on(chain, "i65")
    luassert.is_nil(plan, "target beyond the inner-hop window must not be plannable")
    luassert.is_not_nil(err, "window overflow should report an error")
  end)

  it("test_窗口保证：k=8 门控在最劣对齐下仍能规划", function()
    -- 链长 8,land 的候选 roll 为 9..16:合法 roll(16)落在窗口最后一格,
    -- 钉住「8 个连续 roll」的窗口下限——任何缩窗都会在此失败。
    local chain = { entry_points = { e1 = { inner_id = "i1" } }, outer_prev = {} }
    local prev = "e1"
    for i = 1, 8 do
      chain.outer_prev[prev] = "o" .. i
      prev = "o" .. i
    end
    local fresh = {}
    for i = 1, 7 do
      fresh["i" .. i] = "i" .. (i + 1)
    end
    chain.fresh_forward_next = fresh
    support.with_patches({
      { target = direction, key = "parity_allows_inner", value = function(roll) return roll % 8 == 0 end },
    }, function()
      local land = assert(route_plan.plan_land_on(chain, "i8"))
      _assert_eq(land.roll, 16, "worst-aligned mod-8 gate should be found at the window edge")
      local pass = assert(route_plan.plan_pass_through(chain, "i7"))
      _assert_eq(pass.roll, 16, "pass-through worst-aligned mod-8 gate should be found at the window edge")
    end)
  end)

-- 契约钉：内圈入口门控的唯一权威是 direction.parity_allows_inner；
-- 规划器选 roll 必须与解析器同谓词。src 改门控时这里与解析器一起变，
-- 计划仍由上面的真实棋步模拟兜底验证。
  it("test_规划的 roll 满足解析器的入口门控谓词", function()
    local map = _new_board().map
    local land = route_plan.plan_land_on(map, map.market_id)
    local pass = route_plan.plan_pass_through(map, map.market_id)
    luassert.is.same(true, direction.parity_allows_inner(land.roll), "land roll should pass the entry gate")
    luassert.is.same(true, direction.parity_allows_inner(pass.roll), "pass roll should pass the entry gate")
  end)


end)
