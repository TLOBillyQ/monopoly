local lu = require("luaunit")
local path_planner = require("src.computer.agent.path")

local function _assert_eq(actual, expected, message)
  lu.assertEvalToTrue(actual == expected, string.format("%s: expected %s got %s", tostring(message), tostring(expected), tostring(actual)))
end

local function _require_upvalue(fn, expected_name)
  lu.assertEvalToTrue(debug and type(debug.getupvalue) == "function", "debug.getupvalue should be available for characterization tests")
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    lu.assertEvalToTrue(name ~= nil, "missing upvalue: " .. tostring(expected_name))
    if name == expected_name then
      return value
    end
    index = index + 1
  end
end

local function _remote_priority()
  return _require_upvalue(path_planner.pick_remote_dice_value, "_remote_priority")
end

local function _call_remote_priority(player, tile_ref, steps)
  return _remote_priority()({}, player or { id = 7 }, {
    tile = tile_ref,
    steps = steps,
  })
end

TestRemotePriority = {}

do
  local _config_reset = require("test.support.config_reset")
  function TestRemotePriority:setUp()
    _config_reset.reset_all()
  end
end

function TestRemotePriority:test_remote_priority_returns_nil_for_missing_tile()
  local rank, score = _call_remote_priority({ id = 7 }, nil, 3)
  _assert_eq(rank, nil, "missing tile should not produce rank")
  _assert_eq(score, nil, "missing tile should not produce score")
end

function TestRemotePriority:test_remote_priority_ranks_item_tile()
  local rank, score = _call_remote_priority({ id = 7 }, { type = "item" }, 2)
  _assert_eq(rank, 1, "item tile should keep item rank")
  _assert_eq(score, 2, "item tile should keep step score")
end

function TestRemotePriority:test_remote_priority_ranks_chance_tile()
  local rank, score = _call_remote_priority({ id = 7 }, { type = "chance" }, 3)
  _assert_eq(rank, 2, "chance tile should keep chance rank")
  _assert_eq(score, 3, "chance tile should keep step score")
end

function TestRemotePriority:test_remote_priority_ranks_empty_land_tile()
  local rank, score = _call_remote_priority({ id = 7 }, {
    type = "land",
    owner_id = nil,
    level = 0,
    rents = { 80 },
  }, 4)
  _assert_eq(rank, 3, "unowned land should keep empty-land rank")
  _assert_eq(score, 4, "unowned land should keep step score")
end

function TestRemotePriority:test_remote_priority_ranks_self_owned_land_tile()
  local player = { id = 7 }
  local rank, score = _call_remote_priority(player, {
    type = "land",
    owner_id = player.id,
    level = 1,
    rents = { 80, 160 },
  }, 5)
  _assert_eq(rank, 4, "self-owned land should keep self-owned rank")
  _assert_eq(score, 5, "self-owned land should keep step score")
end

function TestRemotePriority:test_remote_priority_ranks_enemy_owned_land_tile()
  local rank, score = _call_remote_priority({ id = 7 }, {
    type = "land",
    owner_id = 2,
    level = 1,
    rents = { 120, 300 },
  }, 4)
  _assert_eq(rank, 10, "enemy-owned land should keep enemy-land rank")
  _assert_eq(score, -300, "enemy-owned land should score negative rent")
end

function TestRemotePriority:test_remote_priority_ranks_market_tile()
  local rank, score = _call_remote_priority({ id = 7 }, { type = "market" }, 6)
  _assert_eq(rank, 6, "market tile should keep market rank")
  _assert_eq(score, 6, "market tile should keep step score")
end

-- 批3 击杀：线性棋盘构建器——tiles 按绝对下标给板子，走步每步 +1。
local function _flat_board(tiles)
  return {
    tiles = tiles,
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return false
    end,
    get_tile = function(_, index)
      return tiles[index]
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, nil, false
    end,
  }
end

local function _item_tile()
  return { type = "item" }
end

local function _unowned_land()
  return { type = "land", owner_id = nil, level = 0, rents = { 80 } }
end

-- 批3 击杀 L122(or->and 崩) / L132(or->and 分数全变 0) / L140(两处 or 兜底)：
-- 不传 dice_count 走默认 1，item 板子上步数即分数，实码应选最大步数 6；
-- L122/L140-or 变异在 best==nil 或 dice_count==nil 时直接崩。
function TestRemotePriority:test_pick_remote_dice_value_defaults_to_single_dice()
  local tiles = {}
  for index = 0, 6 do
    tiles[index] = _item_tile()
  end
  local board = _flat_board(tiles)
  local ok, value, tile_ref = pcall(path_planner.pick_remote_dice_value, { board = board }, { id = 7, position = 0 })
  lu.assertEvalToTrue(ok == true, "pick_remote_dice_value must tolerate a missing dice_count")
  _assert_eq(value, 6, "item tiles rank by step count; max steps should win")
  _assert_eq(tile_ref, tiles[6], "winning candidate should expose its tile")
end

-- 批3 击杀 L143(*->/)：dice_count=2 时步数翻倍，12 步位(item)应胜过 6 步内的
-- land；除法变异会产出小数步、让 0 步位(item)反胜。
function TestRemotePriority:test_pick_remote_dice_value_uses_dice_count_multiplier()
  local tiles = {}
  tiles[0] = _item_tile()
  for index = 1, 11 do
    tiles[index] = _unowned_land()
  end
  tiles[12] = _item_tile()
  local board = _flat_board(tiles)
  local value, tile_ref = path_planner.pick_remote_dice_value({ board = board }, { id = 7, position = 0 }, 2)
  _assert_eq(value, 6, "twelve-step item tile should beat the six-step lands")
  _assert_eq(tile_ref, tiles[12], "winning candidate should be the doubled-step item tile")
