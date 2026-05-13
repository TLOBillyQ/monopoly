local action_selector = require("src.computer.agent.action")
local item_ids = require("src.config.gameplay.item_ids")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_player(id, opts)
  opts = opts or {}
  return {
    id = id,
    eliminated = opts.eliminated or false,
    position = opts.position or 1,
  }
end

local function _make_game(players, opts)
  opts = opts or {}
  local balances = opts.balances or {}
  local deity_flags = opts.deity_flags or {}
  local g = { players = players }
  function g:player_balance(p, _)
    return balances[p.id] or 0
  end
  function g:player_has_deity(p, deity_type)
    local flags = deity_flags[p.id] or {}
    return flags[deity_type] == true
  end
  return g
end

-- pick_target_player: unknown item_id returns nil


-- share_wealth: player is not richest → returns richest other


-- share_wealth: player is richest → returns nil


-- exile: returns richest other


-- tax: returns richest other


-- poor: returns richest other


-- exile: skips eliminated player


-- exile with options (allow_ids filter)


-- invite_deity: prefers player with angel deity


-- invite_deity: falls back to rich when no angel


-- invite_deity: no deity targets → returns nil


-- send_poor: player has poor deity → returns richest other


-- send_poor: player does not have poor deity → returns nil


-- _richest_other: no eligible others → returns nil

describe("domain action selector coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("pick_target unknown item returns nil", function()
    local player = _make_player("p1")
    local game = _make_game({ player })
    local result = action_selector.pick_target_player(game, player, 9999, nil)
    _assert_eq(result, nil, "unknown item_id should return nil")
  end)

  it("pick_target share_wealth not richest returns richest other", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, { balances = { p1 = 50, p2 = 200 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.share_wealth, nil)
    _assert_eq(result, p2, "should return richest other player")
  end)

  it("pick_target share_wealth is richest returns nil", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, { balances = { p1 = 500, p2 = 100 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.share_wealth, nil)
    _assert_eq(result, nil, "richest player should return nil for share_wealth")
  end)

  it("pick_target exile returns richest other", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local p3 = _make_player("p3")
    local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 100, p2 = 50, p3 = 300 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
    _assert_eq(result, p3, "exile should target richest other")
  end)

  it("pick_target tax returns richest other", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, { balances = { p1 = 10, p2 = 999 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.tax, nil)
    _assert_eq(result, p2, "tax should target richest other")
  end)

  it("pick_target poor returns richest other", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, { balances = { p1 = 10, p2 = 500 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.poor, nil)
    _assert_eq(result, p2, "poor should target richest other")
  end)

  it("pick_target exile skips eliminated", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2", { eliminated = true })
    local p3 = _make_player("p3")
    local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 10, p2 = 9999, p3 = 100 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
    _assert_eq(result, p3, "should skip eliminated players")
  end)

  it("pick_target exile respects options filter", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local p3 = _make_player("p3")
    local game = _make_game({ p1, p2, p3 }, { balances = { p1 = 10, p2 = 999, p3 = 50 } })
    -- only p3 is in options
    local options = { { id = "p3" } }
    local result = action_selector.pick_target_player(game, p1, item_ids.exile, options)
    _assert_eq(result, p3, "options filter should restrict targets to p3 only")
  end)

  it("pick_target invite_deity prefers angel", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local p3 = _make_player("p3")
    local game = _make_game({ p1, p2, p3 }, {
      deity_flags = { p2 = { rich = true }, p3 = { angel = true } },
    })
    local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
    _assert_eq(result, p3, "invite_deity should prefer angel over rich")
  end)

  it("pick_target invite_deity falls back to rich", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, {
      deity_flags = { p2 = { rich = true } },
    })
    local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
    _assert_eq(result, p2, "invite_deity should fall back to rich player")
  end)

  it("pick_target invite_deity no targets returns nil", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, { deity_flags = {} })
    local result = action_selector.pick_target_player(game, p1, item_ids.invite_deity, nil)
    _assert_eq(result, nil, "no deity targets should return nil")
  end)

  it("pick_target send_poor player has poor returns richest", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, {
      balances = { p1 = 10, p2 = 800 },
      deity_flags = { p1 = { poor = true } },
    })
    local result = action_selector.pick_target_player(game, p1, item_ids.send_poor, nil)
    _assert_eq(result, p2, "send_poor with poor deity should target richest other")
  end)

  it("pick_target send_poor no poor deity returns nil", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2")
    local game = _make_game({ p1, p2 }, {
      balances = { p1 = 10, p2 = 800 },
      deity_flags = {},
    })
    local result = action_selector.pick_target_player(game, p1, item_ids.send_poor, nil)
    _assert_eq(result, nil, "send_poor without poor deity should return nil")
  end)

  it("richest_other no eligible others returns nil", function()
    local p1 = _make_player("p1")
    local p2 = _make_player("p2", { eliminated = true })
    local game = _make_game({ p1, p2 }, { balances = { p1 = 100, p2 = 999 } })
    local result = action_selector.pick_target_player(game, p1, item_ids.exile, nil)
    _assert_eq(result, nil, "all others eliminated should return nil")
  end)
end)
