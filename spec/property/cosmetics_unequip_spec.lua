local support = require("spec.support.shared_support")
local _with_patches = support.with_patches
local property = require("spec.support.property")
local logger = require("src.foundation.log")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local skin_equip = require("src.rules.cosmetics")

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

describe("skin_equip equip/unequip equivalence properties", function()
  it("unequip restores through reset_model instead of setting a fallback creature key", function()
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

        assert(unequip_result == equip_result, "unequip must mirror equip's success result")
        assert(equip_call_count == 1 and unequip_call_count == 1,
          "equip and unequip must each invoke one host model operation")
        assert(equip_op == "set_model_by_creature_key" and equip_key == key,
          "equip must forward the selected creature key to the host setter")
        assert(unequip_op == "reset_model",
          "unequip must use the host reset API instead of reapplying a default creature")
      end)
    end)
  end)

  it("equip rejects nil before lookup, while unequip can reset without a fallback key", function()
    local calls, resolves = {}, {}
    _patched(calls, resolves, function()
      property.for_all(function(rng)
        return rng:int(1, 100000)
      end, function(role_id)
        _clear(calls)
        _clear(resolves)
        assert(skin_equip.equip(role_id, nil) == false, "equip must reject a nil creature key")
        assert(#calls == 0, "a nil equip creature key must never reach the host model setter")
        assert(#resolves == 0, "the equip nil guard must short-circuit before resolving the role")

        _clear(calls)
        _clear(resolves)
        assert(skin_equip.unequip(role_id, nil) == true,
          "unequip should use reset_model even when no fallback creature key is configured")
        assert(#calls == 1 and calls[1].op == "reset_model",
          "unequip without fallback should restore through reset_model")
      end)
    end)
  end)

  it("unequip fallback forwards any configured default key when reset_model is unavailable", function()
    local calls = {}
    _patched_without_reset(calls, function()
      property.for_all(function(rng)
        if rng:bool() then
          return rng:int(1, 100000)
        end
        return "default_" .. rng:int(1, 100000)
      end, function(default_key)
        _clear(calls)

        assert(skin_equip.unequip(7, default_key) == true,
          "unequip fallback should succeed through the host model setter")
        assert(#calls == 1, "unequip fallback must call the host model setter exactly once")
        assert(calls[1][1] == default_key,
          "unequip fallback must forward the configured default key unchanged")
      end)
    end)
  end)
end)
