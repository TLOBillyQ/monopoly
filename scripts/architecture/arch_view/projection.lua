local common = require("arch_view.common")
local layers = require("arch_view.layers")

local projection = {}

local MIXED_LEAF_SUFFIX = "|file"

local function _mixed_leaf_id(child_name)
  return child_name .. MIXED_LEAF_SUFFIX
end

local function _is_mixed_leaf(node_id)
  return tostring(node_id):sub(-#MIXED_LEAF_SUFFIX) == MIXED_LEAF_SUFFIX
end

local function _node_label(child_name, mixed_leaf)
  if mixed_leaf then
    return child_name .. " [file]"
  end
  return child_name
end

local function _collect_scoped_modules(modules, prefix_segments)
  local scoped = {}
  for module_id, module_info in common.sorted_pairs(modules or {}) do
    if common.starts_with_segments(module_info.namespace_segments, prefix_segments)
      and #module_info.namespace_segments > #prefix_segments then
      scoped[module_id] = module_info
    end
  end
  return scoped
end

local function _module_to_child(scoped_modules, prefix_segments)
  local result = {}
  for module_id, module_info in pairs(scoped_modules or {}) do
    result[module_id] = module_info.namespace_segments[#prefix_segments + 1]
  end
  return result
end

local function _child_to_info(scoped_modules, prefix_segments, module_child_map)
  local child_info = {}
  for module_id, module_info in pairs(scoped_modules or {}) do
    local child_name = module_child_map[module_id]
    local info = child_info[child_name] or {
      exact_module = nil,
      descendant_modules = {},
    }
    if #module_info.namespace_segments == (#prefix_segments + 1) then
      info.exact_module = module_id
    else
      info.descendant_modules[module_id] = true
    end
    child_info[child_name] = info
  end
  return child_info
end

local function _module_to_node(child_info)
  local module_node_map = {}
  for child_name, info in common.sorted_pairs(child_info) do
    local has_descendants = next(info.descendant_modules) ~= nil
    if info.exact_module ~= nil then
      module_node_map[info.exact_module] = has_descendants and _mixed_leaf_id(child_name) or child_name
    end
    for module_id in common.sorted_pairs(info.descendant_modules) do
      module_node_map[module_id] = child_name
    end
  end
  return module_node_map
end

local function _node_to_modules(module_node_map)
  local node_modules = {}
  for module_id, node_id in common.sorted_pairs(module_node_map) do
    local bucket = node_modules[node_id] or {}
    bucket[#bucket + 1] = module_id
    node_modules[node_id] = bucket
  end
  for _, module_ids in pairs(node_modules) do
    table.sort(module_ids)
  end
  return node_modules
end

local function _node_graph(graph, scoped_modules, module_node_map)
  local graph_nodes = {}
  local graph_node_set = {}
  local edge_map = {}

  for _, node_id in common.sorted_pairs(module_node_map) do
    if not graph_node_set[node_id] then
      graph_node_set[node_id] = true
      graph_nodes[#graph_nodes + 1] = node_id
    end
  end

  for _, edge in ipairs(graph.edges or {}) do
    if scoped_modules[edge.from] and scoped_modules[edge.to] then
      local from_node = module_node_map[edge.from]
      local to_node = module_node_map[edge.to]
      if from_node ~= nil and to_node ~= nil and from_node ~= to_node then
        local key = common.edge_key(from_node, to_node)
        local entry = edge_map[key] or {
          from = from_node,
          to = to_node,
          count = 0,
          module_edges = {},
          feedback = false,
        }
        entry.count = entry.count + 1
        entry.module_edges[#entry.module_edges + 1] = {
          from = edge.from,
          to = edge.to,
        }
        edge_map[key] = entry
      end
    end
  end

  table.sort(graph_nodes)
  local graph_edges = {}
  for _, edge in common.sorted_pairs(edge_map) do
    table.sort(edge.module_edges, function(left, right)
      if left.from == right.from then
        return left.to < right.to
      end
      return left.from < right.from
    end)
    graph_edges[#graph_edges + 1] = edge
  end
  table.sort(graph_edges, function(left, right)
    if left.from == right.from then
      return left.to < right.to
    end
    return left.from < right.from
  end)

  return {
    nodes = graph_nodes,
    edges = graph_edges,
  }
end

local function _feedback_edge_set(layout)
  local feedback = {}
  for _, edge in ipairs(layout.feedback_edges or {}) do
    feedback[common.edge_key(edge.from, edge.to)] = true
  end
  return feedback
end

local function _module_feedback_set(layout)
  local involved = {}
  for _, edge in ipairs(layout.feedback_edges or {}) do
    involved[edge.from] = true
    involved[edge.to] = true
  end
  return involved
end

local function _node_component(modules, module_ids)
  local component_name = nil
  for _, module_id in ipairs(module_ids or {}) do
    local next_component = modules[module_id] and modules[module_id].component or nil
    if component_name == nil then
      component_name = next_component
    elseif component_name ~= next_component then
      return "mixed"
    end
  end
  return component_name
end

local function _node_abstract(modules, module_ids)
  for _, module_id in ipairs(module_ids or {}) do
    if modules[module_id] and modules[module_id].abstract == true then
      return true
    end
  end
  return false
end

local function _build_breadcrumb(prefix_segments)
  local breadcrumb = {
    { key = "root", label = "src" },
  }
  local current = {}
  for _, segment in ipairs(prefix_segments or {}) do
    current[#current + 1] = segment
    breadcrumb[#breadcrumb + 1] = {
      key = common.view_key(current),
      label = segment,
    }
  end
  return breadcrumb
end

local function _build_view(architecture, prefix_segments)
  local scoped_modules = _collect_scoped_modules(architecture.modules, prefix_segments)
  local module_child_map = _module_to_child(scoped_modules, prefix_segments)
  local child_info = _child_to_info(scoped_modules, prefix_segments, module_child_map)
  local module_node_map = _module_to_node(child_info)
  local node_modules = _node_to_modules(module_node_map)
  local child_graph = _node_graph(architecture.graph, scoped_modules, module_node_map)
  local child_layout = layers.assign_layers({
    nodes = child_graph.nodes,
    edges = child_graph.edges,
  })
  local child_feedback_set = _feedback_edge_set(child_layout)
  local module_feedback = _module_feedback_set(architecture.layout)
  local node_layer_map = child_layout.module_to_layer or {}
  local node_items = {}

  for node_id, module_ids in common.sorted_pairs(node_modules) do
    local child_name = _is_mixed_leaf(node_id) and node_id:sub(1, #node_id - #MIXED_LEAF_SUFFIX) or node_id
    local info = child_info[child_name]
    local mixed_leaf = _is_mixed_leaf(node_id)
    local module_id = mixed_leaf and info.exact_module or ((info and next(info.descendant_modules) == nil) and info.exact_module or nil)
    local leaf = module_id ~= nil
    local child_prefix = common.copy_array(prefix_segments)
    child_prefix[#child_prefix + 1] = child_name
    local has_descendants = info ~= nil and next(info.descendant_modules) ~= nil or false
    local has_cycle = false
    for _, descendant_id in ipairs(module_ids) do
      if module_feedback[descendant_id] then
        has_cycle = true
        break
      end
    end

    local item = {
      id = node_id,
      label = _node_label(child_name, mixed_leaf),
      child_name = child_name,
      layer = node_layer_map[node_id] or 0,
      leaf = leaf,
      mixed_leaf = mixed_leaf,
      component = _node_component(architecture.modules, module_ids),
      abstract = _node_abstract(architecture.modules, module_ids),
      has_cycle = has_cycle,
      module_ids = common.copy_array(module_ids),
      view_key = (has_descendants and not leaf) and common.view_key(child_prefix) or nil,
    }

    if leaf then
      local module_info = architecture.modules[module_id]
      item.module_id = module_id
      item.source_path = module_info.source_path
      item.source_text = module_info.source_text
      item.internal_requires = common.copy_array(module_info.internal_requires)
      item.external_requires = common.copy_array(module_info.external_requires)
    end

    node_items[#node_items + 1] = item
  end

  table.sort(node_items, function(left, right)
    if left.layer == right.layer then
      return left.label < right.label
    end
    return left.layer < right.layer
  end)

  local edge_items = {}
  for _, edge in ipairs(child_graph.edges or {}) do
    edge.feedback = child_feedback_set[common.edge_key(edge.from, edge.to)] == true
    edge_items[#edge_items + 1] = edge
  end

  local views = {
    [common.view_key(prefix_segments)] = {
      key = common.view_key(prefix_segments),
      label = #prefix_segments == 0 and "src" or prefix_segments[#prefix_segments],
      breadcrumb = _build_breadcrumb(prefix_segments),
      nodes = node_items,
      edges = edge_items,
    },
  }

  for child_name, info in common.sorted_pairs(child_info) do
    if next(info.descendant_modules) ~= nil then
      local child_prefix = common.copy_array(prefix_segments)
      child_prefix[#child_prefix + 1] = child_name
      local nested_views = _build_view(architecture, child_prefix)
      for view_key, view in pairs(nested_views) do
        views[view_key] = view
      end
    end
  end

  return views
end

function projection.build_views(architecture)
  return _build_view(architecture, {})
end

return projection
