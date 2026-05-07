local runtime_ports = require("src.foundation.ports.runtime_ports")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _before()
  runtime_ports.reset_for_tests()
end

describe("domain runtime ports coverage", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("schedule calls fn directly when no scheduler configured", function()
    _before()
    local called = false
    runtime_ports.schedule(0.1, function() called = true end)
    _assert_eq(called, true, "schedule should call fn directly when no scheduler port")
  end)

  it("schedule delegates to configured scheduler", function()
    _before()
    local received_delay, received_fn
    runtime_ports.configure({
      schedule = function(delay, fn)
        received_delay = delay
        received_fn = fn
      end,
    })
    local my_fn = function() end
    runtime_ports.schedule(0.5, my_fn)
    _assert_eq(received_delay, 0.5, "configured scheduler should receive delay")
    _assert_eq(received_fn, my_fn, "configured scheduler should receive fn")
    runtime_ports.reset_for_tests()
  end)

  it("resolve_role returns nil when not configured", function()
    _before()
    _assert_eq(runtime_ports.resolve_role("role_1"), nil, "resolve_role should return nil when not configured")
  end)

  it("resolve_role delegates to configured resolver", function()
    _before()
    local got_id
    runtime_ports.configure({
      resolve_role = function(player_id)
        got_id = player_id
        return { id = player_id }
      end,
    })
    local result = runtime_ports.resolve_role("p1")
    _assert_eq(got_id, "p1", "configured resolver should receive player_id")
    _assert_eq(result.id, "p1", "resolve_role should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("resolve_roles returns empty when not configured", function()
    _before()
    local roles = runtime_ports.resolve_roles()
    _assert_eq(type(roles), "table", "resolve_roles should return table when not configured")
    _assert_eq(#roles, 0, "resolve_roles should return empty table when not configured")
  end)

  it("resolve_roles delegates to configured resolver", function()
    _before()
    local all_roles = { { id = "r1" }, { id = "r2" } }
    runtime_ports.configure({
      resolve_roles = function() return all_roles end,
    })
    _assert_eq(runtime_ports.resolve_roles(), all_roles, "resolve_roles should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("mark_role_lose returns nil when not configured", function()
    _before()
    _assert_eq(runtime_ports.mark_role_lose({ id = "r1" }), nil, "mark_role_lose should return nil when not configured")
  end)

  it("mark_role_lose delegates to configured marker", function()
    _before()
    local marked_role
    runtime_ports.configure({
      mark_role_lose = function(role) marked_role = role end,
    })
    local role = { id = "r2" }
    runtime_ports.mark_role_lose(role)
    _assert_eq(marked_role, role, "mark_role_lose should delegate to configured marker")
    runtime_ports.reset_for_tests()
  end)

  it("resolve_camera_helper returns nil when not configured", function()
    _before()
    _assert_eq(runtime_ports.resolve_camera_helper(), nil, "resolve_camera_helper should return nil when not configured")
  end)

  it("resolve_camera_helper delegates to configured resolver", function()
    _before()
    local helper = { kind = "camera" }
    runtime_ports.configure({
      resolve_camera_helper = function() return helper end,
    })
    _assert_eq(runtime_ports.resolve_camera_helper(), helper, "resolve_camera_helper should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("emit_event returns false when not configured", function()
    _before()
    _assert_eq(runtime_ports.emit_event("evt", {}), false, "emit_event should return false when not configured")
  end)

  it("emit_event delegates to configured emitter", function()
    _before()
    local received = {}
    runtime_ports.configure({
      emit_event = function(name, payload, opts)
        received.name = name
        received.payload = payload
        received.opts = opts
        return true
      end,
    })
    local payload = { data = 1 }
    local opts = { broadcast = true }
    local result = runtime_ports.emit_event("test_event", payload, opts)
    _assert_eq(result, true, "emit_event should return configured emitter result")
    _assert_eq(received.name, "test_event", "emit_event should pass event name")
    _assert_eq(received.payload, payload, "emit_event should pass payload")
    _assert_eq(received.opts, opts, "emit_event should pass opts")
    runtime_ports.reset_for_tests()
  end)

  it("wall_now_seconds returns zero when not configured", function()
    _before()
    _assert_eq(runtime_ports.wall_now_seconds(), 0, "wall_now_seconds should return 0 when not configured")
  end)

  it("wall_now_seconds delegates to configured fn", function()
    _before()
    runtime_ports.configure({ wall_now_seconds = function() return 1234.5 end })
    _assert_eq(runtime_ports.wall_now_seconds(), 1234.5, "wall_now_seconds should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("wall_diff_seconds returns zero when not configured", function()
    _before()
    _assert_eq(runtime_ports.wall_diff_seconds(100.0, 99.0), 0, "wall_diff_seconds should return 0 when not configured")
  end)

  it("wall_diff_seconds delegates to configured fn", function()
    _before()
    local got_t1, got_t2
    runtime_ports.configure({
      wall_diff_seconds = function(t1, t2)
        got_t1 = t1
        got_t2 = t2
        return t1 - t2
      end,
    })
    local result = runtime_ports.wall_diff_seconds(10.5, 10.0)
    _assert_eq(result, 0.5, "wall_diff_seconds should return configured result")
    _assert_eq(got_t1, 10.5, "wall_diff_seconds should pass t1")
    _assert_eq(got_t2, 10.0, "wall_diff_seconds should pass t2")
    runtime_ports.reset_for_tests()
  end)

  it("cpu_now_seconds returns zero when not configured", function()
    _before()
    _assert_eq(runtime_ports.cpu_now_seconds(), 0, "cpu_now_seconds should return 0 when not configured")
  end)

  it("cpu_now_seconds delegates to configured fn", function()
    _before()
    runtime_ports.configure({ cpu_now_seconds = function() return 99.9 end })
    _assert_eq(runtime_ports.cpu_now_seconds(), 99.9, "cpu_now_seconds should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("cpu_diff_seconds returns zero when not configured", function()
    _before()
    _assert_eq(runtime_ports.cpu_diff_seconds(5.0, 4.0), 0, "cpu_diff_seconds should return 0 when not configured")
  end)

  it("cpu_diff_seconds delegates to configured fn", function()
    _before()
    runtime_ports.configure({
      cpu_diff_seconds = function(t1, t2) return t1 - t2 end,
    })
    _assert_eq(runtime_ports.cpu_diff_seconds(3.0, 2.5), 0.5, "cpu_diff_seconds should return configured result")
    runtime_ports.reset_for_tests()
  end)

  it("is_effect_idle returns true when not configured", function()
    _before()
    _assert_eq(runtime_ports.is_effect_idle(), true, "is_effect_idle should return true when not configured")
  end)

  it("is_effect_idle delegates to configured fn", function()
    _before()
    runtime_ports.configure({ is_effect_idle = function() return false end })
    _assert_eq(runtime_ports.is_effect_idle(), false, "is_effect_idle should return configured result")
    runtime_ports.reset_for_tests()
  end)
end)
