local runtime_ports = {}

local configured = nil

local function _resolve_port(name)
  if configured and configured[name] ~= nil then
    return configured[name]
  end
  return nil
end

-- Build a port that forwards its arguments to the configured implementation
-- and returns `default` when the host left the port unconfigured.
local function _make_port(name, default)
  return function(...)
    local fn = _resolve_port(name)
    if type(fn) ~= "function" then
      return default
    end
    return fn(...)
  end
end

function runtime_ports.configure(ports)
  configured = ports or nil
end

function runtime_ports.rng_next_int(min, max)
  local fn = _resolve_port("rng_next_int")
  assert(type(fn) == "function", "missing runtime port: rng_next_int")
  return fn(min, max)
end

function runtime_ports.schedule(delay, fn)
  local scheduler = _resolve_port("schedule")
  if type(scheduler) ~= "function" then
    if fn then
      fn()
    end
    return
  end
  return scheduler(delay, fn)
end

runtime_ports.resolve_role = _make_port("resolve_role", nil)

local _empty_roles = {}

runtime_ports.resolve_roles = _make_port("resolve_roles", _empty_roles)

runtime_ports.mark_role_lose = _make_port("mark_role_lose", nil)

runtime_ports.call_role_die = _make_port("call_role_die", false)

runtime_ports.resolve_camera_helper = _make_port("resolve_camera_helper", nil)

runtime_ports.emit_event = _make_port("emit_event", false)

runtime_ports.wall_now_seconds = _make_port("wall_now_seconds", 0)

function runtime_ports.wall_now_hms()
  local fn = _resolve_port("wall_now_hms")
  if type(fn) ~= "function" then
    return nil
  end
  local ok, hms = pcall(fn)
  if not ok or type(hms) ~= "string" or hms == "" then
    return nil
  end
  return hms
end

runtime_ports.wall_diff_seconds = _make_port("wall_diff_seconds", 0)

runtime_ports.cpu_now_seconds = _make_port("cpu_now_seconds", 0)

runtime_ports.cpu_diff_seconds = _make_port("cpu_diff_seconds", 0)

runtime_ports.is_effect_idle = _make_port("is_effect_idle", true)

runtime_ports.archives_enabled = _make_port("archives_enabled", false)

runtime_ports.get_archive_int = _make_port("get_archive_int", 0)

runtime_ports.set_archive_int = _make_port("set_archive_int", false)

function runtime_ports.reset_for_tests()
  configured = nil
end

-- 车道守卫用:共享测试基线(shared_support / env_runtime 加载时建立)要求本端口
-- 处于已配置态;spec teardown 拆到未配置态后不装回会泄漏给同进程后续 suite(#217)。
function runtime_ports.is_configured()
  return configured ~= nil
end

return runtime_ports

--[[ mutate4lua-manifest
version=4
projectHash=55618a658e5943ac
scope.0.id=chunk:src/foundation/ports/runtime_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=42d3113aaa4b25af
scope.1.id=function:_resolve_port
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=64f691721af56f6b
scope.2.id=function:_make_port
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=22
scope.2.semanticHash=0202d6152719828b
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=21
scope.3.semanticHash=39d740c0c387a53d
scope.4.id=function:runtime_ports.configure
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=26
scope.4.semanticHash=f0bb9394ad3dc3ac
scope.5.id=function:runtime_ports.rng_next_int
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=32
scope.5.semanticHash=f4a7a5e859ed2344
scope.6.id=function:runtime_ports.schedule
scope.6.kind=function
scope.6.startLine=34
scope.6.endLine=43
scope.6.semanticHash=47ecc2dee36d3b8f
scope.7.id=function:runtime_ports.wall_now_hms
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=71
scope.7.semanticHash=1cc795addb6d73b1
scope.8.id=function:runtime_ports.reset_for_tests
scope.8.kind=function
scope.8.startLine=87
scope.8.endLine=89
scope.8.semanticHash=f308d8708726be18
scope.9.id=function:runtime_ports.is_configured
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=95
scope.9.semanticHash=70efc1221c5d6d62
]]
