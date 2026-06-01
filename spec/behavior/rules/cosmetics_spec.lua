local support = require("spec.support.shared_support")
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

describe("skin_equip runtime integration", function()
  it("applies creature key to resolved role unit", function()
    local calls = {}

    _with_unit(_unit_with_model_recorder(calls), function()
      _assert_eq(skin_equip.equip(11, "skin_key"), true, "skin equip should report model change success")
    end)

    _assert_eq(#calls, 1, "skin equip should call unit model setter")
    _assert_eq(calls[1][1], "skin_key", "skin equip should pass creature key")
  end)

  it("tries the host model setter with self when the direct call fails", function()
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
  end)

  it("falls back to short host model setter signatures", function()
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
  end)

  it("falls back to short host model setter signatures with self", function()
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
  end)

  it("reports false when the role cannot be resolved or the model setter is missing", function()
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
  end)

  it("rejects nil creature keys before resolving the role", function()
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
  end)

  it("unequip prefers the host model reset API", function()
    local calls = {}

    _with_unit(_unit_with_reset_and_model_recorder(calls), function()
      _assert_eq(skin_equip.unequip(11, "default_key"), true, "skin unequip should report model reset success")
    end)

    _assert_eq(#calls, 1, "skin unequip should call one host restore method")
    _assert_eq(calls[1].op, "reset_model", "skin unequip should restore through reset_model")
  end)

  it("tries the host model reset with self when the direct call fails", function()
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
  end)

  it("unequip falls back to default creature when reset_model is unavailable", function()
    local calls = {}

    _with_unit(_unit_with_model_recorder(calls), function()
      _assert_eq(skin_equip.unequip(11, "default_key"), true,
        "skin unequip should preserve the default-creature fallback")
    end)

    _assert_eq(#calls, 1, "fallback should call unit model setter once")
    _assert_eq(calls[1][1], "default_key", "fallback should pass default creature key")
  end)

  it("reports false when unequip cannot reset and has no default fallback", function()
    _with_warn_capture(function(warns)
      _with_unit({}, function()
        _assert_eq(skin_equip.unequip(11, nil), false,
          "skin unequip should fail without reset_model or default fallback")
      end)

      _assert_eq(#warns >= 1, true, "missing unequip fallback should warn")
    end)
  end)

  it("warns when the default creature fallback cannot be applied", function()
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
  end)
end)
