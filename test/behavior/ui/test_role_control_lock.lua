-- luacheck: ignore 211
local lu = require("luaunit")

local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local role_control_lock_policy = require("src.ui.input.role_control_lock")

local function _with_buff_enums(buff_id, fn)
  local original = _G.Enums
  _G.Enums = { BuffState = { BUFF_FORBID_CONTROL = buff_id } }
  local ok, err = pcall(fn)
  _G.Enums = original
  if not ok then
    error(err)
  end
end

local function _single_role_runtime(unit, role_id)
  return {
    for_each_role_or_global = function(fn)
      fn({ get_ctrl_unit = function() return unit end })
    end,
    resolve_role_id = function() return role_id end,
  }
end

TestRoleControlLock = {}

function TestRoleControlLock:test__sync_falls_back_to_tostring_role_id_when_resolve_fails()
  -- kills L149 `resolve_role_id(role) or tostring(role)` -> `or nil`:
  -- resolve_role_id 失败时锁键退化 nil,角色根本不被锁(role_id==nil 提前 return)。
  local buff_calls = {}
  local unit = {
    get_state_count = function()
      return 0
    end,
    add_state = function(_, buff_id)
      buff_calls[#buff_calls + 1] = { op = "add", buff = buff_id }
    end,
    remove_state = function()
      buff_calls[#buff_calls + 1] = { op = "remove" }
    end,
  }
  local role = { get_ctrl_unit = function()
    return unit
  end }
  local deps = {
    runtime = {
      for_each_role_or_global = function(fn)
        fn(role)
      end,
      resolve_role_id = function()
        return nil
      end,
    },
  }
  local state = {}
  _with_buff_enums("BUFF_FORBID_CONTROL", function()
    role_control_lock_policy.sync(state, true, deps)
  end)
  _assert_eq(#buff_calls, 1, "the fallback tostring id must still lock the role (kills `or tostring(role)` -> `or nil`)")
  _assert_eq(buff_calls[1].op, "add", "the fallback path acquires the control buff")
end

-- presentation_ui.role_control_lock
function TestRoleControlLock:test__sync_marks_buff_api_incomplete_when_add_state_missing()
  -- Pins L21 `_can_apply` chain `... and unit.add_state ...`: an `or` mutant treats a unit that
  -- has get_state_count but no add_state as usable and skips the warning.
  local unit = {
    get_state_count = function() return 1 end,
    remove_state = function() end,
  }
  local state = { role_control_lock = { by_role = {} } }

  _with_buff_enums(70, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(unit, "p1") })
  end)

  lu.assertEvalToTrue(
    state.debug_runtime
      and state.debug_runtime.log_once
      and state.debug_runtime.log_once["role_control_lock:missing_buff_api_p1"] == true,
    "a unit missing add_state must be treated as buff-api-incomplete and warned"
  )
end

function TestRoleControlLock:test__sync_marks_buff_api_incomplete_when_remove_state_missing()
  -- Pins L22 `_can_apply` chain `... and unit.remove_state`: an `or` mutant treats a unit that
  -- lacks remove_state as usable and skips the warning.
  local unit = {
    get_state_count = function() return 1 end,
    add_state = function() end,
  }
  local state = { role_control_lock = { by_role = {} } }

  _with_buff_enums(71, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(unit, "p1") })
  end)

  lu.assertEvalToTrue(
    state.debug_runtime
      and state.debug_runtime.log_once
      and state.debug_runtime.log_once["role_control_lock:missing_buff_api_p1"] == true,
    "a unit missing remove_state must be treated as buff-api-incomplete and warned"
  )
end

function TestRoleControlLock:test__release_tolerates_nil_state_count_without_error()
  -- Pins L30 `if count and count > 0`: an `or` mutant evaluates `nil > 0` and raises.
  local stale = {
    get_state_count = function() return nil end,
    remove_state = function() end,
  }
  local state = { role_control_lock = { by_role = { p1 = { owned = true, unit = stale } } } }

  local ok = pcall(function()
    _with_buff_enums(72, function()
      role_control_lock_policy.sync(state, false, {
        runtime = { for_each_role_or_global = function() end },
      })
    end)
  end)

  lu.assertEvalToTrue(ok, "release must guard with `count and count > 0` and tolerate a nil state count")
