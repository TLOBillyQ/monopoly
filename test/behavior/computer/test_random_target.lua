require("test.bootstrap").install_package_paths()
-- busted injects luassert fields on assert.
-- luacheck: ignore 143
local luassert = assert
local agent = require("src.computer.agent")
local item_ids = require("src.config.gameplay.item_ids")

-- #101：偷窃与导弹在合法目标中经共享 game.rng 均匀随机，名单顺序不再决定集火对象。

local function _make_inventory(count)
  return { count = function() return count end }
end

local function _make_player(id, opts)
  opts = opts or {}
  return {
    id = id,
    eliminated = opts.eliminated or false,
    inventory = opts.inventory or _make_inventory(1),
  }
end

-- 循环 RNG：依次返回 min..max，再从 min 重来；n 次调用恰好覆盖 [min, max] 各一次。
local function _cycling_rng()
  local rng = { calls = {} }
  local cursor = 0
  function rng:next_int(min, max)
    self.calls[#self.calls + 1] = { min, max }
    local value = min + cursor % (max - min + 1)
    cursor = cursor + 1
    return value
  end
  return rng
end

local function _make_game(players, opts)
  opts = opts or {}
  local balances = opts.balances or {}
  local g = { players = players, rng = opts.rng or _cycling_rng() }
  function g:player_cash(p) return balances[p.id] or 0 end
  function g:player_has_deity() return false end
  return g
end

local function _tally(game, actor, item_id, options, rounds)
  local counts = {}
  for _ = 1, rounds do
    local target = agent.pick_target_player(game, actor, item_id, options)
    local key = target and target.id or "nil"
    counts[key] = (counts[key] or 0) + 1
  end
  return counts
end

local function test_steal_spreads_evenly_over_holders()
  local ai = _make_player("ai")
  local game = _make_game({ _make_player("human"), ai, _make_player("p3"), _make_player("p4") })
  local counts = _tally(game, ai, item_ids.steal, nil, 30)
  luassert.is.same({ human = 10, p3 = 10, p4 = 10 }, counts)
end

local function test_missile_spreads_evenly_over_targetable()
  local ai = _make_player("ai")
  local game = _make_game({ ai, _make_player("human"), _make_player("p3") })
  local counts = _tally(game, ai, item_ids.missile, nil, 20)
  luassert.is.same({ human = 10, p3 = 10 }, counts)
end

local function test_swap_roster_order_keeps_even_distribution()
  local ai = _make_player("ai")
  local forward = _make_game({ _make_player("human"), ai, _make_player("p3") })
  local swapped = _make_game({ _make_player("p3"), ai, _make_player("human") })
  luassert.is.same(
    _tally(forward, ai, item_ids.steal, nil, 20),
    _tally(swapped, ai, item_ids.steal, nil, 20)
  )
end

local function test_angel_protected_player_never_targeted()
  -- 天使保护在上游 target_candidates 已过滤，这里经 options 复现该过滤结果。
  local ai = _make_player("ai")
  local game = _make_game({ _make_player("human"), ai, _make_player("angel_blessed") })
  local options = { { id = "human" } } -- 受保护者不在候选内
  local counts = _tally(game, ai, item_ids.missile, options, 10)
  luassert.is.same({ human = 10 }, counts)
end

local function test_eliminated_player_never_targeted()
  local ai = _make_player("ai")
  local game = _make_game({ _make_player("human", { eliminated = true }), ai, _make_player("p3") })
  local counts = _tally(game, ai, item_ids.steal, nil, 10)
  luassert.is.same({ p3 = 10 }, counts)
end

local function test_player_without_items_never_stolen()
  local ai = _make_player("ai")
  local game = _make_game({
    _make_player("human", { inventory = _make_inventory(0) }),
    ai,
    _make_player("p3"),
  })
  local counts = _tally(game, ai, item_ids.steal, nil, 10)
  luassert.is.same({ p3 = 10 }, counts)
end

local function test_rng_called_with_full_candidate_range()
  local ai = _make_player("ai")
  local rng = _cycling_rng()
  local game = _make_game({ _make_player("human"), ai, _make_player("p3") }, { rng = rng })
  agent.pick_target_player(game, ai, item_ids.missile, nil)
  luassert.is.same({ { 1, 2 } }, rng.calls)
end

local function test_no_legal_target_returns_nil()
  local ai = _make_player("ai")
  local game = _make_game({ ai, _make_player("human", { inventory = _make_inventory(0) }) })
  luassert.is_nil(agent.pick_target_player(game, ai, item_ids.steal, nil))
end

describe("TestRandomTarget", function()
  it("test_steal_spreads_evenly_over_holders", test_steal_spreads_evenly_over_holders)
  it("test_missile_spreads_evenly_over_targetable", test_missile_spreads_evenly_over_targetable)
  it("test_swap_roster_order_keeps_even_distribution", test_swap_roster_order_keeps_even_distribution)
  it("test_angel_protected_player_never_targeted", test_angel_protected_player_never_targeted)
  it("test_eliminated_player_never_targeted", test_eliminated_player_never_targeted)
  it("test_player_without_items_never_stolen", test_player_without_items_never_stolen)
  it("test_rng_called_with_full_candidate_range", test_rng_called_with_full_candidate_range)
  it("test_no_legal_target_returns_nil", test_no_legal_target_returns_nil)
end)
