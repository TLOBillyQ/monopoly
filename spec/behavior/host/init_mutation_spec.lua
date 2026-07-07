-- Mutation-pinning specs for src/host/init.lua host_runtime.register_custom_event.
-- State shape kept inline (per view_command_mutation_pin idiom); each test asserts
-- a value that DIFFERS between the original and one specific surviving mutant.
--
-- register_custom_event guards (L19-30):
--   L20  if type(event_name) ~= "string" or type(handler) ~= "function" then return false
--   L24  local lua_api = runtime_ctx and runtime_ctx.env and runtime_ctx.env.LuaAPI or nil
--   L25  if not (lua_api and type(lua_api.global_register_custom_event) == "function") then
--   L26    return false

local host_runtime = require("src.host.init")
local runtime_context = require("src.host.context")

-- Run fn with runtime_context.current() forced to ctx, restoring afterwards even
-- on error so a mutant crash cannot leak state into sibling tests.
local function _with_current(ctx, fn)
  local saved = runtime_context.current()
  runtime_context.set_current(ctx)
  local ok, res = pcall(fn)
  runtime_context.set_current(saved)
  if not ok then error(res, 0) end
  return res
end

describe("host_runtime.register_custom_event L20 arg-type guard (or must not become and)", function()
  it("rejects a non-string event_name even when handler is a valid function (L20 'or')", function()
    -- LuaAPI present and healthy: if the guard is bypassed, registration succeeds
    -- and the function returns true, so original (false) vs mutant (true) diverge.
    local registered = {}
    local ctx = {
      env = {
        LuaAPI = {
          global_register_custom_event = function(name, handler)
            registered[#registered + 1] = { name = name, handler = handler }
          end,
        },
      },
    }
    local result = _with_current(ctx, function()
      return host_runtime.register_custom_event(123, function() end) -- number name, fn handler
    end)
    -- Original L20: (type(123)~="string"=true) OR (type(fn)~="function"=false) -> true -> return false.
    -- Mutant  and:  true AND false -> false -> falls through -> registers -> returns true.
    assert(result == false,
      "non-string event_name must be rejected (return false); got " .. tostring(result))
    assert(#registered == 0,
      "rejected registration must not reach LuaAPI; saw " .. #registered .. " calls")
  end)
end)

describe("host_runtime.register_custom_event L25 lua_api guard (and must not become or)", function()
  it("returns false when LuaAPI lacks a callable global_register_custom_event (L25 'and')", function()
    -- lua_api is a present table, but the registration hook is NOT a function.
    -- Original short-circuits on the failed type() check and returns false.
    -- Mutant 'or' lets a truthy lua_api satisfy the guard, then tries to CALL the
    -- non-function hook and crashes -> the direct (non-pcall) call raises, which
    -- busted records as a failure, killing the mutant.
    local ctx = { env = { LuaAPI = { global_register_custom_event = 42 } } } -- not a function
    local result = _with_current(ctx, function()
      return host_runtime.register_custom_event("evt", function() end)
    end)
    -- Original L25: not(lua_api AND type(42)=="function"=false) = not(false) = true -> return false.
    -- Mutant  or:   not(lua_api OR ...) = not(truthy) = false -> proceeds -> 42(...) -> crash.
    assert(result == false,
      "missing callable hook must return false; got " .. tostring(result))
  end)
end)

describe("host_runtime.register_custom_event L26 guard-failure return (false must not become true)", function()
  it("returns false (not true) when no runtime context / LuaAPI is available (L26 'false')", function()
    -- current()=nil -> lua_api=nil -> guard fails -> hits `return false`.
    local result = _with_current(nil, function()
      return host_runtime.register_custom_event("evt", function() end)
    end)
    -- Original L26: return false. Mutant false->true: return true.
    assert(result == false,
      "unavailable LuaAPI must yield false; L26 mutation flips it to true. Got " .. tostring(result))
  end)

  it("returns true only on the genuine happy path (positive control for L26)", function()
    -- Confirms the false/true distinction is meaningful: with a healthy hook the
    -- function DOES return true, so the L26 test above is not vacuously false.
    local ctx = { env = { LuaAPI = { global_register_custom_event = function() end } } }
    local result = _with_current(ctx, function()
      return host_runtime.register_custom_event("evt", function() end)
    end)
    assert(result == true, "healthy registration must return true; got " .. tostring(result))
  end)
end)
