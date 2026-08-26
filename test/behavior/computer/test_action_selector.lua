local lu = require("luaunit")
local action_selector = require("src.computer.agent.action")
local item_ids = require("src.config.gameplay.item_ids")
local roadblock = require("src.rules.items.roadblock")

-- 保存原函数引用:roadblock 桩恢复必须还原到源码函数本身,不能另建闭包。
local original_auto_candidates = roadblock.auto_candidates
local original_pick_best = roadblock.pick_best

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_player(id, opts)
  opts = opts or {}
  return {
    id = id,
    eliminated = opts.eliminated or false,
    position = opts.position or 1,
    inventory = opts.inventory,
  }
end

local function _make_inventory(count)
  return {
    count = function()
      return count
    end,
  }
end

local function _make_game(players, opts)
  opts = opts or {}
  local balances = opts.balances or {}
  local deity_flags = opts.deity_flags or {}
  local g = { players = players }
  function g:player_cash(p)
    return balances[p.id] or 0
  end
  function g:player_has_deity(p, deity_type)
    local flags = deity_flags[p.id] or {}
    return flags[deity_type] == true
  end
  return g
end

TestActionSelector = {}

do
  local _config_reset = require("test.support.config_reset")
  function TestActionSelector:setUp()
    _config_reset.reset_all()
  end

  function TestActionSelector:tearDown()
    roadblock.auto_candidates = original_auto_candidates
    roadblock.pick_best = original_pick_best
  end
end

function TestActionSelector:test_pick_target_unknown_item_returns_nil()
  local player = _make_player("p1")
  local game = _make_game({ player })
  local result = action_selector.pick_target_player(game, player, 9999, nil)
  _assert_eq(result, nil, "unknown item_id should return nil")
end

function TestActionSelector:test_pick_target_share_wealth_not_richest_returns_richest_other()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { balances = { p1 = 50, p2 = 200 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.share_wealth, nil)
  _assert_eq(result, p2, "should return richest other player")
end

function TestActionSelector:test_pick_target_share_wealth_is_richest_returns_nil()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { balances = { p1 = 500, p2 = 100 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.share_wealth, nil)
  _assert_eq(result, nil, "richest player should return nil for share_wealth")
end

function TestActionSelector:test_pick_target_exile_returns_richest_other()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 100, p2 = 50, p3 = 300 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
  _assert_eq(result, p3, "exile should target richest other")
end

function TestActionSelector:test_pick_target_tax_returns_richest_other()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { balances = { p1 = 10, p2 = 999 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.tax, nil)
  _assert_eq(result, p2, "tax should target richest other")
end

function TestActionSelector:test_pick_target_poor_returns_richest_other()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { balances = { p1 = 10, p2 = 500 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.poor, nil)
  _assert_eq(result, p2, "poor should target richest other")
end

function TestActionSelector:test_pick_target_exile_skips_eliminated()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2", { eliminated = true })
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 10, p2 = 9999, p3 = 100 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
  _assert_eq(result, p3, "should skip eliminated players")
end

function TestActionSelector:test_pick_target_exile_respects_options_filter()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 10, p2 = 999, p3 = 50 } })
  -- only p3 is in options
  local options = { { id = "p3" } }
  local result = action_selector.pick_target_player(game, p1, item_ids.exile, options)
  _assert_eq(result, p3, "options filter should restrict targets to p3 only")
end

function TestActionSelector:test_pick_target_invite_deity_prefers_angel()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 }, {
    deity_flags = { p2 = { rich = true }, p3 = { angel = true } },
  })
  local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
  _assert_eq(result, p3, "invite_deity should prefer angel over rich")
end

function TestActionSelector:test_pick_target_invite_deity_falls_back_to_rich()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, {
    deity_flags = { p2 = { rich = true } },
  })
  local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
  _assert_eq(result, p2, "invite_deity should fall back to rich player")
end

function TestActionSelector:test_pick_target_invite_deity_no_targets_returns_nil()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { deity_flags = {} })
  local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
  _assert_eq(result, nil, "no deity targets should return nil")
end

function TestActionSelector:test_pick_target_send_poor_player_has_poor_returns_richest()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, {
    balances = { p1 = 10, p2 = 800 },
    deity_flags = { p1 = { poor = true } },
  })
  local result = action_selector.pick_target_player(game, p1, item_ids.send_poor, nil)
  _assert_eq(result, p2, "send_poor with poor deity should target richest other")
end

function TestActionSelector:test_pick_target_send_poor_no_poor_deity_returns_nil()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, {
    balances = { p1 = 10, p2 = 800 },
    deity_flags = {},
  })
  local result = action_selector.pick_target_player(game, p1, item_ids.send_poor, nil)
  _assert_eq(result, nil, "send_poor without poor deity should return nil")
end

