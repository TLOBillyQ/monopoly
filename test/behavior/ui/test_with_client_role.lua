local lu = require("luaunit")
local with_client_role = require("src.ui.render.support.with_client_role")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- describe("with_client_role") 拍平为文件级 TestWithClientRole,文件内自研
-- _assert_eq 原样保留,用例数与改写前一一对应(4 例)。
TestWithClientRole = {}

function TestWithClientRole:test_delegates_to_runtime_with_client_role_when_present()
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
end

function TestWithClientRole:test_calls_fn_directly_when_runtime_has_neither_method()
  local fn_called = false
  local fn = function() fn_called = true end
  local runtime = {}
  with_client_role(runtime, "player1", fn)
  _assert_eq(fn_called, true, "fn called directly")
end

function TestWithClientRole:test_sets_and_clears_client_role_around_fn_when_set_client_role_present()
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
end

function TestWithClientRole:test_clears_client_role_and_re_raises_when_fn_errors()
  local cleared = false
  local runtime = {
    set_client_role = function(r)
      if r == nil then cleared = true end
    end,
  }
  local ok, err = pcall(with_client_role, runtime, "p", function() error("boom") end)
  _assert_eq(ok, false, "error propagated")
  _assert_eq(cleared, true, "role cleared despite error")
  lu.assertEvalToTrue(tostring(err):find("boom"), "original error preserved: " .. tostring(err))
end

function TestWithClientRole:test_rejects_missing_runtime_with_message()
  -- #293: L2 assert 消息变异(消息串翻 nil)——缺 runtime 必须报出标识消息。
  local luax = require("test.support.luax")
  luax.has_error(function()
    with_client_role(nil, "p", function() end)
  end, "missing runtime")
end

function TestWithClientRole:test_rejects_missing_fn_with_message()
  -- #293: L3 assert 消息变异(消息串翻 nil)——缺 fn 必须报出标识消息。
  local luax = require("test.support.luax")
  luax.has_error(function()
    with_client_role({}, "p", nil)
  end, "missing fn")
end


return TestWithClientRole
