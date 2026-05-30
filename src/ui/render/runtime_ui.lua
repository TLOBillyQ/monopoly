local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_id_utils = require("src.foundation.identity")

local runtime = {}

local function _traceback(err)
  if type(traceback) == "function" then
    return traceback(err)
  end
  return err
end

function runtime.set_client_role(role)
  if UIManager then
    UIManager.client_role = role
  end
end

function runtime.get_client_role()
  if UIManager then
    return UIManager.client_role
  end
  return nil
end

function runtime.resolve_role_id(role)
  if not role or not role.get_roleid then
    return nil
  end
  local ok, raw_role_id = pcall(role.get_roleid)
  if not ok then
    return nil
  end
  return role_id_utils.normalize(raw_role_id)
end

function runtime.with_client_role(role, fn, ...)
  assert(type(fn) == "function", "missing fn")
  local previous_role = UIManager and UIManager.client_role or nil
  runtime.set_client_role(role)
  local ok, result = xpcall(fn, _traceback, ...)
  runtime.set_client_role(previous_role)
  if not ok then
    error(result)
  end
  return result
end

function runtime.for_each_role_or_global(fn)
  assert(type(fn) == "function", "missing fn")
  local roles = runtime_ports.resolve_roles()
  if type(roles) == "table" and #roles > 0 then
    for _, role in ipairs(roles) do
      runtime.with_client_role(role, fn, role)
    end
    return
  end
  runtime.with_client_role(nil, fn, nil)
end

function runtime.query_nodes(name)
  assert(name ~= nil, "missing ui node name")
  assert(UIManager ~= nil and UIManager.query_nodes_by_name ~= nil, "missing UIManager.query_nodes_by_name")
  local nodes = UIManager.query_nodes_by_name(name)
  assert(nodes ~= nil and nodes[1] ~= nil, "missing ui node: " .. tostring(name))
  return nodes
end

function runtime.query_node(name)
  local nodes = runtime.query_nodes(name)
  return nodes[1]
end

local function _apply_texture_via_methods(node, image_key, methods)
  assert(node ~= nil, "missing image node")
  assert(image_key ~= nil, "missing image key")
  for _, method_name in ipairs(methods) do
    if node[method_name] then
      node[method_name](node, image_key)
      return
    end
  end
  node.image_texture = image_key
end

function runtime.set_node_texture_keep_size(node, image_key)
  _apply_texture_via_methods(node, image_key, { "set_texture_keep_size" })
end

function runtime.set_node_texture_native_size(node, image_key)
  _apply_texture_via_methods(node, image_key, { "set_texture_native_size", "set_texture_keep_size" })
end

return runtime

--[[ mutate4lua-manifest
version=2
projectHash=6d29592578574593
scope.0.id=chunk:src/ui/render/runtime_ui.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=95
scope.0.semanticHash=872dd4ae35a5e675
scope.0.lastMutatedAt=2026-05-28T15:20:13Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=16
scope.0.lastMutationKilled=16
scope.1.id=function:_traceback:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=11
scope.1.semanticHash=ac4a679837505f7c
scope.1.lastMutatedAt=2026-05-28T15:20:13Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:runtime.set_client_role:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=17
scope.2.semanticHash=2e0639af8bb1ed0a
scope.3.id=function:runtime.get_client_role:19
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=24
scope.3.semanticHash=3fcba97e92559602
scope.4.id=function:runtime.resolve_role_id:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=35
scope.4.semanticHash=2a4fcbcdd64cecf1
scope.4.lastMutatedAt=2026-05-28T15:20:13Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=6
scope.4.lastMutationKilled=6
scope.5.id=function:runtime.with_client_role:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=47
scope.5.semanticHash=0e95a57a406c1885
scope.5.lastMutatedAt=2026-05-28T15:20:13Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
scope.6.id=function:runtime.query_nodes:61
scope.6.kind=function
scope.6.startLine=61
scope.6.endLine=67
scope.6.semanticHash=0adb703d01237f06
scope.6.lastMutatedAt=2026-05-28T15:20:13Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:runtime.query_node:69
scope.7.kind=function
scope.7.startLine=69
scope.7.endLine=72
scope.7.semanticHash=ee591cd2e977389e
scope.7.lastMutatedAt=2026-05-28T15:20:13Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=2
scope.7.lastMutationKilled=2
scope.8.id=function:runtime.set_node_texture_keep_size:86
scope.8.kind=function
scope.8.startLine=86
scope.8.endLine=88
scope.8.semanticHash=036454f537af1e74
scope.8.lastMutatedAt=2026-05-28T15:20:13Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:runtime.set_node_texture_native_size:90
scope.9.kind=function
scope.9.startLine=90
scope.9.endLine=92
scope.9.semanticHash=7ac0a7c10152cd60
scope.9.lastMutatedAt=2026-05-28T15:20:13Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
]]
