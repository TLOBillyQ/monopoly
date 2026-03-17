local runtime_ports = require("src.core.ports.runtime_ports")
local role_id_utils = require("src.core.utils.role_id")

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

function runtime.with_client_role(role, fn)
  assert(type(fn) == "function", "missing fn")
  local previous_role = UIManager and UIManager.client_role or nil
  runtime.set_client_role(role)
  local ok, result = xpcall(fn, _traceback)
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
      runtime.with_client_role(role, function()
        fn(role)
      end)
    end
    return
  end
  runtime.with_client_role(nil, function()
    fn(nil)
  end)
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

function runtime.set_node_texture_keep_size(node, image_key)
  assert(node ~= nil, "missing image node")
  assert(image_key ~= nil, "missing image key")
  if node.set_texture_keep_size then
    node:set_texture_keep_size(image_key)
    return
  end
  node.image_texture = image_key
end

function runtime.set_node_texture_native_size(node, image_key)
  assert(node ~= nil, "missing image node")
  assert(image_key ~= nil, "missing image key")
  if node.set_texture_native_size then
    node:set_texture_native_size(image_key)
    return
  end
  if node.set_texture_keep_size then
    node:set_texture_keep_size(image_key)
    return
  end
  node.image_texture = image_key
end

return runtime
