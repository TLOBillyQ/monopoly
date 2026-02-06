local patch_reducer = {}

local function _ensure_parent(root, path)
  local node = root
  for index = 1, #path - 1 do
    local key = path[index]
    local next_node = node[key]
    if type(next_node) ~= "table" then
      next_node = {}
      node[key] = next_node
    end
    node = next_node
  end
  return node
end

function patch_reducer.apply(state, event)
  if event.type ~= "state_patch" then
    return
  end
  local payload = event.payload or {}
  local path = payload.path
  if type(path) ~= "table" or #path == 0 then
    return
  end
  local parent = _ensure_parent(state, path)
  parent[path[#path]] = payload.value
end

return patch_reducer
