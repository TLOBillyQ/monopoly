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
version=4
projectHash=b5c9c7ffe4c6e69c
scope.0.id=chunk:src/host/camera.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=30
scope.0.semanticHash=807f95e29480aa82
scope.1.id=function:camera_helper.new
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=27
scope.1.semanticHash=c1ff09e1e84f7832
scope.2.id=function:helper.set_target
scope.2.kind=function
scope.2.startLine=9
scope.2.endLine=12
scope.2.semanticHash=2fa32a61913a8e01
scope.3.id=function:helper.get_target
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=24f2b9b574225623
scope.4.id=function:helper.follow
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=24
scope.4.semanticHash=b0271ee5330da4cb
]]
