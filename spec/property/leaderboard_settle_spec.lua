local property = require("spec.support.property")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local leaderboard = require("src.app.host_integrations.leaderboard")
local asset_total = require("src.rules.land.asset_total")

local WIN = leaderboard.win_count_archive_key
local ASSETS = leaderboard.total_assets_archive_key

local QUIT_REASONS = { "disconnect", "manual_exit", "crash" }
local NON_QUIT_REASONS = { "normal_finish", "afk", "victory" }

local function _slot(role_id, archive_key)
  return tostring(role_id) .. "|" .. tostring(archive_key)
end

-- Installs an in-memory archive store backed by the runtime ports, mirroring the
-- behavior spec harness, and returns the store plus a write counter.
local function _install_archives(enabled, seed)
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
local function _game(players, winners)
  return {
    players = players,
    winners = winners,
    player_balance = function(_, player)
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

describe("leaderboard.settle accumulation properties", function()
  after_each(function()
    runtime_ports.reset_for_tests()
  end)

  it("adds one win per winner and remaining assets per non-quit player, leaving the rest untouched", function()
    property.for_all(_generate, function(case)
      local store = _install_archives(true, case.seed)
      local game = _game(case.players, case.winners)
      local winner_ids = _winner_id_set(case)

      assert(leaderboard.settle(game) == true, "first settlement on enabled archives must run")

      local expected_win_total, expected_asset_total = 0, 0
      for _, player in ipairs(case.players) do
        local expected_win_delta = winner_ids[player.id] and 1 or 0
        -- A quit winner still earns the win but contributes no assets.
        local expected_asset_delta = 0
        if not leaderboard.is_quit_reason(player.quit_reason) then
          expected_asset_delta = asset_total.player_total(game, player)
        end
        assert(store[_slot(player.id, WIN)] == case.seed[_slot(player.id, WIN)] + expected_win_delta,
          "win archive must change by exactly the winner delta for player " .. player.id)
        assert(store[_slot(player.id, ASSETS)] == case.seed[_slot(player.id, ASSETS)] + expected_asset_delta,
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
      assert(actual_win_total == expected_win_total, "total wins added must equal the present winner count")
      assert(actual_asset_total == expected_asset_total, "total assets added must equal the non-quit player sum")
    end)
  end)

  it("is idempotent: a second settlement reports skipped and changes no archive", function()
    property.for_all(_generate, function(case)
      local store = _install_archives(true, case.seed)
      local game = _game(case.players, case.winners)

      leaderboard.settle(game)
      local snapshot = {}
      for key, value in pairs(store) do
        snapshot[key] = value
      end

      assert(leaderboard.settle(game) == false, "repeat settlement must report skipped")
      for key, value in pairs(store) do
        assert(snapshot[key] == value, "repeat settlement must not change archive " .. key)
      end
      for key, value in pairs(snapshot) do
        assert(store[key] == value, "repeat settlement must not remove archive " .. key)
      end
    end)
  end)

  it("writes nothing and reports skipped when host archives are disabled", function()
    property.for_all(_generate, function(case)
      local _, writes = _install_archives(false, case.seed)
      local game = _game(case.players, case.winners)

      assert(leaderboard.settle(game) == false, "disabled archives must report skipped")
      assert(writes.count == 0, "disabled archives must receive no writes")
    end)
  end)
end)
