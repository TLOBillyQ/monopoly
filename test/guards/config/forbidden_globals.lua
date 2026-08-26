-- 出生类配置(#176):forbidden_globals 守卫的本仓豁免面,归项目所有。
-- 机制体住 test/guards/lib/forbidden_globals.lua,只读本文件,不内嵌项目路径。

-- Issue #83: host global direct-call interception for src/ui.
-- Allowlist: src/ui/manager/ (host-EUI adapter) and src/host/ (host adapter implementation).
-- Manager EUI boundary (Issue #84): direct GameAPI.get_eui_children / get_eui_child_by_name
-- calls in src/ui/manager/enode.lua and src/ui/manager/ecanvas.lua are explicitly allowed
-- because the manager layer is the host-EUI adapter.
local host_globals_allowlist = {
  "^src/ui/manager/",
  "^src/host/",
}

-- Transitional exemptions below are pre-existing direct usage scheduled for seam migration.
local host_globals_transitional_exemptions = {
  ["src/ui/render/status3d/init.lua"] = {
    "Enums.ModelSocket",
  },
  ["src/ui/render/status3d/scene.lua"] = {
    "Enums.ModelSocket.socket_head",
  },
  ["src/ui/input/role_control_lock.lua"] = {
    "Enums.BuffState.BUFF_FORBID_CONTROL",
  },
}

return {
  host_globals_allowlist = host_globals_allowlist,
  host_globals_transitional_exemptions = host_globals_transitional_exemptions,
}
