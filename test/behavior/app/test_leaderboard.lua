-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为 Test* 类,after_each →
-- tearDown,断言从裸 assert 切到 luassert.truthy,用例数与改写前一一对应
-- (settle 7 例 + 迁自 property 车道的 accumulation properties 3 例 = 10 例)。

require("test.bootstrap").install_package_paths()
-- busted injects luassert fields on assert.
-- luacheck: ignore 143
local luassert = assert
local support = require("test.support.shared_support")
local function _assert_eq(actual, expected, message)
  luassert.is.equal(expected, actual, message)
end
local runtime_ports = require("src.foundation.ports.runtime_ports")
local leaderboard = require("src.app.host_integrations.leaderboard")

local WIN = leaderboard.win_count_archive_key
local ASSETS = leaderboard.total_assets_archive_key

-- Installs an in-memory archive store backed by the runtime ports and returns
-- the store plus a write counter so tests can assert "no writes" cases.
local function _install_archives(enabled, seed)
  local store = {}
  for key, value in pairs(seed or {}) do
    store[key] = value
  end
  local writes = { count = 0 }
  local function _slot(role_id, archive_key)
    return tostring(role_id) .. "|" .. tostring(archive_key)
  end
  runtime_ports.configure({
    archives_enabled = function()
      return enabled
    end,
    get_archive_int = function(role_id, archive_key)
      return store[_slot(role_id, archive_key)] or 0
    end,
    set_archive_int = function(role_id, archive_key, value)
      store[_slot(role_id, archive_key)] = value
      writes.count = writes.count + 1
    end,
  })
  return store, writes, _slot
end

local function _player(id, cash, overrides)
  local player = { id = id, name = "P" .. tostring(id), properties = {}, cash = cash }
  for key, value in pairs(overrides or {}) do
    player[key] = value
  end
  return player
end

local function _game(players, winners)
  return {
    players = players,
    winners = winners,
    player_cash = function(_, player)
      return player.cash or 0
    end,
    board = { get_tile_by_id = function() return nil end },
  }
end

describe("TestLeaderboardSettle", function()
  after_each(function()
    runtime_ports.reset_for_tests()
    support.restore_runtime_services()
  end)

local function _test_increments_win_count_for_each_winner_only()
  local winner = _player(1, 0)
  local loser = _player(2, 0)
  local store, _, slot = _install_archives(true, {
    [tostring(1) .. "|" .. tostring(WIN)] = 3,
    [tostring(2) .. "|" .. tostring(WIN)] = 5,
  })
  leaderboard.settle(_game({ winner, loser }, { winner }))

  _assert_eq(store[slot(1, WIN)], 4, "winner win count should increment by one")
  _assert_eq(store[slot(2, WIN)], 5, "non-winner win count should stay unchanged")
end

local function _test_accumulates_remaining_assets_for_present_players()
  local player = _player(1, 30000)
  local store, _, slot = _install_archives(true, {
    [tostring(1) .. "|" .. tostring(ASSETS)] = 50000,
  })
  leaderboard.settle(_game({ player }, {}))

  _assert_eq(store[slot(1, ASSETS)], 80000, "present player assets should add to the cumulative total")
end

local function _test_excludes_quit_players_from_asset_accumulation()
  local player = _player(1, 99999, { quit_reason = "disconnect" })
  local store, _, slot = _install_archives(true, {
    [tostring(1) .. "|" .. tostring(ASSETS)] = 50000,
  })
  leaderboard.settle(_game({ player }, {}))

  _assert_eq(store[slot(1, ASSETS)], 50000, "quit player assets must not be counted")
end

local function _test_increments_each_winner_in_a_tie()
  local one = _player(1, 0)
  local two = _player(2, 0)
  local store, _, slot = _install_archives(true, {
    [tostring(1) .. "|" .. tostring(WIN)] = 2,
    [tostring(2) .. "|" .. tostring(WIN)] = 2,
  })
  leaderboard.settle(_game({ one, two }, { one, two }))

  _assert_eq(store[slot(1, WIN)], 3, "first tied winner should gain one win")
  _assert_eq(store[slot(2, WIN)], 3, "second tied winner should gain one win")
end

local function _test_does_not_double_count_on_repeat_settlement()
  local winner = _player(1, 50000)
  local store, _, slot = _install_archives(true, {})
  local game = _game({ winner }, { winner })

  _assert_eq(leaderboard.settle(game), true, "first settlement should run")
  local wins_after_first = store[slot(1, WIN)]
  local assets_after_first = store[slot(1, ASSETS)]

  _assert_eq(leaderboard.settle(game), false, "repeat settlement should be a no-op")
  _assert_eq(store[slot(1, WIN)], wins_after_first, "repeat settlement should not add wins")
  _assert_eq(store[slot(1, ASSETS)], assets_after_first, "repeat settlement should not add assets")
end

local function _test_writes_nothing_when_archives_are_disabled()
  local winner = _player(1, 50000)
  local _, writes = _install_archives(false, {})

  _assert_eq(leaderboard.settle(_game({ winner }, { winner })), false,
    "settlement should report skipped when archives are off")
  _assert_eq(writes.count, 0, "disabled archives must receive no writes")
end

local function _test_recognizes_host_quit_reasons()
  _assert_eq(leaderboard.is_quit_reason("disconnect"), true, "disconnect should be a quit reason")
  _assert_eq(leaderboard.is_quit_reason("manual_exit"), true, "manual exit should be a quit reason")
  _assert_eq(leaderboard.is_quit_reason("crash"), true, "crash should be a quit reason")
  _assert_eq(leaderboard.is_quit_reason("normal_finish"), false, "a normal finish is not a quit reason")
  _assert_eq(leaderboard.is_quit_reason(nil), false, "missing reason is not a quit reason")
end

it("test_increments_win_count_for_each_winner_only", _test_increments_win_count_for_each_winner_only)
it("test_accumulates_remaining_assets_for_present_players", _test_accumulates_remaining_assets_for_present_players)
it("test_excludes_quit_players_from_asset_accumulation", _test_excludes_quit_players_from_asset_accumulation)
it("test_increments_each_winner_in_a_tie", _test_increments_each_winner_in_a_tie)
it("test_does_not_double_count_on_repeat_settlement", _test_does_not_double_count_on_repeat_settlement)
it("test_writes_nothing_when_archives_are_disabled", _test_writes_nothing_when_archives_are_disabled)
it("test_recognizes_host_quit_reasons", _test_recognizes_host_quit_reasons)
end)

