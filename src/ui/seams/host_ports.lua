-- ui 宿主能力 port 清单单一真源（#250/#251）：5 个 host 能力
-- port 槽的有序表。app 装配（host_install）、聚合面（host_runtime）与 spec 支撑
-- （shared_support / test_env）均批量消费本表——新增/删除一个 host port 只改这一处。
return {
  (require("src.ui.seams.host_events")),
  (require("src.ui.seams.host_roles")),
  (require("src.ui.seams.host_units")),
  (require("src.ui.seams.host_sfx")),
  (require("src.ui.seams.host_scene_ui")),
}

--[[ mutate4lua-manifest
version=4
projectHash=bbf1360b15b19a08
scope.0.id=chunk:src/ui/seams/host_ports.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=11
scope.0.semanticHash=12f2d4bd097aa3b3
]]
