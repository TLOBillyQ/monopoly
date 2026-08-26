-- src.ui.ports.actor_context 包装面直测：build() 逐名委托 src.ui.coord.actor_context。
-- 此前行为车道只驱动过 coord 逻辑本体(test_interaction / test_view_command_ports),
-- 没驱动过这个包装面,"委托断线直接 return nil" 无测试照看——#293 清
-- actor_context.lua 幸存者的测错维度补齐。#442 起端口面只剩 resolve_role_by_id。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local host_roles = require("src.ui.seams.host_roles")
local actor_context_ports = require("src.ui.ports.actor_context")

TestActorContextPorts = {}

function TestActorContextPorts:setUp()
  host_roles.reset_for_tests()
end

function TestActorContextPorts:tearDown()
  support.restore_runtime_services()
end

function TestActorContextPorts:test_build_exposes_only_role_lookup_not_actor_resolution()
  -- #442:resolve_local_actor_role_id 已从端口面拆除——用例层不再自行解析行动者,
  -- 只消费事件边界写入的 intent.actor_role_id(ADR 0054)。
  local ports = actor_context_ports.build()
  lu.assertIs(type(ports.resolve_role_by_id), "function")
  lu.assertIs(ports.resolve_local_actor_role_id, nil,
    "actor resolution must not be reachable through the usecase-facing port (#442)")
end

function TestActorContextPorts:test_resolve_role_by_id_falls_back_to_minimal_stub_when_host_roster_empty()
  local ports = actor_context_ports.build()
  local role = ports.resolve_role_by_id(5)
  lu.assertIs(type(role), "table", "unconfigured host roster should yield a stub, not nil")
  lu.assertIs(role.get_roleid(), 5, "stub should report the normalized role id")
end

return TestActorContextPorts