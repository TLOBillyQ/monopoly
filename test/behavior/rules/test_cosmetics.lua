local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local runtime_ports = require("src.foundation.ports.runtime_ports")
local logger = require("src.foundation.log")
local skin_equip = require("src.rules.cosmetics")

local function _with_warn_capture(fn)
  local warns = {}
  _with_patches({
    {
      target = logger,
      key = "warn",
      value = function(message)
        warns[#warns + 1] = tostring(message)
      end,
    },
  }, function()
    fn(warns)
  end)
end

local function _with_unit(unit, fn)
  _with_patches({
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function()
        return {
          get_ctrl_unit = function()
            return unit
          end,
        }
      end,
    },
  }, fn)
end

local function _unit_with_model_recorder(calls)
  return {
    set_model_by_creature_key = function(...)
      calls[#calls + 1] = { ... }
      return true
    end,
  }
end

local function _record_operation(calls, op, ...)
  calls[#calls + 1] = { op = op, args = { ... } }
  return true
end

local function _unit_with_reset_and_model_recorder(calls)
  local unit = _unit_with_model_recorder(calls)
  unit.reset_model = function(...)
    return _record_operation(calls, "reset_model", ...)
  end
  unit.set_model_by_creature_key = function(...)
    return _record_operation(calls, "set_model_by_creature_key", ...)
  end
  return unit
end

TestCosmetics = {}

function TestCosmetics:test_applies_creature_key_to_resolved_role_unit()
  local calls = {}

  _with_unit(_unit_with_model_recorder(calls), function()
    _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should report model change success")
  end)

  _assert_eq(#calls, 1, "skin equip should call unit model setter")
  _assert_eq(calls[1][1], "skin_key", "skin equip should pass creature key")
end

function TestCosmetics:test_tries_the_host_model_setter_with_self_when_the_direct_call_fails()
  local unit
  local calls = {}
  unit = {
    set_model_by_creature_key = function(self, creature_key, include_custom_model, inherit_scale, inherit_capsule_size)
      calls[#calls + 1] = { self = self, key = creature_key }
      if self ~= unit then
        error("setter requires host self")
      end
      _assert_eq(creature_key, "skin_key", "setter should receive creature key")
      _assert_eq(include_custom_model, true, "setter should include custom model")
      _assert_eq(inherit_scale, true, "setter should inherit scale")
      _assert_eq(inherit_capsule_size, true, "setter should inherit capsule size")
      return true
    end,
  }

  _with_unit(unit, function()
    _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should retry setter with self")
  end)

  _assert_eq(#calls, 2, "skin equip should try direct setter before self fallback")
  _assert_eq(calls[2].self, unit, "skin equip should pass unit as self on fallback")
end

function TestCosmetics:test_falls_back_to_short_host_model_setter_signatures()
  local calls = {}
  local unit = {
    set_model_by_creature_key = function(...)
      local args = { ... }
      calls[#calls + 1] = args
      if #args ~= 1 then
        error("setter requires short creature-key call")
      end
      _assert_eq(args[1], "skin_key", "short setter should receive creature key")
      return true
    end,
  }

  _with_unit(unit, function()
    _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should retry short setter form")
  end)

  _assert_eq(#calls, 3, "skin equip should reach the short direct setter fallback")
end

function TestCosmetics:test_falls_back_to_short_host_model_setter_signatures_with_self()
  local unit
  local calls = {}
  unit = {
    set_model_by_creature_key = function(...)
      local args = { ... }
      calls[#calls + 1] = args
      if #args ~= 2 or args[1] ~= unit then
        error("setter requires short self call")
      end
      _assert_eq(args[2], "skin_key", "short self setter should receive creature key")
      return true
    end,
  }

  _with_unit(unit, function()
    _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should retry short self setter form")
  end)

  _assert_eq(#calls, 4, "skin equip should try all setter signatures in order")
end

function TestCosmetics:test_reports_false_when_the_role_cannot_be_resolved_or_the_model_setter_is_missing()
  _with_warn_capture(function(warns)
    _with_patches({
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function()
          return nil
        end,
      },
    }, function()
      _assert_eq(skin_equip.equip(11, "skin_key"), false, "missing role should fail equip")
      _assert_eq(skin_equip.unequip(11, "default_key"), false, "missing role should fail unequip")
    end)

    _assert_eq(#warns >= 2, true, "missing role should warn for equip and unequip")
  end)

  _with_warn_capture(function(warns)
    _with_unit({}, function()
      _assert_eq(skin_equip.equip(11, "skin_key"), false, "missing setter should fail equip")
    end)

    _assert_eq(#warns >= 1, true, "missing setter should warn")
  end)
end

function TestCosmetics:test_rejects_nil_creature_keys_before_resolving_the_role()
  local resolves = 0
  _with_warn_capture(function(warns)
    _with_patches({
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function()
          resolves = resolves + 1
          return {}
        end,
      },
    }, function()
      _assert_eq(skin_equip.equip(11, nil), false, "nil creature key should fail equip")
    end)

    _assert_eq(resolves, 0, "nil creature key should short-circuit before role lookup")
    _assert_eq(#warns, 1, "nil creature key should warn once")
  end)
end

function TestCosmetics:test_unequip_prefers_the_host_model_reset_api()
  local calls = {}

  _with_unit(_unit_with_reset_and_model_recorder(calls), function()
    _assert_eq(skin_equip.unequip(11, "default_key"), true, "skin unequip should report model reset success")
  end)

  _assert_eq(#calls, 1, "skin unequip should call one host restore method")
  _assert_eq(calls[1].op, "reset_model", "skin unequip should restore through reset_model")
end

function TestCosmetics:test_tries_the_host_model_reset_with_self_when_the_direct_call_fails()
  local unit
  local calls = {}
  unit = {
    reset_model = function(self)
      calls[#calls + 1] = { self = self }
      if self ~= unit then
        error("reset requires host self")
      end
      return true
    end,
  }

  _with_unit(unit, function()
    _assert_eq(skin_equip.unequip(11, nil), true, "skin unequip should retry reset with self")
  end)

  _assert_eq(#calls, 2, "skin unequip should try direct reset before self fallback")
  _assert_eq(calls[2].self, unit, "skin unequip should pass unit as self on reset fallback")
end

function TestCosmetics:test_unequip_falls_back_to_default_creature_when_reset_model_is_unavailable()
  local calls = {}

  _with_unit(_unit_with_model_recorder(calls), function()
    _assert_eq(skin_equip.unequip(11, "default_key"), true,
      "skin unequip should preserve the default-creature fallback")
  end)

  _assert_eq(#calls, 1, "fallback should call unit model setter once")
  _assert_eq(calls[1][1], "default_key", "fallback should pass default creature key")
end

function TestCosmetics:test_reports_false_when_unequip_cannot_reset_and_has_no_default_fallback()
  _with_warn_capture(function(warns)
    _with_unit({}, function()
      _assert_eq(skin_equip.unequip(11, nil), false,
        "skin unequip should fail without reset_model or default fallback")
    end)

    _assert_eq(#warns >= 1, true, "missing unequip fallback should warn")
  end)
end

function TestCosmetics:test_warns_when_the_default_creature_fallback_cannot_be_applied()
  local unit = {
    set_model_by_creature_key = function()
      error("setter failed")
    end,
  }

  _with_warn_capture(function(warns)
    _with_unit(unit, function()
      _assert_eq(skin_equip.unequip(11, "default_key"), false,
        "skin unequip should fail when the default fallback setter fails")
    end)

    _assert_eq(warns[#warns], "skin_equip: default creature fallback failed for player 11",
      "skin unequip should warn when the default fallback setter fails")
  end)
end

function TestCosmetics:test_warns_and_falls_back_to_the_default_creature_when_reset_model_itself_fails()
  local calls = {}
  local unit = {
    reset_model = function()
      error("reset failed")
    end,
    set_model_by_creature_key = function(...)
      calls[#calls + 1] = { ... }
      return true
    end,
  }

  _with_warn_capture(function(warns)
    _with_unit(unit, function()
      _assert_eq(skin_equip.unequip(11, "default_key"), true,
        "a failing reset_model should still recover through the default creature")
    end)

    _assert_eq(warns[1], "skin_equip: reset_model failed for player 11",
      "a failing reset_model should warn before falling back")
  end)

  _assert_eq(calls[1][1], "default_key", "fallback should apply the default creature key")
end

-- ===== 迁自 test/property/test_cosmetics_unequip.lua（#190, 测试极简化决策：property 车道退场，性质并入 behavior）=====
do
  local property = require("test.support.property")

  -- A role whose control unit records every model restore call into `calls`, and a
  -- resolve_role stub that records its own invocations into `resolves`. Both share
  -- the caller's tables so a property case can clear and re-read them in place.
  local function _patched(calls, resolves, body)
    _with_patches({
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function(role_id)
          resolves[#resolves + 1] = role_id
          return {
            get_ctrl_unit = function()
              return {
                reset_model = function(...)
                  calls[#calls + 1] = { op = "reset_model", args = { ... } }
                  return true
                end,
                set_model_by_creature_key = function(...)
                  calls[#calls + 1] = { op = "set_model_by_creature_key", args = { ... } }
                  return true
                end,
              }
            end,
          }
        end,
      },
      {
        target = logger,
        key = "warn",
        value = function() end,
      },
    }, body)
  end

  local function _patched_without_reset(calls, body)
    _with_patches({
      {
        target = runtime_ports,
        key = "resolve_role",
        value = function()
          return {
            get_ctrl_unit = function()
              return {
                set_model_by_creature_key = function(...)
                  calls[#calls + 1] = { ... }
                  return true
                end,
              }
            end,
          }
        end,
      },
    }, body)
  end

  local function _clear(t)
    for index = #t, 1, -1 do
      t[index] = nil
    end
  end

  function TestCosmetics:test_unequip_restores_through_reset_model_instead_of_setting_a_fallback_creature_key()
    local calls, resolves = {}, {}
    _patched(calls, resolves, function()
      property.for_all(function(rng)
        -- Cover both the numeric resource ids the host expects and the string
        -- creature_key form the equip wiring warns is silently ignored.
        if rng:bool() then
          return rng:int(1, 5000)
        end
        return "creature_" .. rng:int(1, 5000)
      end, function(key)
        _clear(calls)
        local equip_result = skin_equip.equip(7, key)
        local equip_call_count = #calls
        local equip_op = calls[1] and calls[1].op
        local equip_key = calls[1] and calls[1].args and calls[1].args[1]

        _clear(calls)
        local unequip_result = skin_equip.unequip(7, key)
        local unequip_call_count = #calls
        local unequip_op = calls[1] and calls[1].op

        lu.assertEvalToTrue(unequip_result == equip_result, "unequip must mirror equip's success result")
        lu.assertEvalToTrue(equip_call_count == 1 and unequip_call_count == 1,
          "equip and unequip must each invoke one host model operation")
        lu.assertEvalToTrue(equip_op == "set_model_by_creature_key" and equip_key == key,
          "equip must forward the selected creature key to the host setter")
        lu.assertEvalToTrue(unequip_op == "reset_model",
          "unequip must use the host reset API instead of reapplying a default creature")
      end)
    end)
  end

  function TestCosmetics:test_equip_rejects_nil_before_lookup_while_unequip_can_reset_without_a_fallback_key()
    local calls, resolves = {}, {}
    _patched(calls, resolves, function()
      property.for_all(function(rng)
        return rng:int(1, 100000)
      end, function(role_id)
        _clear(calls)
        _clear(resolves)
        lu.assertEvalToTrue(skin_equip.equip(role_id, nil) == false, "equip must reject a nil creature key")
        lu.assertEvalToTrue(#calls == 0, "a nil equip creature key must never reach the host model setter")
        lu.assertEvalToTrue(#resolves == 0, "the equip nil guard must short-circuit before resolving the role")

        _clear(calls)
        _clear(resolves)
        lu.assertEvalToTrue(skin_equip.unequip(role_id, nil) == true,
          "unequip should use reset_model even when no fallback creature key is configured")
        lu.assertEvalToTrue(#calls == 1 and calls[1].op == "reset_model",
          "unequip without fallback should restore through reset_model")
      end)
    end)
  end

  function TestCosmetics:test_unequip_fallback_forwards_any_configured_default_key_when_reset_model_is_unavailable()
    local calls = {}
    _patched_without_reset(calls, function()
      property.for_all(function(rng)
        if rng:bool() then
          return rng:int(1, 100000)
        end
        return "default_" .. rng:int(1, 100000)
      end, function(default_key)
        _clear(calls)

        lu.assertEvalToTrue(skin_equip.unequip(7, default_key) == true,
          "unequip fallback should succeed through the host model setter")
        lu.assertEvalToTrue(#calls == 1, "unequip fallback must call the host model setter exactly once")
        lu.assertEvalToTrue(calls[1][1] == default_key,
          "unequip fallback must forward the configured default key unchanged")
      end)
    end)
  end
end

function TestCosmetics:test_first_model_setter_attempt_carries_full_boolean_flags()
  -- #293:_try_set_model 首臂的 3 个 true 字面值(→ false 变异)未测。
  local captured
  local unit = {
    set_model_by_creature_key = function(...)
      captured = { ... }
      return true
    end,
  }
  _with_unit(unit, function()
    _assert_eq(skin_equip.equip(11, "skin_key"), true,
      "equip should succeed via the first setter arm")
  end)
  lu.assertEvalToTrue(captured ~= nil and captured[1] == "skin_key"
    and captured[2] == true and captured[3] == true and captured[4] == true,
    "first setter attempt should be (creature_key, true, true, true)")
end

function TestCosmetics:test_get_ctrl_unit_failure_logs_warn_with_role_id()
  -- #293:get_ctrl_unit 抛错路径的 warn 文案与 role_id 序列化未测。
  local log_capture = require("test.support.log_capture")
  _with_patches({
    {
      target = runtime_ports,
      key = "resolve_role",
      value = function()
        return {
          get_ctrl_unit = function() error("ctrl boom") end,
        }
      end,
    },
  }, function()
    local ok, _, captured = log_capture.capture(function()
      _assert_eq(skin_equip.equip(11, "skin_key"), false,
        "failed ctrl unit should report no model change")
    end)
    lu.assertEvalToTrue(ok == true, "equip should swallow the ctrl unit error")
    local joined = table.concat(captured.lines, "\n")
    lu.assertEvalToTrue(joined:find("get_ctrl_unit failed", 1, true) ~= nil
      and joined:find("11", 1, true) ~= nil,
      "warn should carry the failure text and role id; got " .. joined)
  end)
end


return TestCosmetics
