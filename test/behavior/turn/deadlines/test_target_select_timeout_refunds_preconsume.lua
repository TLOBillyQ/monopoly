-- 验证：道具目标选择超时后清除 item_phase_ask 的 pending confirmation，并清空 pending_choice
local lu = require("luaunit")
local target_select_timer = require("src.turn.waits.target_select_timer")
local pending_confirmation = require("src.state.pending_confirmation")
local DeadlineService = require("src.turn.deadlines")
local runtime_state = require("src.state.runtime")

local function _build_state()
  local state = {}
  runtime_state.ensure_all(state)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
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

TestTargetSelectTimeoutRefundsPreconsume = {}

function TestTargetSelectTimeoutRefundsPreconsume:test_registers_deadline_when_item_phase_ask_active_becomes_true()
  local state = _build_state()
  local game = _build_game()
  target_select_timer.step(game, state, 0.1)
  lu.assertTrue(DeadlineService.is_active(state, "target_select"))
end

function TestTargetSelectTimeoutRefundsPreconsume:test_ticking_past_timeout_clears_item_phase_ask_active_and_pending_choice()
  local state = _build_state()
  local game, advanced = _build_game()
  state._game = game

  target_select_timer.step(game, state, 0.1)
  lu.assertTrue(DeadlineService.is_active(state, "target_select"))

  -- 推进 16 秒（超过 target_select 15s）
  DeadlineService.tick(state, 16.0)

  lu.assertFalse(pending_confirmation.is_active(state))
  lu.assertNil(game.turn.pending_choice)
  lu.assertTrue(advanced.count >= 1)
end

function TestTargetSelectTimeoutRefundsPreconsume:test_cancels_deadline_when_item_phase_ask_active_becomes_false()
  local state = _build_state()
  local game = _build_game()
  target_select_timer.step(game, state, 0.1)
  pending_confirmation.clear(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  target_select_timer.step(game, state, 0.1)
  lu.assertFalse(DeadlineService.is_active(state, "target_select"))
end


return TestTargetSelectTimeoutRefundsPreconsume
