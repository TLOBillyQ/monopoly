-- 验证：choice 无 allow_cancel + 无 auto_action + 无注册 fallback → force_skip 必然推进
local force_resolve = require("src.turn.deadlines.force_resolve")
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

  it("choice without allow_cancel and without registered fallback resolves via force_skip", function()
    local state = _build_state()
    local game, advanced = _build_game()
    local choice = {
      id = "c1",
      kind = "unknown_kind_no_handler",
      allow_cancel = false,
      owner_role_id = 1,
      options = {},
    }
    game.turn.pending_choice = choice
    state._game = game

    force_resolve.resolve_choice(game, state, choice, "tick_timeout")

    assert.is_nil(game.turn.pending_choice)
    assert.is_true(advanced.count >= 1)
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
end)
