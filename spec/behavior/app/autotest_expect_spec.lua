local support = require("spec.support.test_profile_support")
local autotest_expect = require("src.app.testing.autotest_expect")
local event_log = require("src.state.event_log")
local event_kinds = require("src.config.gameplay.event_kinds")

local function _new_game()
  local game = support.new_game()
  -- 生产里 game.state.event_log 由 event_feed_adapter 惰性创建
  -- （src/turn/output/event_feed_adapter.lua:13-14）；这里同构补齐。
  game.state = game.state or {}
  game.state.event_log = game.state.event_log or event_log.new()
  return game
end

local function _hospital_index(game)
  return assert(game.board:find_first_by_type("hospital"), "map should provide hospital tile")
end

describe("autotest_expect.evaluate", function()
  it("nil_expect_always_passes", function()
    local verdict = autotest_expect.evaluate(_new_game(), nil)
    assert(verdict.ok == true, "nil expect means no assertion")
    assert(#verdict.failures == 0, "no failures expected")
  end)

  it("tile_level_matches_and_mismatches", function()
    local game = _new_game()
    local tile = assert(game.board:get_tile_by_id(11), "tile 11 should exist")
    game:set_tile_level(tile, 2)

    local ok_verdict = autotest_expect.evaluate(game, { tiles = { [11] = { level = 2 } } })
    assert(ok_verdict.ok == true, "matching level should pass")

    local bad_verdict = autotest_expect.evaluate(game, { tiles = { [11] = { level = 0 } } })
    assert(bad_verdict.ok == false, "level mismatch should fail")
    assert(#bad_verdict.failures == 1, "one failure expected")
    assert(bad_verdict.failures[1]:find("tile 11", 1, true) ~= nil, "failure names the tile")
  end)

  it("player_in_hospital_requires_position_and_detention", function()
    local game = _new_game()
    local player = game.players[2]

    local before = autotest_expect.evaluate(game, { players = { [2] = { in_hospital = true } } })
    assert(before.ok == false, "player not yet hospitalised")

    game:update_player_position(player, _hospital_index(game))
    local without_detention = autotest_expect.evaluate(game, { players = { [2] = { in_hospital = true } } })
    assert(without_detention.ok == false, "standing on hospital without stay is not hospitalised")

    game:set_player_status(player, "stay_turns", 2)
    local hospitalised = autotest_expect.evaluate(game, { players = { [2] = { in_hospital = true } } })
    assert(hospitalised.ok == true, "position + detention means hospitalised")
  end)

  it("player_cash_compares_exactly", function()
    local game = _new_game()
    game:set_player_cash(game.players[1], 4321)
    assert(autotest_expect.evaluate(game, { players = { [1] = { cash = 4321 } } }).ok == true,
      "exact cash should pass")
    assert(autotest_expect.evaluate(game, { players = { [1] = { cash = 1 } } }).ok == false,
      "wrong cash should fail")
  end)

  it("event_kind_scans_event_log_history", function()
    local game = _new_game()
    local expect = { events = { { kind = event_kinds.demolish } } }

    local missing = autotest_expect.evaluate(game, expect)
    assert(missing.ok == false, "kind not yet published")

    event_log.append(game.state.event_log, { kind = event_kinds.demolish, text = "boom" })
    local seen = autotest_expect.evaluate(game, expect)
    assert(seen.ok == true, "published kind should pass")
  end)

  it("solo_missile_expect_shape_is_fully_supported", function()
    -- 钉住 evaluator 与现网唯一 expect（solo_missile）的兼容：把期望态
    -- 直接摆出来，evaluator 必须整体通过。防止 expect schema 与 evaluator 漂移。
    local test_profiles = require("src.app.testing.test_profiles")
    local expect = assert(test_profiles.get("solo_missile").expect, "solo_missile carries expect")

    local game = _new_game()
    local tile = assert(game.board:get_tile_by_id(11), "tile 11 should exist")
    game:set_tile_level(tile, 0)
    local occupant = game.players[2]
    game:update_player_position(occupant, _hospital_index(game))
    game:set_player_status(occupant, "stay_turns", 2)
    event_log.append(game.state.event_log, { kind = event_kinds.demolish, text = "boom" })

    local verdict = autotest_expect.evaluate(game, expect)
    assert(verdict.ok == true,
      "solo_missile expect should evaluate clean, failures: " .. table.concat(verdict.failures, "; "))
  end)

  it("unsupported_expect_keys_raise_instead_of_passing_silently", function()
    local game = _new_game()
    assert(not pcall(autotest_expect.evaluate, game, { tiles = { [11] = { owner = 1 } } }),
      "unknown tile key must raise")
    assert(not pcall(autotest_expect.evaluate, game, { players = { [1] = { position = 3 } } }),
      "unknown player key must raise")
  end)
end)
