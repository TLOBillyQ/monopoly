-- luacheck: ignore 211
local support = require("spec.support.shared_support")
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

describe("presentation_ui.role_control_lock", function()
  it("_sync_marks_buff_api_incomplete_when_add_state_missing", function()
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

    assert(
      state.debug_runtime
        and state.debug_runtime.log_once
        and state.debug_runtime.log_once["role_control_lock:missing_buff_api_p1"] == true,
      "a unit missing add_state must be treated as buff-api-incomplete and warned"
    )
  end)

  it("_sync_marks_buff_api_incomplete_when_remove_state_missing", function()
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

    assert(
      state.debug_runtime
        and state.debug_runtime.log_once
        and state.debug_runtime.log_once["role_control_lock:missing_buff_api_p1"] == true,
      "a unit missing remove_state must be treated as buff-api-incomplete and warned"
    )
  end)

  it("_release_tolerates_nil_state_count_without_error", function()
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

    assert(ok, "release must guard with `count and count > 0` and tolerate a nil state count")
  end)

  it("_release_skips_removal_when_state_count_is_zero", function()
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
  end)

  it("_sync_keeps_lock_when_controlling_unit_unchanged", function()
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
  end)

  it("_sync_leaves_unowned_previous_unit_untouched_on_swap", function()
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
  end)

  it("_sync_preserves_unowned_flag_when_buff_already_present", function()
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
  end)

  it("_sync_does_not_lock_exempt_role_with_capable_unit", function()
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
  end)
end)
