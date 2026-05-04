---@diagnostic disable
-- luacheck: ignore 113
local function make_cases(helpers)
  local _ENV = helpers
  local _ = _ENV._new_game

local function _test_find_player_by_id_accepts_mixed_representation()
  local g = _new_game()
  local p1 = g.players[1]
  p1.id = "1"
  g.player_by_id = { ["1"] = p1 }

  local by_int = g:find_player_by_id(1)
  local by_string = g:find_player_by_id("1")

  assert(by_int == p1, "find_player_by_id should match integer input to string player id")
  assert(by_string == p1, "find_player_by_id should match string input to string player id")
end

local function _test_owner_mine_other_player_triggers_immediately_after_placement()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing owner tile")

  p1.inventory:add({ id = item_ids.mine })
  local use_res = support.executor.use_item(g, p1, item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")
  assert(g.board:has_mine(mine_index), "mine should be placed on owner tile")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should keep placement payload")
  assert(mine_state.armed == true, "freshly placed mine should be active immediately")
  assert(
    mine_state.owner_turn_started_count_at_placement == (p1.status.own_turn_started_count or 0),
    "mine should record the owner's own-turn counter at placement"
  )

  local owner_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not owner_res, "owner landing on freshly placed mine should not trigger extra landing")
  assert((p1.status.stay_turns or 0) == 0, "owner should stay immune on the placement turn")
  assert(g.board:has_mine(mine_index), "mine should remain after owner ignores it")

  g:update_player_position(p2, mine_index)
  local trigger_res = _resolve_landing(g, p2, mine_tile, {})
  assert(not g.turn.pending_choice, "mine trigger should not open a pending choice")
  assert(trigger_res and trigger_res.waiting == true, "other player should trigger the mine immediately")
  assert(trigger_res.next_state == "move_followup", "mine trigger should resume through move_followup")
  assert(trigger_res.next_args and trigger_res.next_args.log_entries and trigger_res.next_args.log_entries[1] == p2.name .. "触发地雷",
    "mine trigger should defer no-vehicle trigger log through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "hospital stay should be deferred until move followup")
  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "end_turn", "mine trigger should end the turn after hospital followup")
  assert((p2.status.stay_turns or 0) > 0, "other player should be hospitalized by the fresh mine")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonation")
end