function TestActionSelector:test_richest_other_no_eligible_others_returns_nil()
  local p1 = _make_player("p1")
  local p2 = _make_player("p2", { eliminated = true })
  local game = _make_game({ p1, p2 }, { balances = { p1 = 100, p2 = 999 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
  _assert_eq(result, nil, "all others eliminated should return nil")
end

function TestActionSelector:test_pick_target_exile_tie_prefers_earlier_player()
  -- L16 `cash > best_cash` -> `>=`:并列现金时变异体换成后到的玩家,
  -- 原实现保持先遇到的玩家。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 10, p2 = 100, p3 = 100 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
  _assert_eq(result, p2, "tie cash should keep the earlier player as richest other")
end

function TestActionSelector:test_pick_target_share_wealth_equal_cash_is_richest_returns_nil()
  -- L38 `game:player_cash(p) > player_cash` -> `>=`:平局时变异体把并列者当
  -- 更富,share_wealth 转向他人;原实现平局仍算自己最富,返回 nil。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local game = _make_game({ p1, p2 }, { balances = { p1 = 100, p2 = 100 } })
  local result = action_selector.pick_target_player(game, p1, item_ids.share_wealth, nil)
  _assert_eq(result, nil, "equal cash should still count as richest for share_wealth")
end

function TestActionSelector:test_pick_target_steal_prefers_first_player_with_nonempty_inventory()
  -- L87 `p.inventory:count() > 0` -> `>= 0`:空背包(0 件)不被偷,变异体
  -- 会把空背包玩家当目标。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2", { inventory = _make_inventory(0) })
  local p3 = _make_player("p3", { inventory = _make_inventory(1) })
  local game = _make_game({ p1, p2, p3 })
  local result = action_selector.pick_target_player(game, p1, item_ids.steal, nil)
  _assert_eq(result, p3, "steal should skip the player with an empty inventory")
end

function TestActionSelector:test_pick_target_steal_skips_player_without_inventory()
  -- L87 `p.inventory ~= nil and ...` -> `or`:无背包玩家会被变异体求值
  -- `p.inventory:count()` 撞 nil 崩溃;原实现跳过无背包玩家。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3", { inventory = _make_inventory(1) })
  local game = _make_game({ p1, p2, p3 })
  local result = action_selector.pick_target_player(game, p1, item_ids.steal, nil)
  _assert_eq(result, p3, "steal should skip a player with no inventory at all")
end

function TestActionSelector:test_pick_target_missile_returns_first_targetable_other()
  -- L101 `_targetable(p, player, allowed)` -> nil:无目标返回 nil,导弹落空。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2")
  local p3 = _make_player("p3")
  local game = _make_game({ p1, p2, p3 })
  local result = action_selector.pick_target_player(game, p1, item_ids.missile, nil)
  _assert_eq(result, p2, "missile should hit the first targetable other player")
end

function TestActionSelector:test_pick_target_missile_skips_self_when_others_eliminated()
  -- L64 `p.id ~= player.id and not p.eliminated and ...` -> `or`:变异体把
  -- 自己当目标(missile 会炸自己),原实现仅剩淘汰他人时无目标。
  local p1 = _make_player("p1")
  local p2 = _make_player("p2", { eliminated = true })
  local game = _make_game({ p1, p2 })
  local result = action_selector.pick_target_player(game, p1, item_ids.missile, nil)
  _assert_eq(result, nil, "missile must not target self even when no other is alive")
end

function TestActionSelector:test_pick_roadblock_target_returns_best_candidate_idx()
  -- L132 `roadblock.auto_candidates(game, player, 3)` -> nil 与
  -- L136 `roadblock.pick_best(candidates)` -> nil:有候选时必须返回最优 idx。
  roadblock.auto_candidates = function()
    return { { idx = 5, priority = 1, step = 1 } }
  end
  local p1 = _make_player("p1")
  local game = _make_game({ p1 })
  local result = action_selector.pick_roadblock_target(game, p1)
  _assert_eq(result, 5, "roadblock should pick the best candidate idx")
end

function TestActionSelector:test_pick_roadblock_target_no_candidates_returns_nil()
  -- L133 `not candidates or #candidates == 0` 的 `not` 被删:候选为 nil 时
  -- 变异体求值 `#candidates` 撞 nil 崩溃;原实现返回 nil。
  roadblock.auto_candidates = function()
    return nil
  end
  local p1 = _make_player("p1")
  local game = _make_game({ p1 })
  local result = action_selector.pick_roadblock_target(game, p1)
  _assert_eq(result, nil, "no roadblock candidates should return nil")
end

function TestActionSelector:test_pick_roadblock_target_pick_best_nil_returns_nil()
  -- L137 `if not best then` 的 `not` 被删:pick_best 返回 nil 时变异体
  -- 落回 `best.idx` 撞 nil 崩溃;原实现返回 nil。
  roadblock.auto_candidates = function()
    return { { idx = 5, priority = 1, step = 1 } }
  end
  roadblock.pick_best = function()
    return nil
  end
  local p1 = _make_player("p1")
  local game = _make_game({ p1 })
  local result = action_selector.pick_roadblock_target(game, p1)
  _assert_eq(result, nil, "nil pick_best result should return nil")
end


return TestActionSelector
