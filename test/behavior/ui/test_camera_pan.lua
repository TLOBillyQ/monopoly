-- camera_sync 各分支行为规约:pan_camera_to_position / follow_camera /
-- sync_camera_position / 守卫分支 / release_target_pan。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):五个顶层 describe 均无嵌套、四个
-- after_each 内容完全相同(reload 端口基线),按「同层多钩子拼接」合并拍平为
-- TestCameraPan 单类 + 统一 tearDown,裸 assert(cond, msg) 机械映射为
-- lu.assertEvalToTrue,用例数与改写前一一对应(6+5+3+4+2 = 20 例)。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local runtime_state = require("src.ui.state.runtime")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local camera_sync = require("src.ui.ports.ui_sync")._camera

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_role(opts)
  opts = opts or {}
  local locked_positions = {}
  local reset_calls = 0
  return {
    set_camera_lock_position = function(pos)
      locked_positions[#locked_positions + 1] = pos
    end,
    set_camera_property = opts.set_camera_property or function() end,
    reset_camera = function()
      reset_calls = reset_calls + 1
      return true
    end,
    _locked_positions = function() return locked_positions end,
    _reset_calls = function() return reset_calls end,
  }
end

local function _make_role_with_id(role_id, opts)
  local role = _make_role(opts)
  role.get_roleid = function()
    return role_id
  end
  return role
end

local function _make_state(opts)
  opts = opts or {}
  return {
    game = {
      turn = { current_player_index = 1 },
      players = { { id = opts.local_role_id or 1 } },
    },
  }
end

TestCameraPan = {}

function TestCameraPan:tearDown()
  runtime_ports.reset_for_tests()
  -- 拆了共享端口基线必须装回,否则 mutate 车道窄 suite 子集会撞空端口(#217)
  support.restore_runtime_services()
end

function TestCameraPan:test_returns_false_when_target_pos_is_nil()
  _assert_eq(camera_sync.pan_camera_to_position(_make_state(), nil), false,
    "should return false for nil target_pos")
end

function TestCameraPan:test_returns_false_when_local_role_cannot_be_resolved()
  runtime_ports.configure({
    resolve_role = function() return nil end,
  })
  _assert_eq(camera_sync.pan_camera_to_position({}, { x = 1, y = 2 }), false,
    "should return false when no local role")
end

function TestCameraPan:test_clears_camera_target_and_locks_to_position_on_success()
  local role = _make_role()
  local camera_helper = { target_role_id = 42 }
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return camera_helper end,
  })
  local state = _make_state()
  local target = { x = 10, y = 20, z = 30 }

  local result = camera_sync.pan_camera_to_position(state, target)

  _assert_eq(result, true, "should return true on success")
  _assert_eq(camera_helper.target_role_id, nil, "should clear camera target_role_id")
  local locked = role._locked_positions()
  lu.assertEvalToTrue(#locked >= 1, "should lock camera to target position")
end

function TestCameraPan:test_works_without_camera_helper()
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()
  local target = { x = 5, y = 5, z = 5 }

  local result = camera_sync.pan_camera_to_position(state, target)

  _assert_eq(result, true, "should succeed even without camera helper")
  local locked = role._locked_positions()
  lu.assertEvalToTrue(#locked >= 1, "should still lock camera position")
end

function TestCameraPan:test_resets_camera_to_self_before_locking()
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()

  camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })

  lu.assertEvalToTrue(role._reset_calls() >= 1, "should call reset_camera")
end

function TestCameraPan:test_does_not_record_camera_failure_warnings_on_successful_reset_and_lock()
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()

  local result = camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })
  local log_once = state.debug_runtime and state.debug_runtime.log_once or {}

  _assert_eq(result, true, "should succeed")
  _assert_eq(log_once["camera_sync:reset_camera_failed"], nil, "successful reset should not warn")
  _assert_eq(log_once["camera_sync:set_camera_property_7"], nil, "successful property restore should not warn")