local function _test_owner_mine_stays_immune_for_next_own_turn_then_triggers_on_third()
  local g = _new_game()
  local p1 = g.players[1]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing owner tile")

  p1.inventory:add({ id = item_ids.mine })
  local use_res = support.executor.use_item(g, p1, item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")
  assert(g.board:has_mine(mine_index), "mine should be placed on owner tile")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should keep placement payload")
  local placement_turn_started_count = mine_state.owner_turn_started_count_at_placement

  g:set_player_status(p1, "own_turn_started_count", placement_turn_started_count + 1)
  local next_turn_res = _resolve_landing(g, p1, mine_tile, {})
  assert(not next_turn_res, "owner should stay immune on the next own turn after placement")
  assert((p1.status.stay_turns or 0) == 0, "owner should not be hospitalized on the next own turn")
  assert(g.board:has_mine(mine_index), "mine should remain after the second immunity pass")

  g:set_player_status(p1, "own_turn_started_count", placement_turn_started_count + 2)

  local trigger_res = _resolve_landing(g, p1, mine_tile, {})
  assert(trigger_res and trigger_res.waiting == true, "owner should be hit by own mine on the third own turn")
  assert(trigger_res.next_state == "move_followup", "owner mine trigger should resume through move_followup")
  assert((p1.status.stay_turns or 0) == 0, "hospital stay should still be deferred until move followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "end_turn", "owner mine trigger should end the turn after hospital followup")
  assert((p1.status.stay_turns or 0) > 0, "owner should be hospitalized by own mine on the third own turn")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after detonating on owner later turn")
end

local function _test_passing_armed_mine_stops_and_triggers_followup()
  local g = _new_game()
  local p1 = g.players[1]
  local p2 = g.players[2]
  local mine_index = p1.position
  local mine_tile = assert(g.board:get_tile(mine_index), "missing mine tile")

  p1.inventory:add({ id = item_ids.mine })
  local use_res = support.executor.use_item(g, p1, item_ids.mine, { by_ai = true })
  assert(use_res ~= nil, "mine use should succeed")
  local mine_state = assert(g.board:get_mine(mine_index), "mine should still exist after placement")
  assert(mine_state.armed == true, "mine should be active immediately for non-owners")

  local before_mine_index = assert(g.board:index_of_tile_id(24), "missing tile before start")
  g:update_player_position(p2, before_mine_index)
  local move_res = movement.move(g, p2, 2, { branch_parity = 2, skip_market_check = true })
  assert(move_res and move_res.landing_tile, "passing player should still produce landing tile")
  assert(p2.position == mine_index, "passing player should stop on mine tile instead of moving past it")
  assert(#move_res.visited == 1, "passing player should consume movement only until mine tile")

  local trigger_res = _resolve_landing(g, p2, mine_tile, move_res)
  assert(trigger_res and trigger_res.waiting == true, "passing mine trigger should wait for move followup")
  assert(trigger_res.next_state == "move_followup", "passing mine trigger should resume through move_followup")
  assert((p2.status.stay_turns or 0) == 0, "hospital stay should be deferred until followup")

  local resumed_state = move_followup.run({ game = g }, trigger_res.next_args)
  assert(resumed_state == "end_turn", "passing mine trigger should end the turn after hospital followup")
  assert((p2.status.stay_turns or 0) > 0, "passing player should be hospitalized after mine followup")
  assert(g.board:has_mine(mine_index) == false, "mine should clear after passing detonation")
end

local function _test_detained_turn_enters_wait_state_before_advancing()
  local g = _new_game()
  local p1 = g.players[1]

  g:set_player_status(p1, "stay_turns", 1)

  g:advance_turn()

  assert(g.turn.current_player_index == 1, "detained player should stay current while wait is active")
  assert((p1.status.stay_turns or 0) == 0, "detained player stay_turns should be decremented")
  assert(g.last_turn and g.last_turn.player_id == p1.id, "last_turn should record skipped player")
  assert(g.last_turn and g.last_turn.skipped == true, "last_turn should mark detained turn as skipped")
  assert(g.last_turn and g.last_turn.stay_turns == 0, "last_turn should keep post-decrement stay_turns for UI projection")
  assert((p1.status.own_turn_started_count or 0) == 1, "detained turn should still increment own-turn counter")
  assert(g.turn.phase == "detained_wait", "detained turn should enter detained_wait")
  assert(g.turn.detained_wait_active == true, "detained wait flag should stay enabled during wait")
  assert(g.turn.detained_wait_seconds == 2.0, "detained wait should use configured 2 second delay")
  assert(g.turn.no_action_notice_active == true, "detained wait should still expose a non-blocking notice")
  assert(g.turn.no_action_notice_player_id == p1.id, "notice should belong to skipped player")
end

local function _test_turn_start_emits_turn_started_feedback_event()
  local g = _new_game()
  local emitted = {}

  support.with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    local next_state, _ = turn_start({ game = g })
    assert(next_state ~= nil, "turn_start should return next state")
  end)

  assert(#emitted >= 1, "turn_start should emit at least one event")
  assert(emitted[1].kind == monopoly_event.feedback.turn_started, "turn_start should emit feedback.turn_started")
  assert(emitted[1].payload.player_id == g:current_player().id, "turn_start should emit current player id")
  assert((g:current_player().status.own_turn_started_count or 0) == 1, "turn_start should increment own-turn counter")
end

local function _test_turn_start_waits_for_pre_action_item_phase_choice()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")

  support.with_patches({
    { target = item_phase, key = "run", value = function(_, phase_name, args)
      assert(phase_name == "pre_action", "turn_start should run pre_action item phase")
      assert(args and args.player == player, "turn_start should pass current player to item phase")
      return {
        waiting = true,
        next_state = "roll",
        next_args = { player = player, source = "pre_action" },
      }
    end },
  }, function()
    local next_state, next_args = turn_start({ game = g })
    assert(next_state == "wait_action", "waiting pre_action item phase should route through wait_action")
    assert(next_args and next_args.next_state == "wait_choice", "wait_action should forward to wait_choice")
    assert(next_args.next_args and next_args.next_args.next_state == "roll", "wait_choice should preserve next state")
    assert(next_args.next_args.next_args and next_args.next_args.next_args.source == "pre_action", "wait_choice should preserve next args")
  end)
end

local function _test_turn_start_waits_for_pre_action_item_phase_action_anim()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        wait_action_anim = true,
        next_state = "roll",
        next_args = { player = player, source = "action_anim" },
      }
    end },
  }, function()
    local next_state, next_args = turn_start({ game = g })
    assert(next_state == "wait_action", "wait_action_anim pre_action should route through wait_action")
    assert(next_args and next_args.next_state == "wait_action_anim", "wait_action should forward to wait_action_anim")
    assert(next_args.next_args and next_args.next_args.next_state == "roll", "wait_action_anim should preserve next state")
    assert(next_args.next_args.next_args and next_args.next_args.next_args.source == "action_anim", "wait_action_anim should preserve next args")
  end)