end

function TestRoleControlLock:test__release_skips_removal_when_state_count_is_zero()
  -- Pins L30 `count > 0`: a `>=` mutant removes the buff even when the count is already 0.
  local removed = 0
  local stale = {
    get_state_count = function() return 0 end,
    remove_state = function() removed = removed + 1 end,
  }
  local state = { role_control_lock = { by_role = { p1 = { owned = true, unit = stale } } } }

  _with_buff_enums(73, function()
    role_control_lock_policy.sync(state, false, {
      runtime = { for_each_role_or_global = function() end },
    })
  end)

  _assert_eq(removed, 0, "a state count of 0 must not trigger remove_state (strict > 0)")
end

function TestRoleControlLock:test__sync_keeps_lock_when_controlling_unit_unchanged()
  -- Pins L41 first `and` (`entry.unit and entry.unit ~= unit ...`): an `or` mutant releases the
  -- buff even when the controlling unit is the same one already tracked.
  local removed = 0
  local unit = {
    get_state_count = function() return 1 end,
    add_state = function() end,
    remove_state = function() removed = removed + 1 end,
  }
  local state = { role_control_lock = { by_role = { p1 = { owned = true, unit = unit } } } }

  _with_buff_enums(74, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(unit, "p1") })
  end)

  _assert_eq(removed, 0, "re-syncing the same controlling unit must not release its buff")
end

function TestRoleControlLock:test__sync_leaves_unowned_previous_unit_untouched_on_swap()
  -- Pins L41 second `and` (`... ~= unit and entry.owned`): an `or` mutant releases a previous
  -- unit's buff on swap even though we never owned it.
  local removed = 0
  local old_unit = {
    get_state_count = function() return 1 end,
    add_state = function() end,
    remove_state = function() removed = removed + 1 end,
  }
  local new_unit = {
    get_state_count = function() return 0 end,
    add_state = function() end,
    remove_state = function() end,
  }
  local state = { role_control_lock = { by_role = { p1 = { owned = false, unit = old_unit } } } }

  _with_buff_enums(75, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(new_unit, "p1") })
  end)

  _assert_eq(removed, 0,
    "a previously unowned unit must not be released when the controlling unit changes")
end

function TestRoleControlLock:test__sync_preserves_unowned_flag_when_buff_already_present()
  -- Pins L55 `entry.owned = entry.owned == true`: a `== false` mutant flips an unowned entry to
  -- owned when the buff is already applied.
  local unit = {
    get_state_count = function() return 1 end,
    add_state = function() end,
    remove_state = function() end,
  }
  local state = { role_control_lock = { by_role = { p1 = { owned = false, unit = unit } } } }

  _with_buff_enums(76, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(unit, "p1") })
  end)

  _assert_eq(state.role_control_lock.by_role.p1.owned, false,
    "a buff we did not add must stay unowned (entry.owned == true)")
end

function TestRoleControlLock:test__sync_does_not_lock_exempt_role_with_capable_unit()
  -- Pins L113 exempt read (`read(...) == true`), L114 `exempt or not unit`, and L143
  -- `state.role_control_lock_exempt_by_role or {}`: each mutant would lock an exempt role that
  -- has a fully-capable control unit.
  local added = 0
  local unit = {
    get_state_count = function() return 0 end,
    add_state = function() added = added + 1 end,
    remove_state = function() end,
  }
  local state = {
    role_control_lock = { by_role = {} },
    role_control_lock_exempt_by_role = { p1 = true },
  }

  _with_buff_enums(77, function()
    role_control_lock_policy.sync(state, true, { runtime = _single_role_runtime(unit, "p1") })
  end)

  _assert_eq(added, 0, "an exempt role with a capable ctrl unit must not receive the control-lock buff")
  _assert_eq(state.role_control_lock.by_role.p1, nil, "an exempt role must not create a lock entry")
end


return TestRoleControlLock