-- ===== 迁自 test/property/test_leaderboard_settle.lua（#190）=====
describe("TestLeaderboardSettleAccumulationProperties", function()
  local property = require("test.support.property")
  local asset_total = require("src.rules.land.asset_total")


  local QUIT_REASONS = { "disconnect", "manual_exit", "crash" }
  local NON_QUIT_REASONS = { "normal_finish", "afk", "victory" }

  local function _slot(role_id, archive_key)
    return tostring(role_id) .. "|" .. tostring(archive_key)
  end

  -- Installs an in-memory archive store backed by the runtime ports, mirroring the
  -- behavior spec harness, and returns the store plus a write counter.
  local function _prop_install_archives(enabled, seed)
    local store = {}
    for key, value in pairs(seed or {}) do
      store[key] = value
    end
    local writes = { count = 0 }
    runtime_ports.configure({
      archives_enabled = function()
        return enabled
      end,
      get_archive_int = function(role_id, archive_key)
        return store[_slot(role_id, archive_key)] or 0
      end,
      set_archive_int = function(role_id, archive_key, value)
        store[_slot(role_id, archive_key)] = value
        writes.count = writes.count + 1
      end,
    })
    return store, writes
  end

  -- A game with no land tiles, so asset_total.player_total resolves to cash. The
  -- oracle still calls asset_total to stay decoupled from that resolution.
  local function _prop_game(players, winners)
    return {
      players = players,
      winners = winners,
      player_cash = function(_, player)
        return player.cash or 0
      end,
      board = { get_tile_by_id = function() return nil end },
    }
  end

  -- Build a random roster of players with distinct ids and a seeded archive store.
  -- Players carry a quit reason from one of three pools: a real quit reason, an
  -- explicit non-quit reason, or nil — exercising every is_quit_reason branch.
  local function _generate(rng)
    local count = rng:int(1, 6)
    local players = {}
    local winners = {}
    local seed = {}
    for id = 1, count do
      local quit_reason
      if rng:bool() then
        quit_reason = rng:pick(QUIT_REASONS)
      elseif rng:bool() then
        quit_reason = rng:pick(NON_QUIT_REASONS)
      end
      local player = { id = id, cash = rng:int(0, 100000), properties = {}, quit_reason = quit_reason }
      players[#players + 1] = player
      if rng:bool() then
        winners[#winners + 1] = player
      end
      seed[_slot(id, WIN)] = rng:int(0, 50)
      seed[_slot(id, ASSETS)] = rng:int(0, 1000000)
    end
    return { players = players, winners = winners, seed = seed }
  end

  local function _winner_id_set(case)
    local ids = {}
    for _, winner in ipairs(case.winners) do
      ids[winner.id] = true
    end
    return ids
  end

  after_each(function()
    runtime_ports.reset_for_tests()
    support.restore_runtime_services()
  end)

  local function _test_adds_one_win_per_winner_and_remaining_assets_per_non_quit_player_leaving_the_rest_untouched()
    property.for_all(_generate, function(case)
      local store = _prop_install_archives(true, case.seed)
      local game = _prop_game(case.players, case.winners)
      local winner_ids = _winner_id_set(case)

      luassert.truthy(leaderboard.settle(game) == true, "first settlement on enabled archives must run")

      local expected_win_total, expected_asset_total = 0, 0
      for _, player in ipairs(case.players) do
        local expected_win_delta = winner_ids[player.id] and 1 or 0
        -- A quit winner still earns the win but contributes no assets.
        local expected_asset_delta = 0
        if not leaderboard.is_quit_reason(player.quit_reason) then
          expected_asset_delta = asset_total.player_total(game, player)
        end
        luassert.truthy(store[_slot(player.id, WIN)] == case.seed[_slot(player.id, WIN)] + expected_win_delta,
          "win archive must change by exactly the winner delta for player " .. player.id)
        luassert.truthy(store[_slot(player.id, ASSETS)] == case.seed[_slot(player.id, ASSETS)] + expected_asset_delta,
          "asset archive must change by exactly the non-quit total for player " .. player.id)
        expected_win_total = expected_win_total + expected_win_delta
        expected_asset_total = expected_asset_total + expected_asset_delta
      end

      -- Conservation: aggregate deltas equal the per-player deltas summed.
      local actual_win_total, actual_asset_total = 0, 0
      for _, player in ipairs(case.players) do
        actual_win_total = actual_win_total
          + (store[_slot(player.id, WIN)] - case.seed[_slot(player.id, WIN)])
        actual_asset_total = actual_asset_total
          + (store[_slot(player.id, ASSETS)] - case.seed[_slot(player.id, ASSETS)])
      end
      luassert.truthy(actual_win_total == expected_win_total, "total wins added must equal the present winner count")
      luassert.truthy(actual_asset_total == expected_asset_total, "total assets added must equal the non-quit player sum")
    end)
  end

  local function _test_is_idempotent_a_second_settlement_reports_skipped_and_changes_no_archive()
    property.for_all(_generate, function(case)
      local store = _prop_install_archives(true, case.seed)
      local game = _prop_game(case.players, case.winners)

      leaderboard.settle(game)
      local snapshot = {}
      for key, value in pairs(store) do
        snapshot[key] = value
      end

      luassert.truthy(leaderboard.settle(game) == false, "repeat settlement must report skipped")
      for key, value in pairs(store) do
        luassert.truthy(snapshot[key] == value, "repeat settlement must not change archive " .. key)
      end
      for key, value in pairs(snapshot) do
        luassert.truthy(store[key] == value, "repeat settlement must not remove archive " .. key)
      end
    end)
  end

  local function _test_writes_nothing_and_reports_skipped_when_host_archives_are_disabled()
    property.for_all(_generate, function(case)
      local _, writes = _prop_install_archives(false, case.seed)
      local game = _prop_game(case.players, case.winners)

      luassert.truthy(leaderboard.settle(game) == false, "disabled archives must report skipped")
      luassert.truthy(writes.count == 0, "disabled archives must receive no writes")
    end)
  end
  it("test_adds_one_win_per_winner_and_remaining_assets_per_non_quit_player_leaving_the_rest_untouched", _test_adds_one_win_per_winner_and_remaining_assets_per_non_quit_player_leaving_the_rest_untouched)
  it("test_is_idempotent_a_second_settlement_reports_skipped_and_changes_no_archive", _test_is_idempotent_a_second_settlement_reports_skipped_and_changes_no_archive)
  it("test_writes_nothing_and_reports_skipped_when_host_archives_are_disabled", _test_writes_nothing_and_reports_skipped_when_host_archives_are_disabled)
end)
