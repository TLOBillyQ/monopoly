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

return runtime_ports

--[[ mutate4lua-manifest
version=2
projectHash=1d280b13f99b0b4f
scope.0.id=chunk:src/foundation/ports/runtime_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=2051eb8b0f31296c
scope.0.lastMutatedAt=2026-05-29T14:57:24Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_resolve_port:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=2d170b78e6886670
scope.1.lastMutatedAt=2026-05-29T14:57:24Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=2
scope.1.lastMutationKilled=2
scope.2.id=function:anonymous@15:15
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=21
scope.2.semanticHash=3d1f3dd799be9d43
scope.2.lastMutatedAt=2026-05-29T14:57:24Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:_make_port:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=22
scope.3.semanticHash=0458be18ea8b9fdc
scope.3.lastMutatedAt=2026-05-29T14:57:24Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=no_sites
scope.3.lastMutationSites=0
scope.3.lastMutationKilled=0
scope.4.id=function:runtime_ports.configure:24
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=26
scope.4.semanticHash=0997604eaef668f1
scope.4.lastMutatedAt=2026-05-29T14:57:24Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:runtime_ports.rng_next_int:28
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=32
scope.5.semanticHash=4dd48f530e514ae7
scope.5.lastMutatedAt=2026-05-29T14:57:24Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=3
scope.5.lastMutationKilled=3
scope.6.id=function:runtime_ports.schedule:34
scope.6.kind=function
scope.6.startLine=34
scope.6.endLine=43
scope.6.semanticHash=32e36f61c7bfc1e7
scope.6.lastMutatedAt=2026-05-29T14:57:24Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=6
scope.6.lastMutationKilled=6
scope.7.id=function:runtime_ports.wall_now_hms:59
scope.7.kind=function
scope.7.startLine=59
scope.7.endLine=69
scope.7.semanticHash=283d92024d529dc1
scope.7.lastMutatedAt=2026-05-29T14:57:24Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=13
scope.7.lastMutationKilled=13
scope.8.id=function:runtime_ports.reset_for_tests:85
scope.8.kind=function
scope.8.startLine=85
scope.8.endLine=87
scope.8.semanticHash=cf4e4acb2826561b
scope.8.lastMutatedAt=2026-05-29T14:57:24Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=no_sites
scope.8.lastMutationSites=0
scope.8.lastMutationKilled=0
]]
