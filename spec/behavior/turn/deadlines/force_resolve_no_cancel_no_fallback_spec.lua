-- 验证：choice 无 allow_cancel + 无 auto_action + 无注册 fallback → force_skip 必然推进
local force_resolve = require("src.turn.deadlines")
local fallback_registry = require("src.rules.choice.fallback_registry")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  return state
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

local function _build_game()
  local advanced = { count = 0 }
  local game = {
    finished = false,
    players = { { id = 1, auto = false } },
    turn = {
      current_player_index = 1,
      pending_choice = nil,
    },
    dirty = { any = false, turn = false },
    auto_play_port = _make_auto_play_port(),
  }
  function game:advance_turn()
    advanced.count = advanced.count + 1
  end
  function game:current_player()
    return self.players[1]
  end
  function game:find_player_by_id(id)
    for _, p in ipairs(self.players) do
      if p.id == id then return p end
    end
    return nil
  end
  return game, advanced
end

describe("force_resolve no cancel no fallback", function()
  before_each(function()
    fallback_registry.reset()
  end)

  it("force_skip clears pending_choice and sets force_skip flag", function()
    local state = _build_state()
    local game = _build_game()
    local choice = { id = "c2", kind = "weird", options = {} }
    game.turn.pending_choice = choice

    force_resolve.force_skip(game, state, choice, "test")

    assert.is_nil(game.turn.pending_choice)
    assert.is_true(state._choice_force_skip_pending == true)
  end)

  it("force_skip clears ui state output port and all choice deadlines", function()
    local state = _build_state()
    local game, advanced = _build_game()
    local clear_calls = 0
    local choice = { id = "c3", kind = "market_buy", options = {} }
    state._item_phase_ask_active = true
    state._resolved_gameplay_loop_ports = {
      output = {
        clear_pending_choice = function(state_arg)
          clear_calls = clear_calls + 1
          assert.equals(state, state_arg)
        end,
      },
    }
    game.turn.pending_choice = choice

    force_resolve.start(state, "choice", { timeout_seconds = 10 })
    force_resolve.start(state, "market_buy", { timeout_seconds = 10 })
    force_resolve.start(state, "target_select", { timeout_seconds = 10 })
    force_resolve.start(state, "modal_popup", { timeout_seconds = 10 })

    force_resolve.force_skip(game, state, choice, "test")

    assert.equals(1, clear_calls)
    assert.is_nil(state._item_phase_ask_active)
    assert.is_true(game.turn._choice_force_skip_pending == true)
    assert.is_nil(game.turn.pending_choice)
    assert.is_false(force_resolve.is_active(state, "choice"))
    assert.is_false(force_resolve.is_active(state, "market_buy"))
    assert.is_false(force_resolve.is_active(state, "target_select"))
    assert.is_false(force_resolve.is_active(state, "modal_popup"))
    assert.equals(1, advanced.count)
  end)

  it("force_skip ignores malformed output port and nil state safely", function()
    local state = _build_state()
    local game = _build_game()
    state._resolved_gameplay_loop_ports = {
      output = {
        clear_pending_choice = "not a function",
      },
    }
    game.turn.pending_choice = { id = "c4", kind = "weird", options = {} }

    local ok, err = pcall(force_resolve.force_skip, game, state, game.turn.pending_choice, "test")
    assert.is_true(ok, tostring(err))
    assert.is_nil(game.turn.pending_choice)

    ok, err = pcall(force_resolve.force_skip, { finished = true, turn = {} }, nil, nil, "test")
    assert.is_true(ok, tostring(err))
  end)

  it("force_skip tolerates nil game and missing output ports", function()
    local state = _build_state()
    state._item_phase_ask_active = true

    local ok, err = pcall(force_resolve.force_skip, nil, state, { id = "c6", kind = "weird" }, "test")

    assert.is_true(ok, tostring(err))
    assert.is_nil(state._item_phase_ask_active)
  end)

  it("force_skip does not advance a finished game", function()
    local state = _build_state()
    local game, advanced = _build_game()
    game.finished = true

    force_resolve.force_skip(game, state, { id = "c5", kind = "weird", options = {} }, "test")

    assert.equals(0, advanced.count)
  end)
end)
