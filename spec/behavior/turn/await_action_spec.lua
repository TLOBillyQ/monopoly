local await = require("src.turn.waits.await")
local auto_play_port = require("src.rules.ports.auto_play")

local function _make_session(opts)
  opts = opts or {}
  local pending_actions = opts.pending_actions or {}
  local idx = 0
  local s = {
    game = opts.game or {
      turn = { phase = "wait_action" },
      players = { { id = 1, name = "P1", cash = 0, eliminated = false } },
      current_player = function(self) return self.players[self.turn.current_player_index or 1] end,
    },
    _phase = nil,
    _cleared = false,
  }
  function s:mark_phase(p) self._phase = p end
  function s:clear_pending_action() self._cleared = true end
  function s:peek_pending_action()
    return pending_actions[idx + 1]
  end
  function s:take_pending_action()
    idx = idx + 1
    return pending_actions[idx]
  end
  return s
end

local function _call_action(session, args)
  return await.action(session, args)
end

describe("await.action", function()
  before_each(function()
    package.loaded["src.rules.ports.auto_play"] = nil
    package.loaded["src.turn.waits.await"] = nil
  end)
  after_each(function()
    package.loaded["src.rules.ports.auto_play"] = nil
    package.loaded["src.turn.waits.await"] = nil
  end)

  it("_test_auto_player_returns_action_next_immediately", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return true end }
    local aw = require("src.turn.waits.await")
    local session = _make_session()
    local result = aw.action(session, { next_state = "roll", next_args = { player = session.game.players[1] } })
    assert(type(result) == "table", "should return table")
    assert(result.wait ~= true, "auto player should not wait")
    assert(result.next_state == "roll", "next_state preserved from args")
  end)

  it("_test_choice_select_action_peeked_returns_action_next", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    local session = _make_session({
      pending_actions = { { type = "choice_select", choice_id = "c1" } },
    })
    local result = aw.action(session, { next_state = "roll", next_args = {} })
    assert(type(result) == "table", "should return table")
    assert(result.wait ~= true, "choice_select peeked should not wait")
    assert(result.next_state == "roll", "next_state from args")
  end)

  it("_test_choice_cancel_action_peeked_returns_action_next", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    local session = _make_session({
      pending_actions = { { type = "choice_cancel", choice_id = "c1" } },
    })
    local result = aw.action(session, { next_state = "item_phase", next_args = {} })
    assert(type(result) == "table", "should return table")
    assert(result.wait ~= true, "choice_cancel peeked should not wait")
    assert(result.next_state == "item_phase", "next_state from args")
  end)

  it("_test_choice_force_skip_peeked_returns_action_next", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    local session = _make_session({
      pending_actions = { { type = "choice_force_skip" } },
    })
    local result = aw.action(session, { next_state = "end_turn", next_args = {} })
    assert(type(result) == "table" and result.wait ~= true, "choice_force_skip should not wait")
  end)

  it("_test_non_choice_action_taken_returns_action_next", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    local session = _make_session({
      pending_actions = { { type = "ui_button", id = "next" } },
    })
    local result = aw.action(session, { next_state = "roll", next_args = {} })
    assert(type(result) == "table" and result.next_state == "roll", "non-choice action taken should proceed")
    assert(result.wait ~= true, "should not wait after taking action")
  end)

  it("_test_no_pending_action_returns_wait", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    local session = _make_session({ pending_actions = {} })
    local result = aw.action(session, { next_state = "roll", next_args = {} })
    assert(type(result) == "table" and result.wait == true, "no action should return WAIT")
  end)

  it("_test_nil_args_uses_default_roll_next_state", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return true end }
    local aw = require("src.turn.waits.await")
    local session = _make_session()
    local result = aw.action(session, nil)
    assert(type(result) == "table", "should return table with nil args")
    assert(result.next_state == "roll", "default next_state is 'roll': " .. tostring(result.next_state))
  end)

  it("_test_non_choice_peeked_action_falls_through_to_take", function()
    package.loaded["src.rules.ports.auto_play"] = { is_auto_player = function() return false end }
    local aw = require("src.turn.waits.await")
    -- peek returns ui_button (not a choice action), take_pending_action returns it
    local session = _make_session({
      pending_actions = { { type = "ui_button", id = "next" } },
    })
    local result = aw.action(session, { next_state = "roll", next_args = {} })
    -- peek sees ui_button → _is_choice_action = false → take action → not nil → return next
    assert(result.wait ~= true, "non-choice peek should take action and proceed")
  end)
end)
