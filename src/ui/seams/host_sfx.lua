local host_slot = require("src.ui.seams.host_slot")

-- 宿主音效 port：特效音/3D 音播放与音效挂接单位。未装配时返回 nil。
return host_slot.new({
  { name = "play_sfx_by_key" },
  { name = "play_3d_sound" },
  { name = "bind_sfx_to_unit" },
})

--[[ mutate4lua-manifest
version=4
projectHash=a38df3f9f7565a6e
scope.0.id=chunk:src/ui/seams/host_sfx.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=9
scope.0.semanticHash=9323838156e05319
]]