end

-- 批3 击杀 L142(1->0)：0 步候选不该参与竞争——0 位放 item 时实码必须仍选
-- 6 步的 land（rank 3 胜过 0 步 item 也无用？否——0 变异会让 0 位 item rank 1 反杀）。
-- 真实语义:for 从 1 起,最小骰值 1。
function TestRemotePriority:test_pick_remote_dice_value_never_considers_zero_dice_value()
  local tiles = {}
  tiles[0] = _item_tile()
  for index = 1, 6 do
    tiles[index] = _unowned_land()
  end
  local board = _flat_board(tiles)
  local value, tile_ref = path_planner.pick_remote_dice_value({ board = board }, { id = 7, position = 0 })
  _assert_eq(value, 6, "zero-step item tile must not win over ranked land candidates")
  _assert_eq(tile_ref, tiles[6], "the six-step land candidate should win")
end

-- 批3 击杀 L124(>->=)：同 rank 同 score 平局必须保留先到者(更小骰值)。
function TestRemotePriority:test_pick_remote_dice_value_tie_keeps_lower_value()
  local tiles = {}
  for index = 1, 6 do
    tiles[index] = { type = "land", owner_id = 2, level = 1, rents = { 120, 300 } }
  end
  local board = _flat_board(tiles)
  local value, tile_ref = path_planner.pick_remote_dice_value({ board = board }, { id = 7, position = 0 })
  _assert_eq(value, 1, "an equal-score tie must keep the earlier (lower) dice value")
  _assert_eq(tile_ref, tiles[1], "tie winner should be the first candidate's tile")
end

local function _simulate_landing()
  return _require_upvalue(path_planner.pick_remote_dice_value, "_simulate_landing")
end

function TestRemotePriority:test_simulate_landing_reads_tile_when_no_obstacle_interrupts()
  local board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return false
    end,
    get_tile = function(_, index)
      return { id = index, type = "land" }
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, 0, false
    end,
  }

  local sim = _simulate_landing()({ board = board }, { position = 0 }, 2)

  _assert_eq(sim.idx, 2, "simulation should advance by all steps without obstacles")
  _assert_eq(sim.tile.id, 2, "simulation should expose the final tile")
  _assert_eq(sim.steps, 2, "simulation should keep the requested step count")
end

function TestRemotePriority:test_simulate_landing_stops_on_a_mine_tile()
  local board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return true
    end,
    get_tile = function()
      return { type = "land" }
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, 0, false
    end,
  }

  local sim = _simulate_landing()({ board = board }, { position = 0 }, 3)

  _assert_eq(sim.idx, 1, "mine should stop the walk on the first step")
  _assert_eq(sim.steps, 3, "simulation should keep the requested step count")
end

-- 批3 击杀 L65：路障位必须停走。
function TestRemotePriority:test_simulate_landing_stops_on_a_roadblock_tile()
  local board = {
    has_roadblock = function(_, index)
      return index == 1
    end,
    has_mine = function()
      return false
    end,
    get_tile = function()
      return { type = "land" }
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, 0, false
    end,
  }

  local sim = _simulate_landing()({ board = board }, { position = 0 }, 3)

  _assert_eq(sim.idx, 1, "roadblock should stop the walk on the first step")
end

-- 批3 击杀 L71 两处：market 位且非末步必须停走；无 type 的瓷砖则必须继续走。
function TestRemotePriority:test_simulate_landing_stops_on_market_only_before_the_final_step()
  local board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return false
    end,
    get_tile = function(_, index)
      if index == 1 then
        return { type = "market" }
      end
      return { type = "land" }
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, 0, false
    end,
  }

  local sim = _simulate_landing()({ board = board }, { position = 0 }, 3)
  _assert_eq(sim.idx, 1, "market before the final step should stop the walk")

  local type_less_board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return false
    end,
    get_tile = function(_, index)
      if index == 1 then
        return {} -- 无 type 的瓷砖不是 market
      end
      return { type = "land" }
    end,
    step_forward_by_facing = function(_, current)
      return current + 1, nil, 0, false
    end,
  }
  local walked = _simulate_landing()({ board = type_less_board }, { position = 0 }, 3)
  _assert_eq(walked.idx, 3, "a type-less tile must not interrupt the walk")
end

-- 批3 击杀 L78/L87：entered_inner 首步必须 false（初始值），跨步后保持置位。
function TestRemotePriority:test_simulate_landing_forwards_entered_inner_progress()
  local received = {}
  local board = {
    has_roadblock = function()
      return false
    end,
    has_mine = function()
      return false
    end,
    get_tile = function()
      return { type = "land" }
    end,
    step_forward_by_facing = function(_, current, _, opts)
      received[#received + 1] = opts and opts.entered_inner
      return current + 1, nil, 0, current == 0
    end,
  }

  _simulate_landing()({ board = board }, { position = 0 }, 3)

  _assert_eq(received[1], false, "the first step must start with entered_inner cleared")
  _assert_eq(received[2], true, "a step that entered inner must latch entered_inner for later steps")
  _assert_eq(received[3], true, "the latched entered_inner must persist")
end

-- 批3 击杀 L16：敌方地块缺 level 时按 0 级收租（or 0 兜底），不能按 1 级收。
function TestRemotePriority:test_enemy_land_without_level_rents_at_zero()
  local rank, score = _call_remote_priority({ id = 7 }, {
    type = "land",
    owner_id = 2,
    rents = { 120, 300 },
  }, 4)
  _assert_eq(rank, 10, "enemy-owned land should keep enemy-land rank")
  _assert_eq(score, -120, "a missing level should rent at level zero")
end


return TestRemotePriority
