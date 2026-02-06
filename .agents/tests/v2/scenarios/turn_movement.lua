local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _find_one_step_pass_start_index(state)
  for index = 1, #state.board.path do
    state.players[1].position = index
    local res = t.services.movement.move(state, 1, 1, { branch_parity = 1 })
    if res.passed_start and res.passed_start > 0 then
      return index, res.to_index
    end
  end
  return nil, nil
end

local function _test_pass_start_from_movement()
  local service = t.new_service()
  local state = service:state()
  local pass_from, start_index = _find_one_step_pass_start_index(state)
  t.assert_true(pass_from ~= nil, "未找到经过起点的测试位置")
  state.players[1].position = pass_from
  local res = t.services.movement.move(state, 1, 1, { branch_parity = 1 })
  t.assert_eq(res.passed_start, 1, "经过起点应记一次奖励")
  t.assert_eq(res.to_index, start_index, "应移动到起点索引")
end

local function _test_roadblock_stop()
  local service = t.new_service()
  local state = service:state()
  state.players[1].position = 1
  state.board.overlays.roadblocks[2] = true
  local res = t.services.movement.move(state, 1, 3, { branch_parity = 3 })
  t.assert_true(res.stopped_on_roadblock == true, "应被路障拦停")
  t.assert_eq(res.to_index, 2, "停在路障位置")
end

local function _test_backward_wrap()
  local service = t.new_service()
  local state = service:state()
  state.players[1].position = 1
  local res = t.services.movement.move(state, 1, -1, {})
  t.assert_true(res.to_index ~= 1, "后退后位置应变化")
  t.assert_true(res.to_index >= 1 and res.to_index <= #state.board.path, "后退结果应在棋盘范围内")
end

local function _test_indices_in_range()
  local service = t.new_service()
  local state = service:state()
  local list = t.services.movement.indices_in_range(state, 1, 3)
  t.assert_true(#list >= 4, "前后范围应包含多个格子")
end

local function _test_next_turn_waits_move_anim()
  local service = t.new_service()
  t.begin_turn(service, 1, 1)
  local state = service:state()
  t.assert_eq(state.turn.phase, "wait_move_anim", "行动后应等待移动动画确认")
  t.assert_true(state.turn.move_anim ~= nil, "应生成 move_anim")
end

local function _test_move_anim_done_advances_phase()
  local service = t.new_service()
  t.begin_turn(service, 1, 1)
  local state = service:state()
  local seq = state.turn.move_anim and state.turn.move_anim.seq
  t.dispatch(service, t.commands.types.move_anim_done, {
    seat_id = 1,
    issued_at = 0.1,
    payload = { seq = seq },
  })
  state = service:state()
  t.assert_true(state.turn.phase ~= "wait_move_anim", "确认后应离开 wait_move_anim")
end

local function _test_pass_start_bonus_applied_in_kernel()
  local service = t.new_service()
  local state = service:state()
  local pass_from = _find_one_step_pass_start_index(state)
  t.assert_true(pass_from ~= nil, "未找到经过起点的测试位置")
  state.players[1].position = pass_from
  local before = state.players[1].cash
  t.begin_turn(service, 1, 1)
  t.progress_until_idle(service)
  t.assert_true(state.players[1].cash > before, "经过起点应获得金币奖励")
end

local function _test_autorun_single_turn_to_idle()
  local service = t.new_service()
  t.begin_turn(service, 1, 2)
  t.progress_until_idle(service)
  local state = service:state()
  t.assert_eq(state.turn.phase, "idle", "自动推进后应回到 idle")
  t.assert_eq(state.turn.current_seat, 2, "应切到下一玩家")
end

return {
  { name = "turn/pass_start_movement", run = _test_pass_start_from_movement },
  { name = "turn/roadblock_stop", run = _test_roadblock_stop },
  { name = "turn/backward_wrap", run = _test_backward_wrap },
  { name = "turn/indices_in_range", run = _test_indices_in_range },
  { name = "turn/next_turn_wait_move_anim", run = _test_next_turn_waits_move_anim },
  { name = "turn/move_anim_done_advances", run = _test_move_anim_done_advances_phase },
  { name = "turn/pass_start_bonus_in_kernel", run = _test_pass_start_bonus_applied_in_kernel },
  { name = "turn/autorun_to_idle", run = _test_autorun_single_turn_to_idle },
}