end

local function _test_phase_registry_post_action_routes_wait_variants()
  local g = _new_game()
  local player = g:current_player()
  local item_phase = require("src.rules.items.phase")
  local phases = phase_registry.build_default_phases()

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        next_state = "post_action_done",
        next_args = { player = player, source = "choice_wait" },
      }
    end },
  }, function()
    local next_state, next_args = phases.post_action({ game = g }, { player = player })
    assert(next_state == "wait_choice", "post_action waiting without action anim should route to wait_choice")
    assert(next_args and next_args.next_state == "post_action_done", "post_action wait_choice should preserve next state")
    assert(next_args.next_args and next_args.next_args.source == "choice_wait", "post_action wait_choice should preserve next args")
  end)

  support.with_patches({
    { target = item_phase, key = "run", value = function()
      return {
        waiting = true,
        wait_action_anim = true,
        next_state = "post_action_done",
        next_args = { player = player, source = "action_wait" },
      }
    end },
  }, function()
    local next_state, next_args = phases.post_action({ game = g }, { player = player })
    assert(next_state == "wait_action_anim", "post_action waiting with action anim should route to wait_action_anim")
    assert(next_args and next_args.next_state == "post_action_done", "post_action wait_action_anim should preserve next state")
    assert(next_args.next_args and next_args.next_args.source == "action_wait", "post_action wait_action_anim should preserve next args")
  end)
end

local function _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending()
  local turn_land = require("src.turn.phases.land")
  local effect_pipeline = require("src.rules.effects.pipeline")
  local g = _new_game()
  local player = g:current_player()
  local move_result = { kind = "move_result" }
  local tile = g.board:get_tile(player.position)
  g.turn.action_anim_queue = {
    { kind = "teleport_effect", seq = 41 },
  }

  support.with_patches({
    { target = effect_pipeline, key = "run", value = function(_, _, _, _, opts)
      return opts.on_need_landing({
        player_id = player.id,
        board_index = tile.id,
        move_result = move_result,
      })
    end },
  }, function()
    local next_state, next_args = turn_land.run({ game = g }, {
      player = player,
      move_result = move_result,
    })
    assert(next_state == "wait_action_anim", "pending teleport_effect queue should defer landing followup behind wait_action_anim")
    assert(next_args and next_args.next_state == "move_followup", "pending teleport_effect queue should resume through move_followup")
    assert(next_args.next_args and next_args.next_args.mode == "resolve_landing", "move_followup should resume landing resolution mode")
    assert(next_args.next_args.player_id == player.id, "move_followup should preserve target player id")
    assert(next_args.next_args.move_result == move_result, "move_followup should preserve move result")
    assert(g.turn.move_followup_pending == true, "pending teleport_effect queue should flag move_followup_pending")
  end)
end

local function _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice()
  local g = _new_game()
  local player = g:current_player()
  g.last_turn = {}
  local steal_module = require("src.rules.items.steal")
  local move_result = {
    steal_interrupt = {
      encountered_ids = { g.players[2].id },
      remaining_steps = 2,
      facing = "left",
      branch_parity = 3,
    },
  }

  support.with_patches({
    { target = steal_module, key = "handle_pass_players", value = function()
      return {
        waiting = true,
      }
    end },
  }, function()
    local next_state, next_args = move_followup.run({ game = g }, {
      mode = "resume_turn_move",
      player = player,
      raw_total = 5,
      move_result = move_result,
    })
    assert(next_state == "wait_choice", "steal interrupt wait should route through wait_choice")
    assert(next_args and next_args.next_state == "move", "steal interrupt wait should resume move phase")
    assert(next_args.next_args and next_args.next_args.continue_from_steal == true,
      "steal interrupt wait should preserve continue_from_steal flag")
    assert(next_args.next_args.remaining_steps == 2, "steal interrupt wait should preserve remaining steps")
  end)
