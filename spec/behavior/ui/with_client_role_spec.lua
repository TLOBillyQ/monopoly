local with_client_role = require("src.ui.utils.with_client_role")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

describe("with_client_role", function()
  it("delegates to runtime.with_client_role when present", function()
    local called_role, called_fn
    local fn = function() return "result" end
    local runtime = {
      with_client_role = function(r, f)
        called_role = r
        called_fn = f
        return f()
      end,
    }
    local ret = with_client_role(runtime, "player1", fn)
    _assert_eq(called_role, "player1", "role passed")
    _assert_eq(called_fn, fn, "fn passed")
    _assert_eq(ret, "result", "return value forwarded")
  end)

  it("calls fn directly when runtime has neither method", function()
    local fn_called = false
    local fn = function() fn_called = true end
    local runtime = {}
    with_client_role(runtime, "player1", fn)
    _assert_eq(fn_called, true, "fn called directly")
  end)

  it("sets and clears client role around fn when set_client_role present", function()
    local calls = {}
    local fn = function() calls[#calls + 1] = "fn" end
    local runtime = {
      set_client_role = function(r)
        calls[#calls + 1] = tostring(r)
      end,
    }
    with_client_role(runtime, "player1", fn)
    _assert_eq(calls[1], "player1", "role set before fn")
    _assert_eq(calls[2], "fn", "fn called after set")
    _assert_eq(calls[3], "nil", "role cleared after fn")
  end)

  it("clears client role and re-raises when fn errors", function()
    local cleared = false
    local runtime = {
      set_client_role = function(r)
        if r == nil then cleared = true end
      end,
    }
    local ok, err = pcall(with_client_role, runtime, "p", function() error("boom") end)
    _assert_eq(ok, false, "error propagated")
    _assert_eq(cleared, true, "role cleared despite error")
    assert(tostring(err):find("boom"), "original error preserved: " .. tostring(err))
  end)
end)