end

function TestCameraPan:test_returns_false_when_no_local_role_can_be_resolved()
  local followed = nil
  runtime_ports.configure({
    resolve_role = function() return nil end,
    resolve_camera_helper = function()
      return {
        follow = function(player_id)
          followed = player_id
        end,
      }
    end,
  })

  local result = camera_sync.follow_camera(_make_state(), 2)

  _assert_eq(result, false, "should fail without a local role")
  _assert_eq(followed, 2, "camera helper should still receive the target")
end

function TestCameraPan:test_returns_false_when_current_player_fallback_has_no_players_table()
  runtime_ports.configure({
    resolve_role = function()
      error("missing players table should not resolve a local role")
    end,
    resolve_camera_helper = function()
      return { follow = function() end }
    end,
  })
  local state = {
    game = {
      turn = { current_player_index = 1 },
    },
  }

  local result = camera_sync.follow_camera(state, 2)

  _assert_eq(result, false, "missing players table should not resolve local role")
end

function TestCameraPan:test_prefers_live_board_unit_position_over_role_fallback()
  local local_role = _make_role()
  local fallback_pos = { x = 99, y = 99, z = 99 }
  local live_pos = { x = 3, y = 4, z = 5 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = {
        get_position = function()
          return live_pos
        end,
      },
    },
  }
  runtime_ports.configure({
    resolve_role = function(role_id)
      if role_id == 1 then
        return local_role
      end
      if role_id == 2 then
        return {
          get_ctrl_unit = function()
            return {
              get_position = function()
                return fallback_pos
              end,
            }
          end,
        }
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { follow = function() end }
    end,
  })

  local result = camera_sync.follow_camera(state, 2)
  local locked = local_role._locked_positions()

  _assert_eq(result, true, "should lock camera to followed player")
  _assert_eq(locked[1], live_pos, "should use live board unit position")
end

function TestCameraPan:test_falls_back_to_role_position_when_board_unit_map_is_missing()
  local local_role = _make_role()
  local fallback_pos = { x = 9, y = 8, z = 7 }
  local state = _make_state()
  state.board_scene = {}
  runtime_ports.configure({
    resolve_role = function(role_id)
      if role_id == 1 then
        return local_role
      end
      if role_id == 2 then
        return {
          get_ctrl_unit = function()
            return {
              get_position = function()
                return fallback_pos
              end,
            }
          end,
        }
      end
      return nil
    end,
    resolve_camera_helper = function()
      return { follow = function() end }
    end,
  })

  local result = camera_sync.follow_camera(state, 2)
  local locked = local_role._locked_positions()

  _assert_eq(result, true, "follow should still succeed without a live unit map")
  _assert_eq(locked[1], fallback_pos, "should fall back to the role unit position")
end

