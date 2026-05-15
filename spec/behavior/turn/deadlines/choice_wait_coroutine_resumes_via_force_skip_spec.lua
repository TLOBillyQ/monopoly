-- 验证：协程层在 force_skip 标志置位后下一帧立即跳出 wait
local choice_wait = require("src.turn.waits.await")

local function _build_session(game)
  local s = {
    game = game,
    choice_elapsed_seconds = 0,
    _pending = nil,
  }
  function s:mark_phase() end
  function s:take_pending_action()
    local a = self._pending
    self._pending = nil
    return a
  end
  function s:clear_pending_action()
    self._pending = nil
  end
  return s
end

local function _make_auto_play_port()
  return {
    is_auto_player = function(_, _p) return false end,
    auto_action_for_choice = function(_, _c) return nil end,
    pick_target_player = function() return nil end,
    pick_remote_dice_value = function() return nil end,
    pick_roadblock_target = function() return nil end,
  }
end

local function _build_game(choice)
  local game = {
    finished = false,
    players = { { id = 1, auto = false } },
    turn = { current_player_index = 1, pending_choice = choice },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:current_player() return self.players[1] end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do if p.id == id then return p end end
    return nil
  end
  return game
end

describe("choice wait coroutine resume via force_skip", function()
  it("returns wait when no force_skip flag and no pending action", function()
    local choice = { id = "c1", kind = "weird", options = {} }
    local game = _build_game(choice)
    local session = _build_session(game)
    local res = choice_wait.choice(session, { next_state = "next" })
    assert.is_table(res)
    assert.is_true(res.wait == true)
  end)

  it("breaks out of wait when game.turn._choice_force_skip_pending is set", function()
    local choice = { id = "c2", kind = "weird", options = {}, allow_cancel = false }
    local game = _build_game(choice)
    game.turn._choice_force_skip_pending = true
    local session = _build_session(game)
    local res = choice_wait.choice(session, { next_state = "after" })
    assert.is_table(res)
    assert.is_nil(res.wait)
    assert.equals("after", res.next_state)
    -- pending_choice 已被清
    assert.is_nil(game.turn.pending_choice)
    -- 标志被消费
    assert.is_nil(game.turn._choice_force_skip_pending)
  end)

  it("clears stale force_skip flag when pending_choice was already cleared", function()
    local game = _build_game(nil)
    game.turn._choice_force_skip_pending = true
    local session = _build_session(game)

    local first = choice_wait.choice(session, { next_state = "after_force_skip" })

    assert.equals("after_force_skip", first.next_state)
    assert.is_nil(game.turn._choice_force_skip_pending)

    game.turn.pending_choice = { id = "fresh", kind = "weird", options = {}, allow_cancel = false }
    local second = choice_wait.choice(session, { next_state = "after_fresh" })

    assert.is_table(second)
    assert.is_true(second.wait == true)
    assert.is_not_nil(game.turn.pending_choice)
  end)
end)
