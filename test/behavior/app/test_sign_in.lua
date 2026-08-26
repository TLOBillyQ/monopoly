-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):三个 describe 拍平成三个 Test* 类(sign_in.install
-- 的 describe 体 local 辅助留在 do 块内),断言从裸 assert 切到 lu.assertEvalToTrue,
-- 用例数与改写前一一对应(sign_in 8 + install 4 + 迁自 property 车道的
-- parsing and claim properties 3 = 15 例)。

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local sign_in = require("src.app.host_integrations.sign_in")

local function _game()
  return {
    add_player_cash = function(_, player, amount)
      player.cash = (player.cash or 0) + amount
    end,
  }
end

TestSignIn = {}

function TestSignIn:test_grants_the_configured_reward_for_each_day()
  local expected = { 500, 1000, 2000, 4000, 6000, 8000, 10000 }
  for day, amount in ipairs(expected) do
    local game = _game()
    local player = { id = 1, cash = 0 }
    _assert_eq(sign_in.grant(game, player, day), true, "day " .. day .. " grant should succeed")
    _assert_eq(player.cash, amount, "day " .. day .. " should grant " .. amount .. " coins")
  end
end

function TestSignIn:test_adds_reward_on_top_of_existing_cash()
  local game = _game()
  local player = { id = 1, cash = 1000 }
  sign_in.grant(game, player, 7)
  _assert_eq(player.cash, 11000, "day 7 reward should add to existing balance")
end

function TestSignIn:test_does_not_grant_for_unconfigured_day()
  for _, day in ipairs({ 0, 8, 99 }) do
    local game = _game()
    local player = { id = 1, cash = 500 }
    _assert_eq(sign_in.grant(game, player, day), false, "unconfigured day " .. day .. " should not grant")
    _assert_eq(player.cash, 500, "unconfigured day " .. day .. " should leave cash unchanged")
  end
end

function TestSignIn:test_rejects_grant_with_missing_arguments()
  local player = { id = 1, cash = 500 }
  _assert_eq(sign_in.grant(_game(), player, nil), false, "nil day should not grant")
  _assert_eq(sign_in.grant(nil, player, 1), false, "missing game should not grant")
  _assert_eq(sign_in.grant(_game(), nil, 1), false, "missing player should not grant")
  _assert_eq(player.cash, 500, "rejected grants should not change cash")
end

function TestSignIn:test_parses_the_reward_day_from_host_event_names()
  _assert_eq(sign_in.day_from_event("RewardDay1"), 1, "RewardDay1 should map to day 1")
  _assert_eq(sign_in.day_from_event("RewardDay7"), 7, "RewardDay7 should map to day 7")
  _assert_eq(sign_in.day_from_event("RewardDay"), nil, "RewardDay with no number is not a reward event")
  _assert_eq(sign_in.day_from_event("RewardDayX"), nil, "non-numeric suffix is not a reward event")
  _assert_eq(sign_in.day_from_event("OtherEvent"), nil, "unrelated event names map to nil")
  _assert_eq(sign_in.day_from_event(nil), nil, "nil event name maps to nil")
end

function TestSignIn:test_exposes_the_full_reward_table()
  _assert_eq(sign_in.amount_for_day(1), 500, "day 1 reward should be 500")
  _assert_eq(sign_in.amount_for_day(5), 6000, "day 5 reward should be 6000")
  _assert_eq(sign_in.amount_for_day(8), nil, "day 8 has no configured reward")
end

function TestSignIn:test_claims_grant_the_day_reward_for_a_host_reward_event()
  local game = _game()
  local player = { id = 1, cash = 0 }
  _assert_eq(sign_in.claim(game, "RewardDay3", player), true, "RewardDay3 claim should succeed")
  _assert_eq(player.cash, 2000, "RewardDay3 should grant the day-3 reward")
end

function TestSignIn:test_claims_do_nothing_for_non_reward_events()
  local game = _game()
  local player = { id = 1, cash = 500 }
  _assert_eq(sign_in.claim(game, "OtherEvent", player), false, "unrelated event should not claim")
  _assert_eq(sign_in.claim(game, "RewardDay", player), false, "RewardDay without a number should not claim")
  _assert_eq(player.cash, 500, "rejected claims should leave cash unchanged")
end

