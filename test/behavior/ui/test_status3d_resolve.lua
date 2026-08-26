-- Direct unit coverage for src.ui.render.status3d.status_resolve, the pure
-- status-resolution module split out of status3d. Focuses on the 扣留剩余回合
-- 含当前回合 (inclusive) convention (CONTEXT「扣留剩余回合」): while a player is detained on the
-- current frozen turn the displayed remaining adds the current turn back, so the
-- status3d overlay shows the same count as the detention tip and never 0.
--
-- 原生 LuaUnit 迁移(自研 busted → LuaUnit):describe/it 拍平为文件级 Test*
-- 类,断言从 luassert 兼容层切到 lu.assertXxx,用例数与改写前一一对应(12 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local status_resolve = require("src.ui.render.status3d.status_resolve")

local function _detained_game(player_id, last_stay_turns)
  return {
    turn = {
      no_action_notice_active = true,
      no_action_notice_player_id = player_id,
    },
    last_turn = {
      player_id = player_id,
      skipped = true,
      stay_turns = last_stay_turns,
    },
  }
end

local function _player(stay_turns)
  return { id = 1, position = 5, status = { stay_turns = stay_turns } }
end

-- Mutation-hardening coverage for src.ui.render.status3d.status_resolve. These
-- cases pin boundary behavior that the happy-path unit/hotspot specs leave
-- indistinguishable from mutated variants (literal/relational/boolean operator
-- mutations).
local function _hospital_board()
  return {
    get_tile = function()
      return { type = "hospital" }
    end,
  }
end

TestStatus3dResolve = {}

function TestStatus3dResolve:test_adds_the_current_frozen_turn_back_while_detained()
  local player = _player(2)
  local remaining = status_resolve.resolve_remaining_value(_detained_game(1, 2), player, "stay_turns")
  _assert_eq(remaining, 3, "detained remaining must be raw stay_turns + 1 (含当前回合)")
end

function TestStatus3dResolve:test_never_resolves_to_0_on_the_last_frozen_turn()
  local player = _player(0)
  local remaining = status_resolve.resolve_remaining_value(_detained_game(1, 0), player, "stay_turns")
  _assert_eq(remaining, 1, "raw 0 while detained still shows 1, never 0")
end

function TestStatus3dResolve:test_passes_the_raw_counter_through_when_not_detained()
  local player = _player(2)
  local remaining = status_resolve.resolve_remaining_value({}, player, "stay_turns")
  _assert_eq(remaining, 2, "off a frozen turn the raw counter is already inclusive")
end

-- L23 `(stay_turns or 0) > 0`: a single remaining stay turn must still mark
-- the location effect active (kills `> 0` → `> 1`).
function TestStatus3dResolve:test_location_stays_active_with_exactly_one_stay_turn()
  local game = { board = _hospital_board() }
  local player = { id = 1, position = 5, status = { stay_turns = 1 } }
  _assert_eq(status_resolve.resolve_player_status_key(game, player), "hospital",
    "stay_turns == 1 must keep the location status visible")
end

-- L30 `not board or not board.get_tile`: an active location effect on a board
-- without get_tile resolves to no key rather than indexing nil (kills `or` →
-- `and`, which would call a nil get_tile).
function TestStatus3dResolve:test_active_location_with_a_board_lacking_get_tile_yields_no_key()
  local game = { board = {} }
  local player = { id = 1, position = 5, status = { stay_turns = 1 } }
  _assert_eq(status_resolve.resolve_player_status_key(game, player), nil,
    "missing board.get_tile must not produce a location status")
end

-- L58 `(deity.remaining or 0) <= 0`: a deity with one remaining turn is still
-- shown (kills `<= 0` → `<= 1`).
function TestStatus3dResolve:test_deity_with_one_remaining_turn_is_shown()
  local game = { last_turn = {} }
  local player = {
    id = 1,
    position = 5,
    status = { deity = { type = "poor", remaining = 1 } },
  }
  _assert_eq(status_resolve.resolve_player_status_key(game, player), "poor",
    "deity remaining == 1 must still resolve to its status key")
end

-- L107 `has_roadblock and has_pending`: when a roadblock stop has no pending
-- trigger but a location effect is active, location wins over roadblock
-- (kills `and` → `or`, which would short-circuit to "roadblock").
function TestStatus3dResolve:test_location_wins_over_a_stopped_roadblock_without_a_pending_trigger()
  local game = {
    board = _hospital_board(),
    last_turn = {
      player_id = 1,
      skipped = true,
      stay_turns = 2,
      move_result = { stopped_on_roadblock = true },
    },
  }
  local player = { id = 1, position = 5, status = { stay_turns = 2 } }
  _assert_eq(status_resolve.resolve_player_status_key(game, player), "hospital",
    "without a pending roadblock trigger the active location takes priority")
end

function TestStatus3dResolve:test_pending_location_effect_mismatch_hides_the_location_status()
  local game = { board = _hospital_board() }
  local player = {
    id = 1,
    position = 5,
    status = {
      stay_turns = 1,
      pending_location_effect = "mountain",
    },
  }

  _assert_eq(status_resolve.resolve_player_status_key(game, player), nil,
    "a pending effect that disagrees with the tile must not show a location status")
end

-- L79 `if not deity then return 0`: deity remaining defaults to 0 when the
-- player has no deity (kills `return 0` → `return 1`).
function TestStatus3dResolve:test_deity_remaining_is_0_when_the_player_has_no_deity()
  local player = { id = 1, status = {} }
  _assert_eq(status_resolve.resolve_remaining_value({}, player, "deity_remaining"), 0,
    "absent deity must report 0 remaining")
end

-- L120 default `return 0`: an unknown remaining field reports 0 (kills the
-- fallthrough `return 0` → `return 1`).
function TestStatus3dResolve:test_unknown_remaining_field_reports_0()
  local player = { id = 1 }
  _assert_eq(status_resolve.resolve_remaining_value({}, player, "not_a_field"), 0,
    "unrecognized remaining_field must report 0")
end

-- ===== 迁自 test/property/test_detention_inclusive_remaining.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
do
  -- Property coverage for the 扣留剩余回合 含当前回合 (inclusive) convention (CONTEXT「扣留剩余回合」).
  -- The internal stay_turns counter decrements at turn start, so the player-facing
  -- remaining count must add the current frozen turn back: while detained the
  -- displayed remaining is raw + 1, which is therefore never 0. Off a frozen turn
  -- the raw counter is already the inclusive value and passes through unchanged.
  local property = require("test.support.property")

  -- Each "not detained" case breaks exactly one detention precondition so the
  -- generator still spans the full stay_turns range on the pass-through branch.
  local function _break_detention(game, player, breaker)
    if breaker == 1 then
      game.last_turn.skipped = false
    elseif breaker == 2 then
      game.last_turn.player_id = player.id + 100
    elseif breaker == 3 then
      game.last_turn.stay_turns = nil
    else
      game.turn = {}
    end
  end

  local function _gen_case(rng)
    local stay_turns = rng:int(0, 60)
    local detained = rng:bool()
    local player = {
      id = rng:int(1, 4),
      position = rng:int(1, 40),
      status = { stay_turns = stay_turns },
    }
    local game = {
      turn = {
        no_action_notice_active = true,
        no_action_notice_player_id = player.id,
      },
      last_turn = {
        player_id = player.id,
        skipped = true,
        stay_turns = stay_turns,
      },
    }
    if not detained then
      _break_detention(game, player, rng:int(1, 4))
    end
    return { game = game, player = player, stay_turns = stay_turns, detained = detained }
  end

  local function _remaining(case)
    return status_resolve.resolve_remaining_value(case.game, case.player, "stay_turns")
  end

  function TestStatus3dResolve:test_adds_the_current_frozen_turn_back_while_detained_2()
    property.for_all(_gen_case, function(case)
      if not case.detained then
        return
      end
      lu.assertEvalToTrue(_remaining(case) == case.stay_turns + 1,
        "detained remaining must be raw stay_turns + 1")
    end)
  end

  function TestStatus3dResolve:test_never_shows_0_remaining_while_detained()
    property.for_all(_gen_case, function(case)
      if not case.detained then
        return
      end
      lu.assertEvalToTrue(_remaining(case) >= 1,
        "the inclusive count counts the current turn, so it is never 0 while detained")
    end)
  end

  function TestStatus3dResolve:test_passes_the_raw_counter_through_when_not_detained_this_turn()
    property.for_all(_gen_case, function(case)
      if case.detained then
        return
      end
      lu.assertEvalToTrue(_remaining(case) == case.stay_turns,
        "off a frozen turn the raw counter is already the inclusive value")
    end)
  end
end


return TestStatus3dResolve
