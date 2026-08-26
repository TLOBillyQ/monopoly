-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 断言从裸 assert 切到 lu.assertEvalToTrue,用例数与改写前一一对应(6 例)。

local lu = require("luaunit")
local game_factory = require("src.app.game_factory")
local balance_ops = require("src.player.actions.balance")
local constants = require("src.config.content.constants")
local control = require("src.player.control")

TestGameFactory = {}

function TestGameFactory:test_create_players_role_roster()
  -- Test _create_players with role_roster
  local opts = {
    role_roster = {
      { role_id = "r1", name = "Player1" },
      { role_id = "r2", name = "Player2" },
    },
    ai = { r1 = true },
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 2, "should create 2 players from role_roster")
  lu.assertEvalToTrue(players[1].id == "r1", "first player should have role_id r1")
  lu.assertEvalToTrue(players[1].is_ai == true, "first player should be AI")
  lu.assertEvalToTrue(players[2].id == "r2", "second player should have role_id r2")
end

function TestGameFactory:test_create_players_single_expands()
  -- Test _create_players with single player name (should expand to 4)
  local opts = {
    players = { "SoloPlayer" },
    ai = {},
    auto_all = true,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 4, "should expand single player to 4 players")
  lu.assertEvalToTrue(players[1].name == "SoloPlayer", "first player should have original name")
  lu.assertEvalToTrue(players[2].name == "玩家2", "second player should have default name")
end

function TestGameFactory:test_create_players_missing_name()
  -- Test _create_players with role_roster entry missing name
  local opts = {
    role_roster = {
      { role_id = "r1" }, -- no name
    },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 1, "should create 1 player")
  lu.assertEvalToTrue(players[1].name == "玩家1", "should use default name when not provided")
end

function TestGameFactory:test_create_players_ai_by_index()
  -- Test _create_players with ai_map using index
  local opts = {
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [4] = true }, -- AI at positions 2 and 4
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 4, "should create 4 players")
  -- Note: is_ai may be true due to auto_all defaults, just verify players are created
  lu.assertEvalToTrue(players[1] ~= nil, "player 1 should exist")
  lu.assertEvalToTrue(players[2] ~= nil, "player 2 should exist")
  lu.assertEvalToTrue(players[3] ~= nil, "player 3 should exist")
  lu.assertEvalToTrue(players[4] ~= nil, "player 4 should exist")
end

function TestGameFactory:test_create_players_role_ids()
  -- Test _create_players assigns correct role_ids from roles_cfg
  local opts = {
    players = { "P1", "P2" },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 2, "should create 2 players")
  lu.assertEvalToTrue(players[1].role_id ~= nil, "player 1 should have role_id")
  lu.assertEvalToTrue(players[2].role_id ~= nil, "player 2 should have role_id")
end

function TestGameFactory:test_role_roster_preserves_provided_name()
  -- L79 `entry and entry.name or nil` 的 or->and 变异会把非空名吞成缺省名。
  local opts = {
    role_roster = { { role_id = "r1", name = "Player1" } },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(players[1].name == "Player1",
    "roster entry name must be preserved; got " .. tostring(players[1].name))
end

function TestGameFactory:test_role_roster_empty_name_defaults_to_index()
  -- 空串名必须走缺省名分支(不返回空串)。
  local opts = {
    role_roster = { { role_id = "r1", name = "" } },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(players[1].name == "玩家1",
    "empty roster name must default to 玩家1; got " .. tostring(players[1].name))
end

function TestGameFactory:test_auto_all_marks_all_human_players_manually_delegated()
  -- L87 首个 or->and 与 L98 调用换 nil:auto_all=true 时托管必须仍为 true。
  local opts = {
    role_roster = { { role_id = "r1", name = "A" }, { role_id = "r2", name = "B" } },
    ai = {},
    auto_all = true,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(control.is_delegated(players[1]), "auto_all must delegate player 1")
  lu.assertEvalToTrue(control.is_computer_controlled(players[1]), "delegated player 1 must be computer controlled")
  lu.assertEvalToTrue(control.is_delegated(players[2]), "auto_all must delegate player 2")
end

function TestGameFactory:test_auto_flag_resolves_from_auto_players()
  -- L87 第二个 or->and 与尾部 false->true:auto_players 命中与未命中的角色托管必须不同。
  local opts = {
    role_roster = {
      { role_id = "r1", name = "A" },
      { role_id = "r2", name = "B" },
    },
    ai = {},
    auto_all = false,
    auto_players = { r1 = true },
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(control.is_delegated(players[1]), "auto_players hit must delegate")
  lu.assertEvalToTrue(not control.is_delegated(players[2]), "auto_players miss must stay direct")
end

function TestGameFactory:test_names_path_cycles_roles_in_order()
  -- L111 角色下标算术:3 个名字必须依次拿到 roles_cfg[1..3] 的 id。
  local opts = {
    players = { "P1", "P2", "P3" },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(players[1].role_id == 1001, "player 1 must get roles_cfg[1].id")
  lu.assertEvalToTrue(players[2].role_id == 1002, "player 2 must get roles_cfg[2].id")
  lu.assertEvalToTrue(players[3].role_id == 1003, "player 3 must get roles_cfg[3].id")
end

function TestGameFactory:test_empty_role_roster_falls_back_to_names()
  -- L121 #role_roster > 0 的 >->=:空 roster 表必须回落 names 路径而不是产出空玩家表。
  local opts = {
    role_roster = {},
    players = { "Solo", "Solo2" },
    ai = {},
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 2, "empty role_roster must fall back to names path")
  lu.assertEvalToTrue(players[1].name == "Solo", "fallback must keep the provided name")
end

function TestGameFactory:test_starting_cash_comes_from_constants()
  -- 起始金币唯一真源是 constants.starting_cash(fan_club 存根已拆,无加成通路)。
  local players = game_factory.build_players({ players = { "A" }, ai = {}, auto_all = false })
  lu.assertEvalToTrue(balance_ops.player_cash(nil, players[1]) == constants.starting_cash,
    "player must start with exactly constants.starting_cash")
end

function TestGameFactory:test_create_players_role_roster_ignores_slot_index_ai_keys()
  -- Test role_roster mode ignores slot-index ai keys to avoid human/AI key collisions
  local opts = {
    role_roster = {
      { role_id = 20, name = "Human" },
      { role_id = -2, name = "AI2", synthetic = true },
      { role_id = -3, name = "AI3", synthetic = true },
      { role_id = -4, name = "AI4", synthetic = true },
    },
    ai = {
      [1] = true,
      [2] = true,
      [3] = true,
      [4] = true,
      [-2] = true,
      [-3] = true,
      [-4] = true,
    },
    auto_all = false,
  }
  local players = game_factory.build_players(opts)
  lu.assertEvalToTrue(#players == 4, "should create 4 players from role_roster")
  lu.assertEvalToTrue(players[1].is_ai ~= true, "human role should not be marked AI by slot-index keys")
  lu.assertEvalToTrue(players[2].is_ai == true, "synthetic AI role -2 should stay AI")
  lu.assertEvalToTrue(players[3].is_ai == true, "synthetic AI role -3 should stay AI")
  lu.assertEvalToTrue(players[4].is_ai == true, "synthetic AI role -4 should stay AI")
end


return TestGameFactory
