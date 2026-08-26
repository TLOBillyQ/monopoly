local host_slot = require("src.ui.seams.host_slot")

-- 宿主单位舞台 port：场景单位查询、创建/销毁生命周期与实体池。
-- 未装配时一律返回 nil，调用方按「宿主缺席」路径降级。
return host_slot.new({
  { name = "query_unit" },
  { name = "query_units" },
  { name = "create_unit_group" },
  { name = "create_unit_with_scale" },
  { name = "destroy_unit" },
  { name = "destroy_unit_with_children" },
  { name = "acquire_unit" },
  { name = "release_unit" },
  { name = "prewarm_unit" },
})

--[[ mutate4lua-manifest
version=4
projectHash=c630a25aca3f4b0f
scope.0.id=chunk:src/ui/seams/host_units.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=50b96c05cdc27d21
]]