-- 真机常态:宿主 role 列表拿得到时必须逐 role 判定——相机是 role 级 API,
-- 谁是被跟的目标谁 reset 回自己,其余席位锁到目标位置。只处理「本机 role」
-- 会让镜头焊在自己身上(真机 2026-07-25 复现)。
function TestCameraPan:test_locks_every_non_acting_host_role_onto_the_acting_player()
  local acting_role = _make_role_with_id(2)
  local watcher_role = _make_role_with_id(1)
  local live_pos = { x = 3, y = 4, z = 5 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return live_pos end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role, acting_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { follow = function() end } end,
  })

  local result = camera_sync.follow_camera(state, 2)

  _assert_eq(result, true, "following should succeed for the watching role")
  _assert_eq(#watcher_role._locked_positions(), 1, "watcher camera should lock once")
  _assert_eq(watcher_role._locked_positions()[1], live_pos, "watcher should look at the acting player")
  _assert_eq(#acting_role._locked_positions(), 0, "the acting role must not lock onto itself")
  _assert_eq(acting_role._reset_calls(), 1, "the acting role should reset back to its own camera")
end

-- #601:单 role 兜底链路(宿主 role 列表拿不到)的身份来源是 client_role——
-- 「上一次点击者缓存」已整体退役。多席位局跟本机角色;client_role 缺位时才
-- 兜底当前行动玩家。注意:with_patches 会先刷新 runtime 端口基线,
-- runtime_ports.configure 必须落在补丁回调内。
function TestCameraPan:test_single_role_path_follows_the_client_role_not_the_current_player()
  -- 独立 role id(42):滤波基线是模块级存活表,与上一条用例的 id 1 隔离。
  local local_role = _make_role_with_id(42)
  local live_pos = { x = 3, y = 4, z = 5 }
  local state = _make_state()
  state.game.players = { { id = 9 } } -- 当前行动玩家不是本机角色,旧兜底会解出 nil
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return live_pos end },
    },
  }

  local result
  support.with_patches({
    { target = runtime_ui, key = "get_client_role", value = function() return _make_role_with_id(42) end },
  }, function()
    runtime_ports.configure({
      resolve_role = function(id) if id == 42 then return local_role end return nil end,
      resolve_camera_helper = function() return { follow = function() end } end,
    })
    result = camera_sync.follow_camera(state, 2)
  end)

  _assert_eq(result, true, "client_role present must resolve the local role")
  _assert_eq(local_role._locked_positions()[1], live_pos,
    "the client role camera should lock onto the followed player")
end

function TestCameraPan:test_single_role_path_falls_back_to_current_player_without_client_role()
  local local_role = _make_role_with_id(1)
  local live_pos = { x = 6, y = 7, z = 8 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return live_pos end },
    },
  }

  local result
  support.with_patches({
    { target = runtime_ui, key = "get_client_role", value = function() return nil end },
  }, function()
    runtime_ports.configure({
      resolve_role = function(id) if id == 1 then return local_role end return nil end,
      resolve_camera_helper = function() return { follow = function() end } end,
    })
    result = camera_sync.follow_camera(state, 2)
  end)

  _assert_eq(result, true, "no client_role should fall back to the current player")
  _assert_eq(local_role._locked_positions()[1], live_pos,
    "the fallback role camera should lock onto the followed player")
end

function TestCameraPan:test_keeps_every_watcher_pinned_to_the_target_while_it_moves()
  local acting_role = _make_role_with_id(2)
  local watcher_role = _make_role_with_id(1)
  local live_pos = { x = 8, y = 9, z = 10 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return live_pos end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role, acting_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { target_role_id = 2 } end,
  })

  local result = camera_sync.sync_camera_position(state)

  _assert_eq(result, true, "sync should keep the watcher locked")
  _assert_eq(watcher_role._locked_positions()[1], live_pos, "watcher should track the live target position")
  _assert_eq(#acting_role._locked_positions(), 0, "the target role should never lock onto itself")
end

function TestCameraPan:test_does_not_lock_when_helper_target_is_already_the_local_role()
  local role = _make_role()
  role.get_ctrl_unit = function()
    return {
      get_position = function()
        return { x = 7, y = 8, z = 9 }
      end,
    }
  end
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function()
      return { target_role_id = 1 }
    end,
  })

  local result = camera_sync.sync_camera_position(_make_state())
  local locked = role._locked_positions()

  _assert_eq(result, false, "should not sync camera to self")
  _assert_eq(#locked, 0, "should not lock when target is local role")
end

function TestCameraPan:test_returns_false_when_camera_helper_has_no_target()
  runtime_ports.configure({
    resolve_camera_helper = function() return {} end,
  })
  _assert_eq(camera_sync.sync_camera_position(_make_state()), false,
    "should return false when camera helper target is nil")
end

function TestCameraPan:test_returns_false_when_followed_target_position_cannot_resolve()
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function(id) if id == 1 then return role end return nil end,
    resolve_camera_helper = function() return { target_role_id = 2 } end,
  })
  local result = camera_sync.sync_camera_position(_make_state())
  _assert_eq(result, false, "should return false when target position is nil")
  _assert_eq(#role._locked_positions(), 0, "should not lock without a target position")
end

function TestCameraPan:test_pan_returns_false_when_role_lacks_set_camera_lock_position()
  local role = { reset_camera = function() return true end, set_camera_property = function() end }
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  _assert_eq(camera_sync.pan_camera_to_position(_make_state(), { x = 1, y = 2, z = 3 }), false,
    "should return false when role cannot lock camera position")
end

function TestCameraPan:test_self_follow_returns_false_when_role_lacks_reset_camera()
  local role = { set_camera_lock_position = function() end, set_camera_property = function() end }
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return { follow = function() end } end,
  })
  _assert_eq(camera_sync.follow_camera(_make_state(), 1), false,
    "self-follow should return false when role cannot reset camera")
