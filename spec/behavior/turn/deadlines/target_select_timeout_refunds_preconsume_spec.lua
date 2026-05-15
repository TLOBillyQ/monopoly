-- 验证：道具目标选择超时后清除 _item_phase_ask_active 标志，并清空 pending_choice
local target_select_timer = require("src.turn.waits.target_select_timer")
local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  state._item_phase_ask_active = true
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
      pending_choice = { id = "tc1", kind = "item_target_tile", meta = { item_preconsumed = true, item_id = 7 }, owner_role_id = 1, options = {} },
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

describe("target select timeout", function()
  it("registers deadline when item_phase_ask_active becomes true", function()
    local state = _build_state()
    local game = _build_game()
    target_select_timer.step(game, state, 0.1)
    assert.is_true(DeadlineService.is_active(state, "target_select"))
  end)

  it("ticking past timeout clears item_phase_ask_active and pending_choice", function()
    local state = _build_state()
    local game, advanced = _build_game()
    state._game = game

    target_select_timer.step(game, state, 0.1)
    assert.is_true(DeadlineService.is_active(state, "target_select"))

    -- 推进 16 秒（超过 target_select 15s）
    DeadlineService.tick(state, 16.0)

    assert.is_nil(state._item_phase_ask_active)
    assert.is_nil(game.turn.pending_choice)
    assert.is_true(advanced.count >= 1)
  end)

  it("cancels deadline when item_phase_ask_active becomes false", function()
    local state = _build_state()
    local game = _build_game()
    target_select_timer.step(game, state, 0.1)
    state._item_phase_ask_active = false
    target_select_timer.step(game, state, 0.1)
    assert.is_false(DeadlineService.is_active(state, "target_select"))
  end)
end)
