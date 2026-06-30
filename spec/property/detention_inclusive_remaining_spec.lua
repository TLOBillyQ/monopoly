-- Property coverage for the 扣留剩余回合 含当前回合 (inclusive) convention (ADR 0024).
-- The internal stay_turns counter decrements at turn start, so the player-facing
-- remaining count must add the current frozen turn back: while detained the
-- displayed remaining is raw + 1, which is therefore never 0. Off a frozen turn
-- the raw counter is already the inclusive value and passes through unchanged.
local property = require("spec.support.property")
local status_resolve = require("src.ui.render.status3d.status_resolve")

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

describe("detention remaining stays inclusive (含当前回合, ADR 0024)", function()
  it("adds the current frozen turn back while detained", function()
    property.for_all(_gen_case, function(case)
      if not case.detained then
        return
      end
      assert(_remaining(case) == case.stay_turns + 1,
        "detained remaining must be raw stay_turns + 1")
    end)
  end)

  it("never shows 0 remaining while detained", function()
    property.for_all(_gen_case, function(case)
      if not case.detained then
        return
      end
      assert(_remaining(case) >= 1,
        "the inclusive count counts the current turn, so it is never 0 while detained")
    end)
  end)

  it("passes the raw counter through when not detained this turn", function()
    property.for_all(_gen_case, function(case)
      if case.detained then
        return
      end
      assert(_remaining(case) == case.stay_turns,
        "off a frozen turn the raw counter is already the inclusive value")
    end)
  end)
end)
