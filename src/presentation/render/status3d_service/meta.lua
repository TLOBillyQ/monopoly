local logger = require("src.core.Logger")
local number_utils = require("src.core.NumberUtils")
local ui_nodes = require("Data.UIManagerNodes")
local specs = require("src.presentation.render.status3d_service.specs")

local M = {}

function M.ensure_cache(state)
  assert(state ~= nil, "missing state")
  if state.ui_status_3d == nil then
    state.ui_status_3d = {
      layers_by_player_id = {},
      nodes_by_player_id = {},
      last_status_key_by_player = {},
      warned_once = {},
      disabled = false,
      meta = nil,
    }
  end
  return state.ui_status_3d
end

function M.warn_once(cache, key, ...)
  if cache.warned_once[key] then
    return
  end
  cache.warned_once[key] = true
  logger.warn(...)
end

local function _split_export_node_id(raw_id)
  if type(raw_id) ~= "string" then
    return nil, nil
  end
  local sep = string.find(raw_id, "|", 1, true)
  if not sep then
    return nil, nil
  end
  local prefix = string.sub(raw_id, 1, sep - 1)
  local node_id_raw = string.sub(raw_id, sep + 1)
  if prefix == "" or node_id_raw == "" then
    return nil, nil
  end
  return prefix, node_id_raw
end

function M.build_meta(cache)
  if cache.meta ~= nil then
    return cache.meta
  end
  local resolved = {}
  local layer_prefix = nil
  for status_key in pairs(specs.status_node_specs) do
    resolved[status_key] = {}
  end
  for raw_id, entry in pairs(ui_nodes) do
    if type(entry) == "table" then
      local binding = specs.status_node_name_lookup[entry[1]]
      if binding then
        local prefix, node_id = _split_export_node_id(raw_id)
        if not prefix or not node_id then
          return nil, "invalid status node export id: " .. tostring(raw_id)
        end
        if layer_prefix == nil then
          layer_prefix = prefix
        elseif layer_prefix ~= prefix then
          return nil, "status node layer prefix mismatch: " .. tostring(layer_prefix) .. " / " .. tostring(prefix)
        end
        resolved[binding.status_key][binding.node_type] = node_id
      end
    end
  end
  if layer_prefix == nil then
    return nil, "status 3d nodes not found in Data.UIManagerNodes"
  end
  for status_key, spec in pairs(specs.status_node_specs) do
    local node_set = resolved[status_key]
    if not node_set.bg then
      return nil, "missing status bg node: " .. tostring(spec.bg)
    end
    if not node_set.text then
      return nil, "missing status text node: " .. tostring(spec.text)
    end
  end
  cache.meta = { layer_key = number_utils.to_integer(layer_prefix) or layer_prefix, node_ids_by_status = resolved }
  return cache.meta
end

return M
