local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
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

describe("leaderboard.settle", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("increments_win_count_for_each_winner_only", function()
    local winner = _player(1, 0)
    local loser = _player(2, 0)
    local store, _, slot = _install_archives(true, {
      [tostring(1) .. "|" .. tostring(WIN)] = 3,
      [tostring(2) .. "|" .. tostring(WIN)] = 5,
    })
    leaderboard.settle(_game({ winner, loser }, { winner }))

    _assert_eq(store[slot(1, WIN)], 4, "winner win count should increment by one")
    _assert_eq(store[slot(2, WIN)], 5, "non-winner win count should stay unchanged")
  end)

  it("accumulates_remaining_assets_for_present_players", function()
    local player = _player(1, 30000)
    local store, _, slot = _install_archives(true, {
      [tostring(1) .. "|" .. tostring(ASSETS)] = 50000,
    })
    leaderboard.settle(_game({ player }, {}))

    _assert_eq(store[slot(1, ASSETS)], 80000, "present player assets should add to the cumulative total")
  end)

  it("excludes_quit_players_from_asset_accumulation", function()
    local player = _player(1, 99999, { quit_reason = "disconnect" })
    local store, _, slot = _install_archives(true, {
      [tostring(1) .. "|" .. tostring(ASSETS)] = 50000,
    })
    leaderboard.settle(_game({ player }, {}))

    _assert_eq(store[slot(1, ASSETS)], 50000, "quit player assets must not be counted")
  end)

  it("increments_each_winner_in_a_tie", function()
    local one = _player(1, 0)
    local two = _player(2, 0)
    local store, _, slot = _install_archives(true, {
      [tostring(1) .. "|" .. tostring(WIN)] = 2,
      [tostring(2) .. "|" .. tostring(WIN)] = 2,
    })
    leaderboard.settle(_game({ one, two }, { one, two }))

    _assert_eq(store[slot(1, WIN)], 3, "first tied winner should gain one win")
    _assert_eq(store[slot(2, WIN)], 3, "second tied winner should gain one win")
  end)

  it("does_not_double_count_on_repeat_settlement", function()
    local winner = _player(1, 50000)
    local store, _, slot = _install_archives(true, {})
    local game = _game({ winner }, { winner })

    _assert_eq(leaderboard.settle(game), true, "first settlement should run")
    local wins_after_first = store[slot(1, WIN)]
    local assets_after_first = store[slot(1, ASSETS)]

    _assert_eq(leaderboard.settle(game), false, "repeat settlement should be a no-op")
    _assert_eq(store[slot(1, WIN)], wins_after_first, "repeat settlement should not add wins")
    _assert_eq(store[slot(1, ASSETS)], assets_after_first, "repeat settlement should not add assets")
  end)

  it("writes_nothing_when_archives_are_disabled", function()
    local winner = _player(1, 50000)
    local _, writes = _install_archives(false, {})

    _assert_eq(leaderboard.settle(_game({ winner }, { winner })), false,
      "settlement should report skipped when archives are off")
    _assert_eq(writes.count, 0, "disabled archives must receive no writes")
  end)

  it("recognizes_host_quit_reasons", function()
    _assert_eq(leaderboard.is_quit_reason("disconnect"), true, "disconnect should be a quit reason")
    _assert_eq(leaderboard.is_quit_reason("manual_exit"), true, "manual exit should be a quit reason")
    _assert_eq(leaderboard.is_quit_reason("crash"), true, "crash should be a quit reason")
    _assert_eq(leaderboard.is_quit_reason("normal_finish"), false, "a normal finish is not a quit reason")
    _assert_eq(leaderboard.is_quit_reason(nil), false, "missing reason is not a quit reason")
  end)
end)
