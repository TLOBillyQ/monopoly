-- turn→UI 玩家控制快照契约(#590):每个玩家一份不可变快照,至少包含
-- is_delegated 与 is_computer_controlled,且由玩家控制公开查询派生。
local lu = require("luaunit")
local snapshot = require("src.turn.output.player_control_snapshot")
local control = require("src.player.control")

local function _player(id, is_ai)
  local player = { id = id, name = "P" .. tostring(id), is_ai = is_ai == true }
  control.initialize(player)
  return player
end

TestPlayerControlSnapshot = {}

function TestPlayerControlSnapshot:test_builds_a_snapshot_per_player_with_delegation_and_computer_control()
  local direct = _player(1, false)
  local manual = _player(2, false)
  local afk = _player(3, false)
  local computer = _player(4, true)
  control.toggle_manual_delegation(manual)
  control.enable_afk_delegation(afk)

  local by_player = snapshot.build({
    players = { direct, manual, afk, computer },
  })

  lu.assertEquals(by_player[1].is_delegated, false)
  lu.assertEquals(by_player[1].is_computer_controlled, false)
  lu.assertEquals(by_player[2].is_delegated, true)
  lu.assertEquals(by_player[2].is_computer_controlled, true)
  lu.assertEquals(by_player[3].is_delegated, true)
  lu.assertEquals(by_player[3].is_computer_controlled, true)
  lu.assertEquals(by_player[4].is_delegated, false)
  lu.assertEquals(by_player[4].is_computer_controlled, true)
end

function TestPlayerControlSnapshot:test_each_build_returns_fresh_tables()
  local player = _player(1, false)
  local game = { players = { player } }

  local first = snapshot.build(game)
  local second = snapshot.build(game)
  lu.assertNotIs(first, second, "snapshot map must be rebuilt each call")
  lu.assertNotIs(first[1], second[1], "snapshot entries must be rebuilt each call")
end

function TestPlayerControlSnapshot:test_install_attaches_the_current_snapshot_to_the_game()
  local player = _player(1, false)
  local game = { players = { player } }

  local installed = snapshot.install(game)
  lu.assertIs(game.player_control_snapshots, installed, "install must attach the snapshot to game")
  lu.assertEquals(installed[1].is_delegated, false)
end

function TestPlayerControlSnapshot:test_snapshot_entries_reject_mutation()
  local player = _player(1, false)
  local game = { players = { player } }
  local by_player = snapshot.build(game)

  lu.assertErrorMsgContains("immutable", function()
    by_player[1].is_delegated = true
  end)
  lu.assertErrorMsgContains("immutable", function()
    by_player[99] = { is_delegated = true, is_computer_controlled = true }
  end)
end

function TestPlayerControlSnapshot:test_find_resolves_players_by_normalized_role_id()
  local player = _player(7, false)
  local game = { players = { player } }
  snapshot.install(game)

  lu.assertEquals(snapshot.find(game, 7).is_computer_controlled, false)
  lu.assertIsNil(snapshot.find(game, 99))
  lu.assertIsNil(snapshot.find({ players = {} }, 7))
end

return TestPlayerControlSnapshot