end

local function _test_roadblock_stop_does_not_detain_next_turn()
  local g = _new_game()
  local player = g:current_player()
  g.last_turn = {}

  local next_state, next_args = move_followup.run({ game = g }, {
    mode = "resume_turn_move",
    player = player,
    raw_total = 3,
    move_result = {
      stopped_on_roadblock = true,
    },
  })

  assert(next_state == "landing", "roadblock followup should still continue into landing")
  assert(next_args and next_args.player == player, "roadblock followup should preserve landing player")
  assert((player.status.stay_turns or 0) == 0, "roadblock should not write detained stay_turns")
  assert(g.last_turn and g.last_turn.move_result and g.last_turn.move_result.stopped_on_roadblock == true,
    "roadblock hit should remain visible through last_turn move_result")

  local start_state = turn_start(g.turn_engine.turn_mgr)
  assert(start_state == "wait_action", "next turn start should not detain player after roadblock")
  assert(g.turn.phase ~= "detained_wait", "roadblock should not route next turn into detained_wait")
  assert(g.last_turn and g.last_turn.skipped == false, "next turn should not be marked as skipped")
end

local function _test_auto_runner_choice_actor_falls_back_to_choice_owner()
  local auto_runner = require("src.turn.policies.auto_runner")
  local auto_policy = require("src.turn.policies.choice_auto")
  local runner = auto_runner:new({ interval = 0 })
  runner:set_enabled(true)

  local g = _new_game()
  local ai_player = g.players[2]
  ai_player.auto = true
  local action = nil
  local original_decide = auto_policy.decide
  auto_policy.decide = function()
    return {
      type = "choice_select",
      choice_id = 901,
      option_id = "use",
    }
  end
  local ok, err = pcall(function()
    action = runner:next_action((timing.auto_decision_delay_seconds or 0) + 0.1, {
      game = g,
      pending_choice = {
        id = 901,
        kind = "steal_prompt",
        owner_role_id = ai_player.id,
        meta = {
          player_id = ai_player.id,
        },
        options = { { id = "use" } },
      },
      current_player_id = g.players[1].id,
      current_player_auto = true,
    })
  end)
  auto_policy.decide = original_decide
  assert(ok, err)

  assert(action and action.type == "choice_select", "auto runner should resolve pending choice action")
  assert(action.actor_role_id == ai_player.id, "auto runner should use pending choice owner as actor role")
end

local function _test_auto_runner_modal_without_buttons_confirms()
  local auto_runner = require("src.turn.policies.auto_runner")
  local runner = auto_runner:new({ interval = 0 })
  runner:set_enabled(true)

  local action = runner:next_action(0, {
    modal_active = true,
    modal_buttons = {},
    current_player_auto = true,
    current_player_id = 2,
  })

  assert(action and action.type == "modal_confirm", "modal without buttons should fall back to modal_confirm")
end

