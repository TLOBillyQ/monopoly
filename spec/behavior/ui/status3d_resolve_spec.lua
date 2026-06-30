-- Direct unit coverage for src.ui.render.status3d.status_resolve, the pure
-- status-resolution module split out of status3d. Focuses on the 扣留剩余回合
-- 含当前回合 (inclusive) convention (ADR 0024): while a player is detained on the
-- current frozen turn the displayed remaining adds the current turn back, so the
-- status3d overlay shows the same count as the detention tip and never 0.
local support = require("spec.support.shared_support")
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

describe("status_resolve.resolve_remaining_value stay_turns", function()
  it("adds the current frozen turn back while detained", function()
    local player = _player(2)
    local remaining = status_resolve.resolve_remaining_value(_detained_game(1, 2), player, "stay_turns")
    _assert_eq(remaining, 3, "detained remaining must be raw stay_turns + 1 (含当前回合)")
  end)

  it("never resolves to 0 on the last frozen turn", function()
    local player = _player(0)
    local remaining = status_resolve.resolve_remaining_value(_detained_game(1, 0), player, "stay_turns")
    _assert_eq(remaining, 1, "raw 0 while detained still shows 1, never 0")
  end)

  it("passes the raw counter through when not detained", function()
    local player = _player(2)
    local remaining = status_resolve.resolve_remaining_value({}, player, "stay_turns")
    _assert_eq(remaining, 2, "off a frozen turn the raw counter is already inclusive")
  end)
end)
