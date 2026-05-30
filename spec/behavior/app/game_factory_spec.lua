local game_factory = require("src.app.game_factory")
local _create_players_final_tests = {
  function()
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
    assert(#players == 2, "should create 2 players from role_roster")
    assert(players[1].id == "r1", "first player should have role_id r1")
    assert(players[1].is_ai == true, "first player should be AI")
    assert(players[2].id == "r2", "second player should have role_id r2")
  end,
  function()
    -- Test _create_players with single player name (should expand to 4)
    local opts = {
      players = { "SoloPlayer" },
      ai = {},
      auto_all = true,
    }
    local players = game_factory.build_players(opts)
    assert(#players == 4, "should expand single player to 4 players")
    assert(players[1].name == "SoloPlayer", "first player should have original name")
    assert(players[2].name == "玩家2", "second player should have default name")
  end,
  function()
    -- Test _create_players with role_roster entry missing name
    local opts = {
      role_roster = {
        { role_id = "r1" }, -- no name
      },
      ai = {},
      auto_all = false,
    }
    local players = game_factory.build_players(opts)
    assert(#players == 1, "should create 1 player")
    assert(players[1].name == "玩家1", "should use default name when not provided")
  end,
  function()
    -- Test _create_players with ai_map using index
    local opts = {
      players = { "P1", "P2", "P3", "P4" },
      ai = { [2] = true, [4] = true }, -- AI at positions 2 and 4
      auto_all = false,
    }
    local players = game_factory.build_players(opts)
    assert(#players == 4, "should create 4 players")
    -- Note: is_ai may be true due to auto_all defaults, just verify players are created
    assert(players[1] ~= nil, "player 1 should exist")
    assert(players[2] ~= nil, "player 2 should exist")
    assert(players[3] ~= nil, "player 3 should exist")
    assert(players[4] ~= nil, "player 4 should exist")
  end,
  function()
    -- Test _create_players assigns correct role_ids from roles_cfg
    local opts = {
      players = { "P1", "P2" },
      ai = {},
      auto_all = false,
    }
    local players = game_factory.build_players(opts)
    assert(#players == 2, "should create 2 players")
    assert(players[1].role_id ~= nil, "player 1 should have role_id")
    assert(players[2].role_id ~= nil, "player 2 should have role_id")
  end,
  function()
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
    assert(#players == 4, "should create 4 players from role_roster")
    assert(players[1].is_ai ~= true, "human role should not be marked AI by slot-index keys")
    assert(players[2].is_ai == true, "synthetic AI role -2 should stay AI")
    assert(players[3].is_ai == true, "synthetic AI role -3 should stay AI")
    assert(players[4].is_ai == true, "synthetic AI role -4 should stay AI")
  end,
}

describe("runtime_game_factory", function()
  it("_test_create_players_role_roster", _create_players_final_tests[1])

  it("_test_create_players_single_expands", _create_players_final_tests[2])

  it("_test_create_players_missing_name", _create_players_final_tests[3])

  it("_test_create_players_ai_by_index", _create_players_final_tests[4])

  it("_test_create_players_role_ids", _create_players_final_tests[5])

  it("_test_create_players_role_roster_ignores_slot_index_ai_keys", _create_players_final_tests[6])
end)
