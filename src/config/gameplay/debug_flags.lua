local resettable_defaults = require("src.foundation.resettable_defaults")

return resettable_defaults.build({
  info_log_per_turn_limit = 1,
  role_control_lock_enabled = true,
  -- 真人玩家联调开关：开局把全部席位(含 1 号位真人)标成托管,玩家进场后随时可点
  -- 托管按钮接管。只影响开局默认值,不改托管本身的语义。必须保持 false 发布,
  -- 由 test/guards/lib/debug_flags_guard.lua 门禁兜底(#265)。
  debug_auto_all_roles = false,
})

--[[ mutate4lua-manifest
version=4
projectHash=842eaabe342ddf7e
scope.0.id=chunk:src/config/gameplay/debug_flags.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=11
scope.0.semanticHash=d15d35954eff96e4
]]
