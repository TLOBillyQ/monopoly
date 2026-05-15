local turn_script = require("src.turn.timing")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_session(phases, opts)
  opts = opts or {}
  return {
    phases = phases,
    game = {
      turn = { turn_count = opts.turn_count or 0 },
      current_player = function() return { name = "P1" } end,
    },
    turn_mgr = opts.turn_mgr or {},
    current_state = opts.current_state or nil,
    current_args = opts.current_args or nil,
    mark_phase = function(_, _) end,
  }
end

-- turn_script.create: simple run start → done → nil


-- turn_script.create: session with existing current_state skips 'start'


-- turn_script.create: callable table as phase handler (_is_callable table path)


-- turn_script.create: state_args forwarded to handler


-- turn_script.create: session.turn_mgr is passed to handlers (not session itself)


-- turn_script.create: session used as turn_mgr when turn_mgr is nil

describe("domain session_script coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("session_script run to finish", function()
    local visited = {}
    local session = _make_session({
      start = function(_, _) visited[#visited + 1] = "start"; return "done", nil end,
      done = function(_, _) visited[#visited + 1] = "done"; return nil end,
    })
    local co = turn_script.create(session)
    local ok = coroutine.resume(co)
    assert(ok, "coroutine should complete without error")
    _assert_eq(session.finished, true, "session should be marked finished")
    _assert_eq(#visited, 2, "should visit start and done")
  end)

  it("session_script resumes from current_state", function()
    local visited = {}
    local session = _make_session({
      mid = function(_, _) visited[#visited + 1] = "mid"; return nil end,
    }, { current_state = "mid" })
    local co = turn_script.create(session)
    coroutine.resume(co)
    _assert_eq(session.finished, true, "should finish from mid state")
    _assert_eq(#visited, 1, "should only visit mid")
  end)

  it("session_script callable table handler", function()
    local call_count = 0
    local handler_table = setmetatable({}, {
      __call = function(_, _, _)
        call_count = call_count + 1
        return nil
      end,
    })
    local session = _make_session({
      start = function(_, _) return "custom", nil end,
      custom = handler_table,
    })
    local co = turn_script.create(session)
    local ok = coroutine.resume(co)
    assert(ok, "coroutine with callable table handler should succeed")
    _assert_eq(call_count, 1, "callable table handler should be invoked once")
    _assert_eq(session.finished, true, "session should finish")
  end)

  it("session_script args forwarded", function()
    local received_args = nil
    local session = _make_session({
      start = function(_, _) return "next", { value = 42 } end,
      next = function(_, args) received_args = args; return nil end,
    })
    local co = turn_script.create(session)
    coroutine.resume(co)
    assert(received_args ~= nil, "args should be forwarded to next phase")
    _assert_eq(received_args.value, 42, "forwarded args.value should be 42")
  end)

  it("session_script turn_mgr passed to handler", function()
    local received_mgr = nil
    local turn_mgr = { label = "mgr" }
    local session = _make_session({
      start = function(mgr, _) received_mgr = mgr; return nil end,
    }, { turn_mgr = turn_mgr })
    local co = turn_script.create(session)
    coroutine.resume(co)
    _assert_eq(received_mgr, turn_mgr, "turn_mgr should be passed to phase handlers")
  end)

  it("session_script session as turn_mgr fallback", function()
    local received_mgr = nil
    local session = _make_session({
      start = function(mgr, _) received_mgr = mgr; return nil end,
    })
    session.turn_mgr = nil
    local co = turn_script.create(session)
    coroutine.resume(co)
    _assert_eq(received_mgr, session, "session itself should be used as turn_mgr when turn_mgr is nil")
  end)
end)