do
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

  TestSignInInstall = {}

  function TestSignInInstall:test_registers_a_host_event_for_each_configured_reward_day()
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
  end

  function TestSignInInstall:test_grants_the_resolved_player_the_day_reward_when_an_event_fires()
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
  end

  function TestSignInInstall:test_does_nothing_when_no_game_is_active()
    local register, handlers = _capturing_register()
    sign_in.install({
      register_event = register,
      get_game = function() return nil end,
      resolve_role_id = function() return 7 end,
    })
    -- firing before a game exists must be a safe no-op, not an error.
    handlers["RewardDay1"](nil, nil, { role = 7 })
  end

  function TestSignInInstall:test_does_nothing_when_the_claiming_player_cannot_be_resolved()
    local register, handlers = _capturing_register()
    local game = _fake_game({})
    sign_in.install({
      register_event = register,
      get_game = function() return game end,
      resolve_role_id = function() return 999 end,
    })
    -- unknown role → find_player_by_id returns nil → grant is a no-op, no error.
    handlers["RewardDay3"](nil, nil, {})
  end

  function TestSignInInstall:test_install_asserts_missing_deps_with_messages()
    -- #293:install 的 4 处依赖断言消息未测,消息→nil 变异存活。
    local ok_deps, err_deps = pcall(sign_in.install, nil)
    lu.assertEvalToTrue(ok_deps == false, "install without deps should assert")
    lu.assertEvalToTrue(tostring(err_deps):find("missing sign_in install deps", 1, true) ~= nil,
      "deps assert should carry its message: " .. tostring(err_deps))

    local ok_register, err_register = pcall(sign_in.install, {})
    lu.assertEvalToTrue(ok_register == false, "install without register_event should assert")
    lu.assertEvalToTrue(tostring(err_register):find("missing register_event", 1, true) ~= nil,
      "register assert should carry its message: " .. tostring(err_register))

    local ok_game, err_game = pcall(sign_in.install, { register_event = function() end })
    lu.assertEvalToTrue(ok_game == false, "install without get_game should assert")
    lu.assertEvalToTrue(tostring(err_game):find("missing get_game", 1, true) ~= nil,
      "get_game assert should carry its message: " .. tostring(err_game))

    local ok_role, err_role = pcall(sign_in.install, {
      register_event = function() end,
      get_game = function() return {} end,
    })
    lu.assertEvalToTrue(ok_role == false, "install without resolve_role_id should assert")
    lu.assertEvalToTrue(tostring(err_role):find("missing resolve_role_id", 1, true) ~= nil,
      "resolve_role_id assert should carry its message: " .. tostring(err_role))
  end

  function TestSignInInstall:test_player_lookup_skips_nil_role_id_without_querying()
    -- #293:_find_player_by_role_id 的 `role_id ~= nil and ...`(or 变异)会让
    -- nil role_id 带着 nil 去查 find_player_by_id——用调用计数钉住「不查询」。
    local register, handlers = _capturing_register()
    local lookups = {}
    local game = {
      find_player_by_id = function(_, role_id)
        -- 追加哨兵而非 role_id 本身:nil 值不进表,计数会漏。
        lookups[#lookups + 1] = { role_id = role_id }
        return nil
      end,
      add_player_cash = function() end,
    }
    sign_in.install({
      register_event = register,
      get_game = function() return game end,
      resolve_role_id = function() return nil end,
    })
    handlers["RewardDay1"](nil, nil, {})
    lu.assertEvalToTrue(#lookups == 0,
      "nil role id must not query the game; got " .. #lookups .. " lookups")
  end
end

-- ===== 迁自 test/property/test_sign_in.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
do

  local property = require("test.support.property")
  local rewards = require("src.config.content.sign_in_rewards")

  local function _prop_game()
    return {
      add_player_cash = function(_, player, amount)
        player.cash = (player.cash or 0) + amount
      end,
    }
  end

  TestSignInParsingAndClaimProperties = {}

  function TestSignInParsingAndClaimProperties:test_round_trips_any_positive_day_through_the_reward_day_event_name()
    property.for_all(function(rng)
      return rng:int(1, 10000000)
    end, function(day)
      lu.assertEvalToTrue(sign_in.day_from_event("RewardDay" .. day) == day,
        "RewardDay<day> must parse back to the same day, including beyond the configured range")
    end)
  end

  function TestSignInParsingAndClaimProperties:test_rejects_event_names_with_a_non_digit_appended_to_the_day()
    -- Guards the trailing `$` anchor: a well-formed prefix plus trailing junk
    -- must not be accepted as a reward event.
    local SUFFIXES = { "x", " ", "0x", "-", ".5", "!" }
    property.for_all(function(rng)
      return { day = rng:int(1, 10000), suffix = rng:pick(SUFFIXES) }
    end, function(case)
      lu.assertEvalToTrue(sign_in.day_from_event("RewardDay" .. case.day .. case.suffix) == nil,
        "a non-digit suffix must not parse as a reward event")
    end)
  end

  function TestSignInParsingAndClaimProperties:test_claims_grant_exactly_the_configured_coins_for_configured_days_and_nothing_otherwise()
    property.for_all(function(rng)
      return { day = rng:int(1, 12), cash = rng:int(0, 100000) }
    end, function(case)
      local player = { id = 1, cash = case.cash }
      local granted = sign_in.claim(_prop_game(), "RewardDay" .. case.day, player)
      local configured = rewards[case.day]
      if configured == nil then
        lu.assertEvalToTrue(granted == false, "an unconfigured day must not grant")
        lu.assertEvalToTrue(player.cash == case.cash, "an unconfigured day must leave cash unchanged")
      else
        lu.assertEvalToTrue(granted == true, "a configured day must grant")
        lu.assertEvalToTrue(player.cash == case.cash + configured,
          "a configured claim must add exactly the configured coins to existing cash")
      end
    end)
  end


end

-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestSignIn,
  TestSignInInstall,
  TestSignInParsingAndClaimProperties
)
