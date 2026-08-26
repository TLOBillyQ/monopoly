-- #293 批3 pin:src/turn/policies/role_control.lua 无既有直测文件,4 个幸存者
-- 在锁启用判定链(_resolve_role_control_lock_enabled 的两个 false->true)与
-- sync 前置守卫链(not state or not state_ports or ... 的两个 or->and)。
-- 桩 debug_flags 同表字段与 apply_role_control_lock 间谍直测可观测面。

local lu = require("luaunit")
local role_control = require("src.turn.policies.role_control")
local debug_flags = require("src.config.gameplay.debug_flags")

local _saved_flag = debug_flags.role_control_lock_enabled

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestRoleControlPolicy = {}

function TestRoleControlPolicy:tearDown()
  debug_flags.role_control_lock_enabled = _saved_flag
end

function TestRoleControlPolicy:test_sync_applies_lock_when_flag_enabled()
  debug_flags.role_control_lock_enabled = true
  local applied = nil
  local state = {}
  local ports = {
    state = {
      apply_role_control_lock = function(s, enabled)
        applied = enabled
      end,
    },
  }
  role_control.sync({}, state, ports)
  _assert_eq(applied, true, "flag on with a live game must apply the lock")
  _assert_eq(state.turn_runtime.role_control_lock_active, true,
    "turn runtime must record the lock as active")
end

function TestRoleControlPolicy:test_sync_does_not_apply_lock_when_flag_disabled()
  -- L8 `debug_flags.role_control_lock_enabled ~= true` 的 return false -> true:
  -- 关掉 flag 必须不落锁。
  debug_flags.role_control_lock_enabled = false
  local applied = nil
  local ports = {
    state = {
      apply_role_control_lock = function(s, enabled)
        applied = enabled
      end,
    },
  }
  role_control.sync({}, {}, ports)
  lu.assertEvalToTrue(applied == nil, "flag off must not apply the lock")
end

function TestRoleControlPolicy:test_sync_does_not_apply_lock_for_finished_game()
  -- L29 `not game or game.finished` 的 return false -> true:已结束对局必须不落锁。
  debug_flags.role_control_lock_enabled = true
  local applied = nil
  local ports = {
    state = {
      apply_role_control_lock = function(s, enabled)
        applied = enabled
      end,
    },
  }
  role_control.sync({ finished = true }, {}, ports)
  lu.assertEvalToTrue(applied == nil, "finished game must not apply the lock")
end

function TestRoleControlPolicy:test_sync_tolerates_missing_state_port()
  -- L36 首个 `not state or not state_ports or ...` 的 or->and:无 state 端口时
  -- 基线提前返回;变异体求值 `not state_ports.apply_role_control_lock` 撞 nil 索引。
  debug_flags.role_control_lock_enabled = true
  role_control.sync({}, {}, {})
  lu.assertEvalToTrue(true, "missing state port must be tolerated without error")
end

function TestRoleControlPolicy:test_sync_tolerates_state_port_without_apply_function()
  -- L36 次个 `not state_ports or not state_ports.apply_role_control_lock` 的
  -- or->and:state 端口无 apply 函数时基线提前返回;变异体放行后调 nil 撞错。
  debug_flags.role_control_lock_enabled = true
  role_control.sync({}, {}, { state = {} })
  lu.assertEvalToTrue(true, "state port without apply must be tolerated without error")
end

return TestRoleControlPolicy
