local camera_helper = {}

function camera_helper.new(env, deps)
  local helper = {
    _env = env,
    target_role_id = nil,
  }

  function helper.set_target(role_id)
    helper.target_role_id = role_id
    return role_id
  end

  function helper.get_target()
    return helper.target_role_id
  end

  function helper.follow(role_id)
    if role_id == nil then
      return false
    end
    helper.set_target(role_id)
    return true
  end

  return helper
end

return camera_helper

--[[ mutate4lua-manifest
version=2
projectHash=9c4d8c1d87c82e45
scope.0.id=chunk:src/host/camera.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=4bdfe05b6cac173e
scope.1.id=function:helper.set_target:9
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=12
scope.1.semanticHash=0b5d500d973675ea
scope.2.id=function:helper.get_target:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=16
scope.2.semanticHash=7b608bfee0c2df3b
scope.3.id=function:helper.follow:18
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=24
scope.3.semanticHash=f2c87ac033819bda
scope.4.id=function:camera_helper.new:3
scope.4.kind=function
scope.4.startLine=3
scope.4.endLine=27
scope.4.semanticHash=692c665244eac80a
]]