end

function TestCameraPan:test_follow_returns_false_when_player_id_is_nil()
  _assert_eq(camera_sync.follow_camera(_make_state(), nil), false,
    "nil player_id should return false")
end

function TestCameraPan:test_follow_returns_false_when_followed_player_position_cannot_resolve()
  local local_role = _make_role()
  runtime_ports.configure({
    resolve_role = function(id) if id == 1 then return local_role end return nil end,
    resolve_camera_helper = function() return { follow = function() end } end,
  })
  _assert_eq(camera_sync.follow_camera(_make_state(), 2), false,
    "should return false when follow target position is nil")
end

function TestCameraPan:test_returns_false_for_nil_state()
  _assert_eq(camera_sync.release_target_pan(nil), false, "nil state should return false")
end

function TestCameraPan:test_clears_the_follow_target_and_returns_true()
  local state = { turn_runtime = { last_follow_player_id = 99 } }
  local result = camera_sync.release_target_pan(state)
  _assert_eq(result, true, "should return true on success")
  _assert_eq(state.turn_runtime.last_follow_player_id, nil, "should clear last_follow_player_id")
end
function TestCameraPan:test_follow_switch_locks_directly_without_reset_detour()
  -- 换人回归:旁观 role 已在跟随 A,切到 B 时不得先 reset 回自己再锁 B——
  -- reset 会把镜头打回自身默认态,宿主端表现为「先跳回自己再跳到新目标」的
  -- 切换瞬间跳变(全真人局每次换人必现)。
  local watcher_role = _make_role_with_id(3)
  local pos_a = { x = 10, y = 0, z = 10 }
  local pos_b = { x = 20, y = 0, z = 20 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [1] = { get_position = function() return pos_a end },
      [2] = { get_position = function() return pos_b end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { follow = function() end } end,
  })

  camera_sync.follow_camera(state, 1)
  local locks_after_a = #watcher_role._locked_positions()
  camera_sync.follow_camera(state, 2)

  lu.assertEvalToTrue(watcher_role._reset_calls() == 0,
    "watcher must not be reset to self between follow targets")
  lu.assertEvalToTrue(#watcher_role._locked_positions() == locks_after_a + 1,
    "watcher should lock directly onto the new target")
  _assert_eq(watcher_role._locked_positions()[locks_after_a + 1], pos_b,
    "the new lock should land on the new target position")
end

function TestCameraPan:test_follow_still_resets_when_target_position_unresolvable()
  -- 兜底保持旧语义:目标位置解析不到时仍 reset 回自己并返回 false。
  local watcher_role = _make_role_with_id(3)
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { follow = function() end } end,
  })

  local result = camera_sync.follow_camera(_make_state(), 2)

  _assert_eq(result, false, "unresolvable target position should fail")
  lu.assertEvalToTrue(watcher_role._reset_calls() == 1,
    "failure path should still reset the watcher camera to self")
  lu.assertEvalToTrue(#watcher_role._locked_positions() == 0,
    "failure path should not lock onto anything")
