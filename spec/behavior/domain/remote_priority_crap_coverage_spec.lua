local path_planner = require("src.computer.agent.path")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, string.format("%s: expected %s got %s", tostring(message), tostring(expected), tostring(actual)))
end

local function _require_upvalue(fn, expected_name)
  assert(debug and type(debug.getupvalue) == "function", "debug.getupvalue should be available for characterization tests")
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    assert(name ~= nil, "missing upvalue: " .. tostring(expected_name))
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

describe("remote_priority_crap_coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("remote_priority_returns_nil_for_missing_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, nil, 3)
    _assert_eq(rank, nil, "missing tile should not produce rank")
    _assert_eq(score, nil, "missing tile should not produce score")
  end)

  it("remote_priority_ranks_item_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, { type = "item" }, 2)
    _assert_eq(rank, 1, "item tile should keep item rank")
    _assert_eq(score, 2, "item tile should keep step score")
  end)

  it("remote_priority_ranks_chance_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, { type = "chance" }, 3)
    _assert_eq(rank, 2, "chance tile should keep chance rank")
    _assert_eq(score, 3, "chance tile should keep step score")
  end)

  it("remote_priority_ranks_empty_land_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, {
      type = "land",
      owner_id = nil,
      level = 0,
      rents = { 80 },
    }, 4)
    _assert_eq(rank, 3, "unowned land should keep empty-land rank")
    _assert_eq(score, 4, "unowned land should keep step score")
  end)

  it("remote_priority_ranks_self_owned_land_tile", function()
    local player = { id = 7 }
    local rank, score = _call_remote_priority(player, {
      type = "land",
      owner_id = player.id,
      level = 1,
      rents = { 80, 160 },
    }, 5)
    _assert_eq(rank, 4, "self-owned land should keep self-owned rank")
    _assert_eq(score, 5, "self-owned land should keep step score")
  end)

  it("remote_priority_ranks_enemy_owned_land_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, {
      type = "land",
      owner_id = 2,
      level = 1,
      rents = { 120, 300 },
    }, 4)
    _assert_eq(rank, 10, "enemy-owned land should keep enemy-land rank")
    _assert_eq(score, -300, "enemy-owned land should score negative rent")
  end)

  it("remote_priority_ranks_market_tile", function()
    local rank, score = _call_remote_priority({ id = 7 }, { type = "market" }, 6)
    _assert_eq(rank, 6, "market tile should keep market rank")
    _assert_eq(score, 6, "market tile should keep step score")
  end)
end)
