-- TurnScheduler 公开接口集成行为：所有推进均经 run_turn/dispatch/step/reset。

local check = require("luassert")
local support = require("test.support.shared_support")
local turn_runtime = require("src.turn.scheduler")
local landing_visual_hold = require("src.state.visual_hold")
local wait_callbacks = require("src.turn.waits.callback_registry")
local market_choice = require("src.rules.market.choice")

describe("TestSchedulerRuntime", function()

after_each(function()
  -- 清了共享 tips 基线必须装回,否则 mutate 车道窄 suite 子集撞空 presenter(#217)
  support.restore_runtime_services()
end)

it("test_coroutine_mode_full_turn_lifecycle", function()
  local g = support.new_game()
  local visited = {}

  g.turn_runtime = turn_runtime:new(g, {
    start = function(_, args)
      visited[#visited + 1] = "start"
      return "roll", { player = g:current_player() }
    end,
    roll = function(_, args)
      visited[#visited + 1] = "roll"
      return "move", args
    end,
    move = function(_, args)
      visited[#visited + 1] = "move"
      return "landing", args
    end,
    landing = function(_, args)
      visited[#visited + 1] = "landing"
      return "post_action", args
    end,
    post_action = function(_, args)
      visited[#visited + 1] = "post_action"
      return "end_turn", args
    end,
    end_turn = function()
      visited[#visited + 1] = "end_turn"
      return nil
    end,
  })

  g:advance_turn()

  local expected = { "start", "roll", "move", "landing", "post_action", "end_turn" }
  check.is_truthy(#visited == #expected,
    "should visit all " .. #expected .. " phases, got " .. #visited)
  for i, name in ipairs(expected) do
    check.is_truthy(visited[i] == name,
      "phase " .. i .. " should be " .. name .. " got " .. tostring(visited[i]))
  end
end)

it("test_coroutine_mode_landing_visual_done_does_not_leak_into_wait_choice", function()
  local g = support.new_game()
  landing_visual_hold.start(g)

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      return "wait_landing_visual", { next_state = "wait_choice", next_args = { next_state = "done", next_args = {} } }
    end,
    done = function()
      return nil
    end,
  })

  local _, tile_ref = support.first_land_tile(g.board)
  local choice = support.open_choice(g, {
    kind = "landing_optional_effect",
    route_key = "base_inline",
    title = "购买地块？",
    options = { { id = "buy_land", label = "购买" } },
    meta = { player_id = g:current_player().id, tile_id = tile_ref.id },
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_landing_visual", "should park at wait_landing_visual with the choice open")

  -- #197：视觉完成信号只应释放视觉等待。landing_visual 的 await 此前不消费
  -- pending action,残留的 landing_visual_done 在 wait_choice 被当作决策输入
  -- 喂给 resolver,触发 "landing_optional_effect requires string action.option_id"。
  g:dispatch_action({ type = "landing_visual_done" })

  check.same(g.turn.phase, "wait_choice", "visual release should hand off to wait_choice")
  check.is_truthy(g.turn.pending_choice ~= nil and g.turn.pending_choice.id == choice.id,
    "non-choice signal must not resolve the pending choice")
end)

it("test_coroutine_mode_resolves_detained_wait", function()
  local g = support.new_game()

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      g.turn.detained_wait_active = true
      return "detained_wait", {}
    end,
    end_turn = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "detained_wait", "should enter detained_wait")

  -- still active -> should stay waiting
  g:advance_turn()
  check.same(g.turn.phase, "detained_wait", "should stay in detained_wait while active")

  -- clear detained -> should proceed to end_turn and finish
  g.turn.detained_wait_active = false
  g:advance_turn()
  check.is_truthy(g.turn.phase ~= "detained_wait", "should leave detained_wait when cleared")
end)

it("test_coroutine_mode_resolves_inter_turn_wait", function()
  local g = support.new_game()

  g.turn_runtime = turn_runtime:new(g, {
    start = function(_, args)
      if args and args.resumed == true then
        return "done", {}
      end
      g.turn.inter_turn_wait_active = true
      return "inter_turn_wait", { resumed = true }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "inter_turn_wait", "should enter inter_turn_wait")

  g:advance_turn()
  check.same(g.turn.phase, "inter_turn_wait", "should stay in inter_turn_wait while active")

  g.turn.inter_turn_wait_active = false
  g:advance_turn()
  check.same(g.turn.current_player_index, 2, "inter_turn_wait should advance to next player before restart")
  check.is_truthy(g.turn.phase ~= "inter_turn_wait", "should leave inter_turn_wait when cleared")
end)

it("test_coroutine_mode_resolves_wait_action", function()
  local g = support.new_game({ ai = { [2] = true } })

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      return "wait_action", {
        player = g:current_player(),
        next_state = "done",
        next_args = {},
      }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_action", "human player should enter wait_action")

  g:advance_turn()
  check.same(g.turn.phase, "wait_action", "tick advance without action should stay in wait_action")

  g:dispatch_action({ type = "ui_button", id = "next" })
  check.is_truthy(g.turn.phase ~= "wait_action", "dispatch action should leave wait_action")
end)

it("test_coroutine_mode_resolves_wait_action_anim", function()
  local g = support.new_game()
  local anim_seq = 99

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      g.turn.action_anim = { seq = anim_seq, kind = "roll", player_id = g:current_player().id }
      return "wait_action_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_action_anim", "should enter wait_action_anim")

  -- wrong seq -> should stay waiting
  g:dispatch_action({ type = "action_anim_done", seq = 1 })
  check.same(g.turn.phase, "wait_action_anim", "wrong seq should keep waiting")

  -- correct seq -> should advance
  g:dispatch_action({ type = "action_anim_done", seq = anim_seq })
  check.is_truthy(g.turn.phase ~= "wait_action_anim", "correct seq should leave wait_action_anim")
end)

it("test_coroutine_mode_resolves_wait_landing_visual", function()
  local g = support.new_game()
  landing_visual_hold.start(g)

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      return "wait_landing_visual", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_landing_visual", "should enter wait_landing_visual")
  check.is_truthy(wait_callbacks.is_wait_ready(g, "landing_visual") == true, "wait_landing_visual should arm release callback")

  g:advance_turn()
  check.is_truthy(g.turn.phase ~= "wait_landing_visual", "second advance should leave wait_landing_visual")
  check.same(g.turn.landing_visual_release_pending, true, "wait_landing_visual should mark release pending")
end)

it("test_coroutine_mode_resolves_wait_move_anim", function()
  local g = support.new_game()
  local move_seq = 42

  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      g.turn.move_anim = { seq = move_seq, player_id = g:current_player().id }
      return "wait_move_anim", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_move_anim", "should enter wait_move_anim")

  -- wrong seq -> should stay waiting
  g:dispatch_action({ type = "move_anim_done", seq = 999 })
  check.same(g.turn.phase, "wait_move_anim", "wrong seq should keep waiting")

  -- correct seq -> should advance
  g:dispatch_action({ type = "move_anim_done", seq = move_seq })
  check.is_truthy(g.turn.phase ~= "wait_move_anim", "correct seq should leave wait_move_anim")
end)

it("test_market_close_after_purchase_skips_market_reveal_wait", function()
  local g = support.new_game()
  local p = g:current_player()
  g:set_player_cash(p, 999999)
  g.anim_gate_port = { wait_action_anim = true, wait_move_anim = false }
  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      return "wait_choice", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  local choice = market_choice.builder.build(p, g, { active_tab = "item", page_index = 1 })
  choice.id = 311
  g.turn.pending_choice = choice
  g:advance_turn()

  g:dispatch_action({
    type = "choice_select",
    choice_id = choice.id,
    option_id = choice.options[1].id,
    actor_role_id = p.id,
  })
  check.is_truthy(g.turn.pending_choice ~= nil and g.turn.pending_choice.kind == "market_buy",
    "market purchase should keep the market choice open")
  check.is_truthy(g.turn.action_anim and g.turn.action_anim.kind == "item_gain_popup",
    "market purchase should queue an item reveal before closing")

  g:dispatch_action({
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = p.id,
  })

  check.is_nil(g.turn.pending_choice, "market close should clear pending choice")
  check.is_nil(g.turn.action_anim, "market close should clear market reveal animation")
  check.is_truthy(g.turn.phase ~= "wait_action_anim", "market close should not wait for reveal animation")
end)

it("test_turn_runtime_coroutine_mode_resolves_wait_choice", function()
  local g = support.new_game()
  g.turn_runtime = turn_runtime:new(g, {
    start = function()
      return "wait_choice", { next_state = "done", next_args = {} }
    end,
    done = function()
      return nil
    end,
  })

  local choice = support.open_choice(g, {
    kind = "item_phase_passive",
    route_key = "base_inline",
    uses_item_slots = true,
    pre_confirm_before_slot_pick = true,
    title = "行动前：使用道具？",
    options = { { id = 2001, label = "路障卡" } },
    allow_cancel = true,
    cancel_label = "结束阶段",
    meta = {
      phase = "pre_action",
      player_id = g:current_player().id,
    },
  })

  g:advance_turn()
  check.same(g.turn.phase, "wait_choice", "coroutine turn_runtime should enter wait_choice")

  g:dispatch_action({
    type = "choice_cancel",
    choice_id = choice.id,
    actor_role_id = g:current_player().id,
  })

  check.is_nil(g.turn.pending_choice, "choice_cancel should clear pending choice in coroutine mode")
  check.is_truthy(g.turn.phase ~= "wait_choice", "coroutine mode should leave wait_choice after cancel")
end)


end)