end
function TestCameraPan:test_pan_marks_target_pan_active_until_release()
  -- pan 存活标志的置位/清位契约:pan 成功置位,release 清位。
  -- 标志是 sync_follow 在效果结算期间不重放 follow 的依据(防镜头被拽离效果地块)。
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()

  camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })
  local turn_runtime = runtime_state.ensure_turn_runtime(state)
  lu.assertEvalToTrue(turn_runtime.target_pan_active == true, "pan 成功应置 pan 存活标志")

  camera_sync.release_target_pan(state)
  lu.assertEvalToTrue(turn_runtime.target_pan_active == nil, "release 应清 pan 存活标志")
end

function TestCameraPan:test_failed_pan_does_not_mark_target_pan_active()
  runtime_ports.configure({
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()

  camera_sync.pan_camera_to_position(state, { x = 1, y = 1, z = 1 })

  local turn_runtime = state.turn_runtime
  lu.assertEvalToTrue(turn_runtime == nil or turn_runtime.target_pan_active == nil,
    "pan 失败不得置 pan 存活标志")
end

-- sync 稳态重锁滤波(#451 真机取证):旁观席位跟随中,get_position 取值有三类噪声——
-- 微漂移(1e-5/tick 永不收敛)、落格 snap 瞬移(2~5 格带 Y 回弹)、卡牌传送(数十格)。
-- 无滤波时每 tick 重锁,宿主插值反复重启,阶段切换瞬间表现为镜头 jitter。
-- 滤波基线按 role_id 做 key(真机 role 是 userdata,禁作 table key),模块级
-- 基线表跨用例存活;每个 fixture 用独立 watcher id 隔离,避免上一条用例的
-- 基线串进来把首帧判成去重/滑行。
local _sync_fixture_seq = 0
local function _make_sync_fixture()
  _sync_fixture_seq = _sync_fixture_seq + 1
  local acting_role = _make_role_with_id(2)
  local watcher_role = _make_role_with_id(100 + _sync_fixture_seq)
  local holder = { pos = { x = 0.0, y = 0.0, z = 0.0 } }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return holder.pos end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role, acting_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { target_role_id = 2 } end,
  })
  return state, watcher_role, holder
end

local function _assert_near(a, b, msg)
  assert(math.abs(a - b) < 1e-6, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

function TestCameraPan:test_sync_skips_relock_when_target_only_micro_drifts()
  -- 微漂移去重:小于阈值的取值抖动不重发,否则宿主每 tick 重启插值稳态也抖。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.sync_camera_position(state)
  holder.pos = { x = 0.000005, y = 0.000003, z = 0.0 }
  local ok = camera_sync.sync_camera_position(state)
  lu.assertEvalToTrue(ok == true, "去重命中仍应视为同步成功")
  _assert_eq(#watcher_role._locked_positions(), 1, "微漂移不应重发 lock")
end

function TestCameraPan:test_sync_tracks_normal_walk_movement_as_is()
  -- 正常行走步长(真机峰值 0.48/tick)必须原样透传,滤波不得拖累跟随。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.sync_camera_position(state)
  local walk_pos = { x = 0.3, y = 0.0, z = 0.0 }
  holder.pos = walk_pos
  camera_sync.sync_camera_position(state)
  _assert_eq(watcher_role._locked_positions()[2], walk_pos, "正常行走步长应原样透传")
end

function TestCameraPan:test_sync_glides_over_snap_discontinuity()
  -- 落格 snap 瞬移(实测 2~5 格)直接跟=镜头瞬移 jitter;滤波按 0.6/tick
  -- 滑行逼近,数 tick 后收敛到目标。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.sync_camera_position(state)
  local snap_pos = { x = 2.07, y = 0.21, z = 0.0 }
  holder.pos = snap_pos
  camera_sync.sync_camera_position(state)
  local locked = watcher_role._locked_positions()
  _assert_eq(#locked, 2, "snap 后应重锁一次")
  local dist = math.sqrt(2.07 * 2.07 + 0.21 * 0.21)
  _assert_near(locked[2].x, 2.07 * 0.6 / dist, "glide 首步 x 应按 0.6 步长截断")
  _assert_near(locked[2].y, 0.21 * 0.6 / dist, "glide 首步 y 应按 0.6 步长截断")
  camera_sync.sync_camera_position(state)
  camera_sync.sync_camera_position(state)
  camera_sync.sync_camera_position(state)
  _assert_eq(locked[#locked], snap_pos, "滑行数 tick 后应收敛到 snap 目标")
end

function TestCameraPan:test_sync_cuts_immediately_on_large_teleport()
  -- 卡牌/入狱传送(数十格)必须立即切,滑行会拖数秒。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.sync_camera_position(state)
  local far_pos = { x = 47.0, y = 0.0, z = 0.0 }
  holder.pos = far_pos
  camera_sync.sync_camera_position(state)
  _assert_eq(watcher_role._locked_positions()[2], far_pos, "大距离传送应原样立即切")
end

function TestCameraPan:test_sync_baseline_rebases_on_follow_lock()
  -- follow 换人直接锁新目标时滤波基线必须重基,否则换人后首 tick 拿旧基线
  -- 算出巨大位移,误判成传送再多跳一次。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.follow_camera(state, 2)
  _assert_eq(#watcher_role._locked_positions(), 1, "follow 应直接锁一次")
  holder.pos = { x = 0.000005, y = 0.0, z = 0.0 }
  camera_sync.sync_camera_position(state)
  _assert_eq(#watcher_role._locked_positions(), 1, "follow 后的微漂移应被去重而不是重发")
end

-- follow 重放也走滤波(#451 第三轮真机取证):dirty.turn 心跳(visual hold 等)
-- 会清 last_follow_player_id,阶段切换瞬间 follow 重放;此时目标没变但落格
-- snap 已把棋子瞬移 2~5 格,无滤波直锁 = 镜头瞬跳,滤波形同虚设(实测 glide
-- 事件 0 次、snap 跳变原样出现在发送序列)。换人cut由 teleport 档(>6)保住。
function TestCameraPan:test_follow_replay_glides_over_snap_discontinuity()
  -- 同目标 follow 重放遇 snap 瞬移:按 0.6/tick 滑行逼近,不得瞬跳。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.follow_camera(state, 2)
  holder.pos = { x = 2.07, y = 0.21, z = 0.0 }
  camera_sync.follow_camera(state, 2)
  local locked = watcher_role._locked_positions()
  _assert_eq(#locked, 2, "follow 重放应重锁一次")
  local dist = math.sqrt(2.07 * 2.07 + 0.21 * 0.21)
  _assert_near(locked[2].x, 2.07 * 0.6 / dist, "follow 重放遇 snap 应按 0.6 步长截断")
  _assert_near(locked[2].y, 0.21 * 0.6 / dist, "follow 重放遇 snap 应按 0.6 步长截断")
end

function TestCameraPan:test_follow_cuts_immediately_on_distant_target_change()
  -- 真换人(目标在数十格外)必须立即切,滤波 teleport 档原样透传。
  local state, watcher_role, holder = _make_sync_fixture()
  camera_sync.follow_camera(state, 2)
  local far_pos = { x = 47.0, y = 0.0, z = 0.0 }
  holder.pos = far_pos
  camera_sync.follow_camera(state, 2)
  _assert_eq(watcher_role._locked_positions()[2], far_pos, "远距离换人应原样立即切")
end

-- 跨局基线存活回归(#454):reset_baseline 清全部基线后,新局同 role_id +
-- 同位置首帧不得被去重,必须实际发出 lock。
function TestCameraPan:test_reset_baseline_allows_first_frame_lock_after_session_restart()
  local watcher_role = _make_role_with_id(77)
  local same_pos = { x = 5.0, y = 0.0, z = 0.0 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return same_pos end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { target_role_id = 2 } end,
  })

  -- 上局末帧:建立基线
  camera_sync.sync_camera_position(state)
  _assert_eq(#watcher_role._locked_positions(), 1, "上局末帧应建立基线")

  -- 模拟新局开局钩子
  camera_sync.reset_baseline()

  -- 新局首帧:同 role_id + 同位置,基线已清,不得去重
  camera_sync.sync_camera_position(state)
  _assert_eq(#watcher_role._locked_positions(), 2, "新局首帧应在基线清除后发送 lock")
end

-- 对照组:不调 reset_baseline 时,同 role_id + 同位置第二帧被去重(去重机制正确工作)。
function TestCameraPan:test_same_position_is_deduplicated_without_reset_baseline()
  local watcher_role = _make_role_with_id(88)
  local same_pos = { x = 5.0, y = 0.0, z = 0.0 }
  local state = _make_state()
  state.board_scene = {
    units_by_player_id = {
      [2] = { get_position = function() return same_pos end },
    },
  }
  runtime_ports.configure({
    resolve_roles = function() return { watcher_role } end,
    resolve_role = function() return nil end,
    resolve_camera_helper = function() return { target_role_id = 2 } end,
  })

  camera_sync.sync_camera_position(state)
  -- 不调 reset_baseline,第二帧同位置应被去重
  camera_sync.sync_camera_position(state)
  _assert_eq(#watcher_role._locked_positions(), 1, "不清基线时同位置第二帧应被去重")
end

-- 内部函数导出后直接覆盖分支(camera_sync._pos_components / _filter_sync_lock_value,
-- 导出先例见 turn_camera_policy._resolve_follow_player_id)。
local function _make_unreadable_pos()
  return setmetatable({}, {
    __index = function()
      error("read pos failed")
    end,
  })
end

function TestCameraPan:test_pos_components_returns_nil_for_nil_pos()
  _assert_eq(camera_sync._pos_components(nil), nil, "nil pos 应返回 nil")
end

function TestCameraPan:test_pos_components_returns_nil_when_component_read_fails()
  _assert_eq(camera_sync._pos_components(_make_unreadable_pos()), nil, "pcall 失败应返回 nil")
end

function TestCameraPan:test_pos_components_returns_nil_when_component_missing()
  _assert_eq(camera_sync._pos_components({ x = 1, y = 2 }), nil, "缺 z 分量应返回 nil")
  _assert_eq(camera_sync._pos_components({ x = 1, y = nil, z = 3 }), nil, "y 为 nil 应返回 nil")
end

function TestCameraPan:test_pos_components_returns_components_when_readable()
  local x, y, z = camera_sync._pos_components({ x = 1, y = 2, z = 3 })
  _assert_eq(x, 1, "应返回 x 分量")
  _assert_eq(y, 2, "应返回 y 分量")
  _assert_eq(z, 3, "应返回 z 分量")
end

function TestCameraPan:test_filter_sync_lock_value_passthrough_when_components_unreadable()
  -- 分量取不出时透传保持旧行为(不重发也不滤波)。
  camera_sync.reset_baseline()
  local role = _make_role_with_id(7)
  _assert_eq(camera_sync._filter_sync_lock_value(role, nil), nil, "nil 目标应原样透传")
  local unreadable = _make_unreadable_pos()
  _assert_eq(camera_sync._filter_sync_lock_value(role, unreadable), unreadable, "取不出分量应原样透传")
end

function TestCameraPan:test_pan_with_unreadable_components_skips_baseline()
  -- pan 目标分量取不出:lock 照发,但滤波基线不写(分量读不出不能当基线)。
  local role = _make_role()
  runtime_ports.configure({
    resolve_role = function() return role end,
    resolve_camera_helper = function() return nil end,
  })
  local state = _make_state()

  local ok = camera_sync.pan_camera_to_position(state, _make_unreadable_pos())

  _assert_eq(ok, true, "分量取不出的 pan 应照常成功")
  _assert_eq(#role._locked_positions(), 1, "应照常发出 lock")
end

return TestCameraPan
