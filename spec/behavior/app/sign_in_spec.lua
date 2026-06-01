local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local sign_in = require("src.app.host_integrations.sign_in")

local function _game()
  return {
    add_player_cash = function(_, player, amount)
      player.cash = (player.cash or 0) + amount
    end,
  }
end

describe("sign_in", function()
  it("grants_the_configured_reward_for_each_day", function()
    local expected = { 500, 1000, 2000, 4000, 6000, 8000, 10000 }
    for day, amount in ipairs(expected) do
      local game = _game()
      local player = { id = 1, cash = 0 }
      _assert_eq(sign_in.grant(game, player, day), true, "day " .. day .. " grant should succeed")
      _assert_eq(player.cash, amount, "day " .. day .. " should grant " .. amount .. " coins")
    end
  end)

  it("adds_reward_on_top_of_existing_cash", function()
    local game = _game()
    local player = { id = 1, cash = 1000 }
    sign_in.grant(game, player, 7)
    _assert_eq(player.cash, 11000, "day 7 reward should add to existing balance")
  end)

  it("does_not_grant_for_unconfigured_day", function()
    for _, day in ipairs({ 0, 8, 99 }) do
      local game = _game()
      local player = { id = 1, cash = 500 }
      _assert_eq(sign_in.grant(game, player, day), false, "unconfigured day " .. day .. " should not grant")
      _assert_eq(player.cash, 500, "unconfigured day " .. day .. " should leave cash unchanged")
    end
  end)

  it("rejects_grant_with_missing_arguments", function()
    local player = { id = 1, cash = 500 }
    _assert_eq(sign_in.grant(_game(), player, nil), false, "nil day should not grant")
    _assert_eq(sign_in.grant(nil, player, 1), false, "missing game should not grant")
    _assert_eq(sign_in.grant(_game(), nil, 1), false, "missing player should not grant")
    _assert_eq(player.cash, 500, "rejected grants should not change cash")
  end)

  it("parses_the_reward_day_from_host_event_names", function()
    _assert_eq(sign_in.day_from_event("RewardDay1"), 1, "RewardDay1 should map to day 1")
    _assert_eq(sign_in.day_from_event("RewardDay7"), 7, "RewardDay7 should map to day 7")
    _assert_eq(sign_in.day_from_event("RewardDay"), nil, "RewardDay with no number is not a reward event")
    _assert_eq(sign_in.day_from_event("RewardDayX"), nil, "non-numeric suffix is not a reward event")
    _assert_eq(sign_in.day_from_event("OtherEvent"), nil, "unrelated event names map to nil")
    _assert_eq(sign_in.day_from_event(nil), nil, "nil event name maps to nil")
  end)

  it("exposes_the_full_reward_table", function()
    _assert_eq(sign_in.amount_for_day(1), 500, "day 1 reward should be 500")
    _assert_eq(sign_in.amount_for_day(5), 6000, "day 5 reward should be 6000")
    _assert_eq(sign_in.amount_for_day(8), nil, "day 8 has no configured reward")
  end)

  it("claims_grant_the_day_reward_for_a_host_reward_event", function()
    local game = _game()
    local player = { id = 1, cash = 0 }
    _assert_eq(sign_in.claim(game, "RewardDay3", player), true, "RewardDay3 claim should succeed")
    _assert_eq(player.cash, 2000, "RewardDay3 should grant the day-3 reward")
  end)

  it("claims_do_nothing_for_non_reward_events", function()
    local game = _game()
    local player = { id = 1, cash = 500 }
    _assert_eq(sign_in.claim(game, "OtherEvent", player), false, "unrelated event should not claim")
    _assert_eq(sign_in.claim(game, "RewardDay", player), false, "RewardDay without a number should not claim")
    _assert_eq(player.cash, 500, "rejected claims should leave cash unchanged")
  end)
end)

describe("sign_in.install", function()
  local function _fake_game(players)
    return {
      find_player_by_id = function(_, role_id)
        return players[role_id]
      end,
      add_player_cash = function(_, player, amount)
        player.cash = (player.cash or 0) + amount
      end,
    }
  end

  local function _capturing_register()
    local handlers = {}
    local function register(name, handler)
      handlers[name] = handler
    end
    return register, handlers
  end

  it("registers_a_host_event_for_each_configured_reward_day", function()
    local register, handlers = _capturing_register()
    sign_in.install({
      register_event = register,
      get_game = function() return _fake_game({}) end,
      resolve_role_id = function() return nil end,
    })
    for day = 1, 7 do
      _assert_eq(type(handlers["RewardDay" .. day]), "function",
        "RewardDay" .. day .. " must be subscribed")
    end
    _assert_eq(handlers["RewardDay8"], nil, "only configured days are wired — no RewardDay8")
    _assert_eq(handlers["RewardDay0"], nil, "subscription starts at day 1 — no RewardDay0")
  end)

  it("grants_the_resolved_player_the_day_reward_when_an_event_fires", function()
    local register, handlers = _capturing_register()
    local player = { id = 7, cash = 0 }
    local game = _fake_game({ [7] = player })
    sign_in.install({
      register_event = register,
      get_game = function() return game end,
      resolve_role_id = function(data) return data and data.role or nil end,
    })
    -- host fires the handler as handler(_, _, data); payload carries the role.
    handlers["RewardDay2"](nil, nil, { role = 7 })
    _assert_eq(player.cash, 1000, "RewardDay2 must credit the resolved player the day-2 reward")
  end)

  it("does_nothing_when_no_game_is_active", function()
    local register, handlers = _capturing_register()
    sign_in.install({
      register_event = register,
      get_game = function() return nil end,
      resolve_role_id = function() return 7 end,
    })
    -- firing before a game exists must be a safe no-op, not an error.
    handlers["RewardDay1"](nil, nil, { role = 7 })
  end)

  it("does_nothing_when_the_claiming_player_cannot_be_resolved", function()
    local register, handlers = _capturing_register()
    local game = _fake_game({})
    sign_in.install({
      register_event = register,
      get_game = function() return game end,
      resolve_role_id = function() return 999 end,
    })
    -- unknown role → find_player_by_id returns nil → grant is a no-op, no error.
    handlers["RewardDay3"](nil, nil, {})
  end)
end)
