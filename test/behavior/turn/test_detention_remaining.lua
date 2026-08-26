-- Detention "remaining turns" use the 含当前回合 (inclusive) convention (CONTEXT「扣留剩余回合」):
-- the player-visible 扣留剩余回合 counts the current frozen turn, so it is never 0
-- while detained. The internal stay_turns counter still decrements at turn start
-- (pinned by the 减后回合 legacy acceptance scenario); the player-facing tip must show the
-- pre-decrement value so a 2-turn hospital stay reads 2, then 1 — never 0.
local support = require("test.support.shared_support")
local _new_game = support.new_game
local _assert_eq = support.assert_eq
local start_phase = require("src.turn.phases.start")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_log = require("src.state.event_log")
local number_utils = require("src.foundation.number")

local _config_reset = require("test.support.config_reset")

local function _latest_detained_remaining(game)
  local shown
  for _, entry in ipairs(event_log.get_entries(game.state.event_log)) do
    if entry.kind == event_kinds.detained then
      shown = tostring(entry.text):match("剩余回合[:：]%s*(%d+)")
    end
  end
  return shown and number_utils.to_integer(shown) or nil
end

local function _detained_remaining_for(stay_turns)
  local game = _new_game()
  local player = game:current_player()
  game:set_player_status(player, "stay_turns", stay_turns)
  start_phase({ game = game })
  return _latest_detained_remaining(game)
end

TestDetentionRemaining = {}

function TestDetentionRemaining:setUp()
  _config_reset.reset_all()
end

function TestDetentionRemaining:test_first_frozen_turn_of_a_2_turn_stay_shows_inclusive_remaining_2()
  _assert_eq(_detained_remaining_for(2), 2,
    "tip on the first frozen turn must show 2 (含当前回合), not the decremented 1")
end

function TestDetentionRemaining:test_last_frozen_turn_of_a_2_turn_stay_shows_inclusive_remaining_1_never_0()
  _assert_eq(_detained_remaining_for(1), 1,
    "tip on the last frozen turn must show 1 (含当前回合), not the decremented 0")
end


return TestDetentionRemaining
