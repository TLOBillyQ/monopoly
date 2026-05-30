local defaults = {
  debug_log_enabled = true,
  action_anim_debug_log_enabled = false,
  move_anim_debug_log_enabled = false,
  debug_log_max_lines = 50,
  info_log_per_turn_limit = 1,
  role_control_lock_enabled = true,
  debug_auto_non_primary = true,
}

local debug_flags = {}

local function _apply_defaults(target)
  for key, value in pairs(defaults) do
    target[key] = value
  end
end

local function _reset(target)
  for key in pairs(target) do
    target[key] = nil
  end
  _apply_defaults(target)
end

_apply_defaults(debug_flags)

setmetatable(debug_flags, {
  __index = {
    reset = function()
      _reset(debug_flags)
    end,
  },
})

return debug_flags

--[[ mutate4lua-manifest
version=2
projectHash=98d60d0cb269fe87
scope.0.id=chunk:src/config/gameplay/debug_flags.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=2c2578241ab6ca75
scope.1.id=function:anonymous@30:30
scope.1.kind=function
scope.1.startLine=30
scope.1.endLine=32
scope.1.semanticHash=0cbcd7f2603d2897
]]
