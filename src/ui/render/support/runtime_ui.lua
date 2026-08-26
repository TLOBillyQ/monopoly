local runtime_ports = require("src.foundation.ports.runtime_ports")
local role_id_utils = require("src.foundation.identity")

local runtime = {}

-- #541:宿主 traceback 全局不保证拼入原始 msg(真机实测只剩空
-- "stack traceback:"),错误正文必须由本侧 tostring 保留,traceback 只做附录。
local function _traceback(err)
  local message = tostring(err)
  if type(traceback) == "function" then
    return message .. "\n" .. tostring(traceback(message))
  end
  return message
end

-- role 作用域内的失败带目标 role 标识,事后仅凭日志可分辨是哪个角色的
-- 推送炸了;role 为 nil(全局推送)时不加前缀。
local function _role_error_prefix(role)
  if role == nil then
    return ""
  end
  local role_id = runtime.resolve_role_id(role)
  if role_id == nil then
    role_id = tostring(role)
  end
  return "[role=" .. tostring(role_id) .. "] "
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
    error(_role_error_prefix(role) .. result)
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
version=4
projectHash=7ee8e42cb036c12d
scope.0.id=chunk:src/ui/render/support/runtime_ui.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=111
scope.0.semanticHash=97fb3a1343fd4ee8
scope.1.id=function:_traceback
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=14
scope.1.semanticHash=b4b3316f6b23e2e7
scope.2.id=function:_role_error_prefix
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=27
scope.2.semanticHash=f4c63b841da91875
scope.3.id=function:runtime.set_client_role
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=33
scope.3.semanticHash=83457172d49234d7
scope.4.id=function:runtime.get_client_role
scope.4.kind=function
scope.4.startLine=35
scope.4.endLine=40
scope.4.semanticHash=356ec8eaed694aba
scope.5.id=function:runtime.resolve_role_id
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=51
scope.5.semanticHash=eb2e0d996cc85e79
scope.6.id=function:runtime.with_client_role
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=63
scope.6.semanticHash=15719ca6b82e4c1d
scope.7.id=function:runtime.for_each_role_or_global
scope.7.kind=function
scope.7.startLine=65
scope.7.endLine=75
scope.7.semanticHash=2d1d388cc45668f2
scope.8.id=function:runtime.query_nodes
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=83
scope.8.semanticHash=13740f9cb6241098
scope.9.id=function:runtime.query_node
scope.9.kind=function
scope.9.startLine=85
scope.9.endLine=88
scope.9.semanticHash=cb7734d009640d9c
scope.10.id=function:_apply_texture_via_methods
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=100
scope.10.semanticHash=9381528952fa8219
scope.11.id=function:runtime.set_node_texture_keep_size
scope.11.kind=function
scope.11.startLine=102
scope.11.endLine=104
scope.11.semanticHash=cbd98dd95a4cd8c5
scope.12.id=function:runtime.set_node_texture_native_size
scope.12.kind=function
scope.12.startLine=106
scope.12.endLine=108
scope.12.semanticHash=741a96b320e9edb7
]]