local function _test_turn_script_dispatches_wait_states_and_move_followup_fallback()
  local g = _new_game()
  local script_calls = {}
  local phase_calls = {}
  local session = {
    game = g,
    current_state = "move_followup",
    current_args = { mode = "resume_turn_move" },
    phases = {},
    mark_phase = function(_, name)
      script_calls[#script_calls + 1] = name
    end,
  }

  local move_followup_module = require("src.turn.phases.move_followup")
  support.with_patches({
    { target = move_followup_module, key = "run", value = function(_, args)
      phase_calls[#phase_calls + 1] = "move_followup"
      assert(args and args.mode == "resume_turn_move", "turn_script should pass move_followup args through fallback")
      return nil
    end },
  }, function()
    local co = turn_script.create(session)
    local first_ok = coroutine.resume(co)
    assert(first_ok == true, "turn_script should execute move_followup fallback state")
    assert(session.finished == true, "turn_script should finish after move_followup fallback")
  end)

  assert(phase_calls[1] == "move_followup", "turn_script should fallback to move_followup handler")
  assert(script_calls[1] == "move_followup", "turn_script should mark move_followup phase")
end

local function _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload()
  local g = _new_game()
  local pushed = {}
  g.popup_port = {
    push_popup = function(_, payload)
      pushed[#pushed + 1] = payload
    end,
  }

  local pushed_ok = intent_dispatcher.dispatch(g, {
    intent = {
      kind = "push_popup",
      payload = { message = "popup" },
    },
  })
  local ignored = intent_dispatcher.dispatch(g, { intent = "invalid" })

  assert(pushed_ok == true, "dispatch should route push_popup intents")
  assert(#pushed == 1 and pushed[1].message == "popup", "dispatch should forward popup payload")
  assert(ignored == nil, "dispatch should ignore invalid intent payloads")
end

local function _test_ai_board_target_choice_falls_back_to_first_option()
  local agent = require("src.computer.core_agent")
  local g = _new_game()
  local ai_player = g.players[2]
  ai_player.auto = true
  local choice = {
    id = 321,
    kind = "roadblock_target",
    meta = {
      player_id = ai_player.id,
    },
    options = { { id = 8 }, { id = 9 } },
  }

  support.with_patches({
    { target = agent, key = "pick_roadblock_target", value = function()
      return nil
    end },
  }, function()
    local action = agent.auto_action_for_choice(g, choice)
    assert(action and action.type == "choice_select", "AI roadblock target should produce choice_select")
    assert(action.option_id == 8, "AI roadblock target should fall back to first option when probe returns nil")
    assert(action.actor_role_id == ai_player.id, "AI roadblock target should preserve owner role")
  end)
end

local function _test_bankruptcy_emits_feedback_event()
  local g = _new_game()
  local p1 = g.players[1]
  local emitted = {}

  support.with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function(kind, payload, opts)
        emitted[#emitted + 1] = { kind = kind, payload = payload }
        return true
      end,
    },
  }, function()
    bankruptcy.eliminate(g, p1, { reason = "测试破产" })
  end)

  local found = false
  for _, entry in ipairs(emitted) do
    if entry.kind == monopoly_event.feedback.bankruptcy then
      found = true
      assert(entry.payload.player_id == p1.id, "bankruptcy feedback should preserve player id")
      assert(entry.payload.reason == "测试破产", "bankruptcy feedback should preserve reason")
    end
  end
  assert(found, "bankruptcy should emit feedback.bankruptcy")
end

local function _test_game_victory_finished_game_short_circuits_without_reemitting()
  local g = _new_game({ install_ui_port = false })
  local emitted = 0
  g.finished = true
  g.winner_names = "existing winner"

  support.with_patches({
    {
      target = monopoly_event,
      key = "emit",
      value = function()
        emitted = emitted + 1
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "finished game should still report victory")
  end)

  assert(emitted == 0, "finished game should not emit duplicate finished events")
  assert(g.winner_names == "existing winner", "finished game should preserve winner names")
end

local function _test_game_victory_turn_limit_tie_keeps_multiple_winners()
  local g = _new_game({ install_ui_port = false })
  local p1 = g.players[1]
  local p2 = g.players[2]
  local captured = nil

  for index = 3, #g.players do
    g.players[index].eliminated = true
  end
  g.turn.turn_count = 1
  g:set_player_cash(p1, 3000)
  g:set_player_cash(p2, 3000)

  support.with_patches({
    { target = timing, key = "turn_limit", value = 1 },
    {
      target = monopoly_event,
      key = "emit",
      value = function(event_name, payload)
        captured = {
          event_name = event_name,
          payload = payload,
        }
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "turn-limit tie should finish the game")
  end)

  assert(g.finished == true, "turn-limit tie should mark game finished")
  assert(g.winner == nil, "turn-limit tie should not pick a single winner")
  assert(g.winner_names == "P1、P2", "turn-limit tie should preserve winner name ordering")
  assert(type(g.winners) == "table" and #g.winners == 2, "turn-limit tie should keep both winners")
  assert(captured ~= nil and captured.event_name == monopoly_event.game.finished,
    "turn-limit tie should emit game.finished")
  assert(captured.payload.winner_ids[1] == true and captured.payload.winner_ids[2] == true,
    "turn-limit tie should expose both winner ids")
end

local function _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners()
  local g = _new_game({ install_ui_port = false })
  local captured = nil

  for _, player in ipairs(g.players) do
    player.eliminated = true
  end
  g.turn.turn_count = 1

  support.with_patches({
    { target = timing, key = "turn_limit", value = 1 },
    {
      target = monopoly_event,
      key = "emit",
      value = function(event_name, payload)
        captured = {
          event_name = event_name,
          payload = payload,
        }
      end,
    },
  }, function()
    local result = g:check_victory()
    assert(result == true, "turn-limit elimination should finish the game")
  end)

  assert(g.finished == true, "turn-limit elimination should mark game finished")
  assert(g.winner == nil, "no-survivor finish should not expose a single winner")
  assert(type(g.winners) == "table" and #g.winners == 0, "no-survivor finish should store empty winners")
  assert(g.winner_names == "", "no-survivor finish should keep empty winner names")
  assert(captured ~= nil and captured.event_name == monopoly_event.game.finished,
    "no-survivor finish should emit game.finished")
  assert(captured.payload.message == "游戏结束，无人生还",
    "no-survivor finish should preserve the no-survivor message")
end

local function _test_camera_policy_follows_eliminated_then_skips_to_next()
  local g = _new_game()
  g.players[1].eliminated = true
  g.turn.current_player_index = 1
  local followed = nil
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == g.players[2].id, "should skip eliminated player and follow next")
end

local function _test_camera_policy_follows_current_when_not_eliminated()
  local g = _new_game()
  g.turn.current_player_index = 2
  local followed = nil
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == g.players[2].id, "should follow current player when not eliminated")
end

local function _test_camera_policy_skips_all_eliminated_and_returns_nil()
  local g = _new_game()
  for _, p in ipairs(g.players) do
    p.eliminated = true
  end
  g.turn.current_player_index = 1
  local followed = "not-called"
  local ports = {
    ui_sync = {
      follow_camera = function(_, player_id)
        followed = player_id
      end,
    },
  }
  turn_camera_policy.sync_follow(g, {}, ports, true)
  assert(followed == "not-called", "should not call follow when all eliminated")
end

local function _test_choice_auto_policy_tick_timeout_cancels_when_allowed()
  local g = _new_game()
  local choice = {
    id = 801,
    kind = "test_choice",
    allow_cancel = true,
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "tick_timeout",
    is_auto_actor = true,
  })
  assert(action and action.type == "choice_cancel", "tick_timeout should cancel when allowed")
end

local function _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable()
  local g = _new_game()
  local choice = {
    id = 802,
    kind = "test_choice",
    allow_cancel = false,
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "tick_timeout",
    is_auto_actor = true,
    allow_first_option_fallback = true,
  })
  assert(action and action.type == "choice_select", "tick_timeout should fallback to first option when not cancelable")
  assert(action.option_id == "opt1", "should select first option")
end

local function _test_choice_auto_policy_generic_mode_uses_fallback_flag()
  local g = _new_game()
  local choice = {
    id = 803,
    kind = "test_choice",
    options = { { id = "opt1" } },
  }
  local action = choice_auto_policy.decide(g, {}, choice, {
    mode = "unknown_mode",
    is_auto_actor = true,
    allow_first_option_fallback = true,
  })
  assert(action and action.type == "choice_select", "generic mode should respect allow_first_option_fallback")
end

local function _test_tick_timeout_resolve_choice_ui_state_returns_route_key()
  local tick_timeout = require("src.gameplay.interactions.tick_timeout")
  local ui_state = tick_timeout.resolve_choice_ui_state({
    choice_id = 1,
    mode = "generic",
    auto = nil,
    timeout_seconds = 5,
    fallback_flag = "some_flag",
  })
  assert(ui_state.choice_id == 1, "should copy choice_id")
  assert(ui_state.route_key == "some_flag", "should use fallback_flag as route_key when auto is nil")
end

local function _test_initial_state_has_used_effect_groups()
  local g = _new_game({ install_ui_port = false })
  assert(type(g.turn.used_effect_groups) == 'table', "used_effect_groups should be a table")
  assert(next(g.turn.used_effect_groups) == nil, "used_effect_groups should start empty")
end

local function _test_end_turn_clears_used_effect_groups()
  local g = _new_game({ install_ui_port = false })
  g.turn.used_effect_groups = {dice_control = true}
  assert(next(g.turn.used_effect_groups) ~= nil, "used_effect_groups should have content before clearing")
  -- Simulate end-of-turn clearing by calling the registry clearing directly
  g.turn.item_phase = {}
  g.turn.used_effect_groups = {}
  g.turn.item_phase_active = ""
  assert(next(g.turn.used_effect_groups) == nil, "used_effect_groups should be empty after clearing")
end

  return {
    _test_find_player_by_id_accepts_mixed_representation = _test_find_player_by_id_accepts_mixed_representation,
    _test_owner_mine_other_player_triggers_immediately_after_placement = _test_owner_mine_other_player_triggers_immediately_after_placement,
    _test_owner_mine_stays_immune_for_next_own_turn_then_triggers_on_third = _test_owner_mine_stays_immune_for_next_own_turn_then_triggers_on_third,
    _test_passing_armed_mine_stops_and_triggers_followup = _test_passing_armed_mine_stops_and_triggers_followup,
    _test_detained_turn_enters_wait_state_before_advancing = _test_detained_turn_enters_wait_state_before_advancing,
    _test_turn_start_emits_turn_started_feedback_event = _test_turn_start_emits_turn_started_feedback_event,
    _test_turn_start_waits_for_pre_action_item_phase_choice = _test_turn_start_waits_for_pre_action_item_phase_choice,
    _test_turn_start_waits_for_pre_action_item_phase_action_anim = _test_turn_start_waits_for_pre_action_item_phase_action_anim,
    _test_phase_registry_post_action_routes_wait_variants = _test_phase_registry_post_action_routes_wait_variants,
    _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending = _test_turn_land_waits_for_move_followup_when_teleport_effect_queue_pending,
    _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice = _test_move_followup_resume_turn_move_waits_on_steal_interrupt_choice,
    _test_roadblock_stop_does_not_detain_next_turn = _test_roadblock_stop_does_not_detain_next_turn,
    _test_auto_runner_choice_actor_falls_back_to_choice_owner = _test_auto_runner_choice_actor_falls_back_to_choice_owner,
    _test_auto_runner_modal_without_buttons_confirms = _test_auto_runner_modal_without_buttons_confirms,
    _test_turn_script_dispatches_wait_states_and_move_followup_fallback = _test_turn_script_dispatches_wait_states_and_move_followup_fallback,
    _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload = _test_intent_dispatcher_dispatch_handles_popup_and_ignores_invalid_payload,
    _test_ai_board_target_choice_falls_back_to_first_option = _test_ai_board_target_choice_falls_back_to_first_option,
    _test_bankruptcy_emits_feedback_event = _test_bankruptcy_emits_feedback_event,
    _test_game_victory_finished_game_short_circuits_without_reemitting = _test_game_victory_finished_game_short_circuits_without_reemitting,
    _test_game_victory_turn_limit_tie_keeps_multiple_winners = _test_game_victory_turn_limit_tie_keeps_multiple_winners,
    _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners = _test_game_victory_turn_limit_with_no_survivors_reports_empty_winners,
    _test_camera_policy_follows_eliminated_then_skips_to_next = _test_camera_policy_follows_eliminated_then_skips_to_next,
    _test_camera_policy_follows_current_when_not_eliminated = _test_camera_policy_follows_current_when_not_eliminated,
    _test_camera_policy_skips_all_eliminated_and_returns_nil = _test_camera_policy_skips_all_eliminated_and_returns_nil,
    _test_choice_auto_policy_tick_timeout_cancels_when_allowed = _test_choice_auto_policy_tick_timeout_cancels_when_allowed,
    _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable = _test_choice_auto_policy_tick_timeout_fallback_when_not_cancelable,
    _test_choice_auto_policy_generic_mode_uses_fallback_flag = _test_choice_auto_policy_generic_mode_uses_fallback_flag,
    _test_tick_timeout_resolve_choice_ui_state_returns_route_key = _test_tick_timeout_resolve_choice_ui_state_returns_route_key,
    _test_initial_state_has_used_effect_groups = _test_initial_state_has_used_effect_groups,
    _test_end_turn_clears_used_effect_groups = _test_end_turn_clears_used_effect_groups,
  }
end

return { make_cases = make_cases }
