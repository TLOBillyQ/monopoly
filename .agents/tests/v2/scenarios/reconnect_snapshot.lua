local state_mod = require("src.v2.domain.State")

local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _test_command_dedup()
  local service = t.new_service()
  local command = {
    seat_id = 1,
    client_seq = 7,
    issued_at = 0,
  }
  local first = t.dispatch(service, t.commands.types.next_turn, command)
  local second = t.dispatch(service, t.commands.types.next_turn, command)
  t.assert_true(first.duplicate == false, "首次命令不应去重")
  t.assert_true(second.duplicate == true, "重复命令应被去重")
end

local function _test_snapshot_replay_consistency()
  local service = t.new_service()
  t.begin_turn(service, 1, 2)
  t.progress_until_idle(service)
  t.begin_turn(service, 2, 1)
  t.progress_until_idle(service)
  t.assert_true(#service.snapshots > 0, "应创建快照")

  local before = state_mod.deep_copy(service:state())
  local rebuilt = service:recover_from_latest_snapshot()
  t.assert_true(rebuilt ~= nil, "应可从快照恢复")
  local after = service:state()
  t.assert_eq(after.turn.current_seat, before.turn.current_seat, "恢复后当前座位应一致")
  t.assert_eq(after.turn.phase, before.turn.phase, "恢复后阶段应一致")
  t.assert_eq(after.players[1].cash, before.players[1].cash, "恢复后玩家现金应一致")
end

local function _test_reconnect_freeze_resume()
  local service, runtime = t.new_service()
  t.begin_turn(service, 1, 1)
  t.assert_eq(service:state().turn.phase, "wait_move_anim", "前置失败：应在等待动画")
  runtime:set_online({ 102 })
  service:tick(0.2)
  t.assert_true(service:state().turn.frozen == true, "当前玩家离线应冻结")

  runtime:set_online({ 101, 102 })
  service:tick(0.2)
  t.assert_true(service:state().turn.frozen == false, "重连后应解冻")
end

local function _test_offline_auto_host_unfreeze()
  local service, runtime = t.new_service()
  t.begin_turn(service, 1, 1)
  runtime:set_online({ 102 })
  service:tick(0.2)
  t.assert_true(service:state().turn.frozen == true, "离线后应冻结")
  service:tick(1.2)
  t.assert_true(service:state().players[1].auto == true, "超时后应托管")
  t.assert_true(service:state().turn.frozen == false, "托管后应解冻")
end

local function _test_tick_countdown_updates()
  local service = t.new_service()
  local state = service:state()
  state.turn.phase = "wait_choice"
  state.turn.pending_interaction = {
    id = 1,
    kind = "dummy",
    options = { { id = "ok", label = "确定" } },
    meta = { owner_seat = 1 },
  }
  state.turn.choice_deadline = 1.0
  t.dispatch(service, t.commands.types.tick, { issued_at = 0.4 })
  t.assert_true(state.turn.countdown_active == true, "有选择时应显示倒计时")
  t.assert_true((state.turn.countdown_seconds or 0) > 0, "剩余时间应大于 0")
end

local function _test_archive_checkpoint_saved()
  local service, runtime = t.new_service()
  t.begin_turn(service, 1, 1)
  t.progress_until_idle(service)
  t.begin_turn(service, 2, 1)
  t.progress_until_idle(service)
  local role = runtime:find_role_by_id(101)
  t.assert_true(role ~= nil, "应找到角色")
  local has_archive = false
  for _ in pairs(role._archive or {}) do
    has_archive = true
    break
  end
  t.assert_true(has_archive, "应写入快照归档")
end

local function _test_restart_match_command()
  local service = t.new_service()
  local state = service:state()
  state.status = "finished"
  state.match.finished = true
  state.match.winner_ids = { 1 }
  t.dispatch(service, t.commands.types.restart_match, {
    seat_id = 1,
    issued_at = 0,
  })
  t.assert_true(state.status == "running", "重开后状态应恢复 running")
  t.assert_true(state.match.finished == false, "重开后 finished 应清空")
  t.assert_eq(state.turn.phase, "idle", "重开后应回到 idle")
end

return {
  { name = "reconnect/command_dedup", run = _test_command_dedup },
  { name = "reconnect/snapshot_replay_consistency", run = _test_snapshot_replay_consistency },
  { name = "reconnect/freeze_resume", run = _test_reconnect_freeze_resume },
  { name = "reconnect/offline_auto_host", run = _test_offline_auto_host_unfreeze },
  { name = "reconnect/tick_countdown", run = _test_tick_countdown_updates },
  { name = "reconnect/archive_checkpoint_saved", run = _test_archive_checkpoint_saved },
  { name = "reconnect/restart_match", run = _test_restart_match_command },
}
