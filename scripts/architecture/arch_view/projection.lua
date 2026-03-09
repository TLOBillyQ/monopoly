local common = require("arch_view.common")
local layers = require("arch_view.layers")
local route_engine = require("arch_view.route_engine")

local projection = {}

local MIXED_LEAF_SUFFIX = "|file"
local CANVAS_WIDTH = 1180.0
local NODE_WIDTH = 188.0
local NODE_HEIGHT = 86.0
local LAYER_GAP = 176.0
local HORIZONTAL_GAP = 44.0
local PADDING_X = 72.0
local PADDING_TOP = 72.0
local LAYER_LABEL_HEIGHT = 28.0

local function _mixed_leaf_id(child_name)
  return child_name .. MIXED_LEAF_SUFFIX
end

local function _is_mixed_leaf(node_id)
  return tostring(node_id):sub(-#MIXED_LEAF_SUFFIX) == MIXED_LEAF_SUFFIX
end

local function _node_child_name(node_id)
  if _is_mixed_leaf(node_id) then
    return node_id:sub(1, #node_id - #MIXED_LEAF_SUFFIX)
  end
  return node_id
end

local function _stripped_module_name(module_id)
  return common.strip_src_prefix(module_id)
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

local function _module_feedback_set(layout)
  local involved = {}
  for _, edge in ipairs((layout and layout.feedback_edges) or {}) do
    involved[edge.from] = true
    involved[edge.to] = true
  end
  return involved
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

local function _display_label_for_node(node_id, child_info, modules)
  local child_name = _node_child_name(node_id)
  local info = child_info[child_name]
  local exact_module = info and info.exact_module or nil
  if exact_module ~= nil then
    local source_file_name = common.source_filename_base(modules[exact_module] and modules[exact_module].source_path or nil)
    if source_file_name ~= nil and source_file_name ~= "" then
      return source_file_name
    end
  end
  return child_name
end

local function _full_name_for_node(node_id, prefix_segments, child_info, modules)
  local child_name = _node_child_name(node_id)
  local info = child_info[child_name]
  if info and info.exact_module ~= nil and next(info.descendant_modules) == nil then
    return _stripped_module_name(info.exact_module)
  end
  if info and _is_mixed_leaf(node_id) and info.exact_module ~= nil then
    return _stripped_module_name(info.exact_module)
  end

  local full_name = common.copy_array(prefix_segments)
  full_name[#full_name + 1] = child_name
  return table.concat(full_name, ".")
end

local function _build_pair_map(entries)
  local pair_map = {}
  for _, entry in ipairs(entries or {}) do
    local key = common.edge_key(entry.from, entry.to)
    local existing = pair_map[key]
    if existing == nil then
      existing = {
        from = entry.from,
        to = entry.to,
        type = entry.type,
        count = 0,
        module_edges = {},
      }
      pair_map[key] = existing
    end
    existing.count = existing.count + 1
    if entry.type == "abstract" then
      existing.type = "abstract"
    end
    existing.module_edges[#existing.module_edges + 1] = {
      from = entry.module_from,
      to = entry.module_to,
      type = entry.type,
      cycle = entry.cycle,
      text = entry.text,
    }
  end
  return pair_map
end

local function _append_sorted_entries(edge)
  table.sort(edge.module_edges, function(left, right)
    if left.from == right.from then
      if left.to == right.to then
        return tostring(left.type) < tostring(right.type)
      end
      return left.to < right.to
    end
    return left.from < right.from
  end)

  local tooltip_lines = {}
  local tooltip_objects = {}
  for _, module_edge in ipairs(edge.module_edges) do
    local text = module_edge.text .. " (" .. tostring(1) .. ")"
    tooltip_lines[#tooltip_lines + 1] = text
    tooltip_objects[#tooltip_objects + 1] = {
      text = text,
      cycle = module_edge.cycle == true,
      type = module_edge.type,
    }
  end
  edge.tooltip_lines = tooltip_lines
  edge.tooltip = tooltip_objects
  edge.arrowhead = edge.type == "abstract" and "closed-triangle" or "standard"
end

local function _build_edge_maps(architecture, scoped_modules, module_node_map, module_feedback)
  local internal_entries = {}
  local outgoing_by_node = {}
  local incoming_by_node = {}

  for _, edge in ipairs(architecture.classified_edges or {}) do
    local from_in = scoped_modules[edge.from] ~= nil
    local to_in = scoped_modules[edge.to] ~= nil
    if from_in or to_in then
      local from_node = from_in and module_node_map[edge.from] or nil
      local to_node = to_in and module_node_map[edge.to] or nil
      local text = _stripped_module_name(edge.from) .. " -> " .. _stripped_module_name(edge.to)
      local cycle = module_feedback[edge.from] == true or module_feedback[edge.to] == true

      if from_node ~= nil and to_node ~= nil and from_node ~= to_node then
        internal_entries[#internal_entries + 1] = {
          from = from_node,
          to = to_node,
          module_from = edge.from,
          module_to = edge.to,
          type = edge.type,
          cycle = cycle,
          text = text,
        }
      end

      if from_node ~= nil then
        outgoing_by_node[from_node] = outgoing_by_node[from_node] or {}
        outgoing_by_node[from_node][#outgoing_by_node[from_node] + 1] = {
          direction = "outgoing",
          from = edge.from,
          to = edge.to,
          text = text .. " (1)",
          type = edge.type,
          cycle = cycle,
        }
      end

      if to_node ~= nil then
        incoming_by_node[to_node] = incoming_by_node[to_node] or {}
        incoming_by_node[to_node][#incoming_by_node[to_node] + 1] = {
          direction = "incoming",
          from = edge.from,
          to = edge.to,
          text = text .. " (1)",
          type = edge.type,
          cycle = cycle,
        }
      end
    end
  end

  local pair_map = _build_pair_map(internal_entries)
  local classified_edges = {}
  for _, edge in common.sorted_pairs(pair_map) do
    _append_sorted_entries(edge)
    classified_edges[#classified_edges + 1] = edge
  end
  table.sort(classified_edges, function(left, right)
    if left.from == right.from then
      return left.to < right.to
    end
    return left.from < right.from
  end)

  for _, list in pairs(outgoing_by_node) do
    table.sort(list, function(left, right)
      if left.to == right.to then
        return left.from < right.from
      end
      return left.to < right.to
    end)
  end
  for _, list in pairs(incoming_by_node) do
    table.sort(list, function(left, right)
      if left.from == right.from then
        return left.to < right.to
      end
      return left.from < right.from
    end)
  end

  return {
    classified_edges = classified_edges,
    display_edges = common.copy_array(classified_edges),
    outgoing_by_node = outgoing_by_node,
    incoming_by_node = incoming_by_node,
  }
end

local function _build_layer_rects(child_layout)
  local layer_rects = {}
  for _, layer in ipairs((child_layout and child_layout.layers) or {}) do
    local node_count = #(layer.modules or {})
    local total_width = node_count * NODE_WIDTH + math.max(0, node_count - 1) * HORIZONTAL_GAP
    local start_x = math.max(PADDING_X, (CANVAS_WIDTH - total_width) / 2.0)
    local layer_y = PADDING_TOP + layer.index * LAYER_GAP
    layer_rects[layer.index] = {
      x = start_x,
      y = layer_y,
      width = total_width,
      height = NODE_HEIGHT,
    }
  end
  return layer_rects
end

local function _build_node_rects(child_layout, display_labels, full_names)
  local node_rects = {}
  local layer_items = {}
  local layer_rects = _build_layer_rects(child_layout)

  for _, layer in ipairs((child_layout and child_layout.layers) or {}) do
    local layer_rect = layer_rects[layer.index]
    local node_ids = common.copy_array(layer.modules)
    local nodes = {}
    for index, node_id in ipairs(node_ids) do
      local x = layer_rect.x + (index - 1) * (NODE_WIDTH + HORIZONTAL_GAP)
      local y = layer_rect.y + LAYER_LABEL_HEIGHT
      local rect = {
        x = x,
        y = y,
        width = NODE_WIDTH,
        height = NODE_HEIGHT,
      }
      node_rects[node_id] = rect
      nodes[#nodes + 1] = {
        id = node_id,
        display_label = display_labels[node_id],
        full_name = full_names[node_id],
        rect = rect,
      }
    end
    layer_items[#layer_items + 1] = {
      index = layer.index,
      label = "Layer " .. tostring(layer.index),
      full_name = "Layer " .. tostring(layer.index),
      node_ids = node_ids,
      nodes = nodes,
      rect = {
        x = layer_rect.x,
        y = layer_rect.y,
        width = layer_rect.width,
        height = NODE_HEIGHT + LAYER_LABEL_HEIGHT,
      },
    }
  end

  return node_rects, layer_items
end

local function _build_indicators(node_items)
  local indicators = {}
  for _, node in ipairs(node_items or {}) do
    if #(node.incoming_dependencies or {}) > 0 then
      local tooltip_lines = {}
      local tooltip = {}
      for _, entry in ipairs(node.incoming_dependencies) do
        tooltip_lines[#tooltip_lines + 1] = entry.text
        tooltip[#tooltip + 1] = {
          text = entry.text,
          cycle = entry.cycle,
          type = entry.type,
        }
      end
      indicators[#indicators + 1] = {
        id = node.id .. ":incoming",
        node_id = node.id,
        direction = "incoming",
        cycle = node.has_cycle_subtree == true,
        count = #tooltip_lines,
        tooltip_lines = tooltip_lines,
        tooltip = tooltip,
      }
    end
    if #(node.outgoing_dependencies or {}) > 0 then
      local tooltip_lines = {}
      local tooltip = {}
      for _, entry in ipairs(node.outgoing_dependencies) do
        tooltip_lines[#tooltip_lines + 1] = entry.text
        tooltip[#tooltip + 1] = {
          text = entry.text,
          cycle = entry.cycle,
          type = entry.type,
        }
      end
      indicators[#indicators + 1] = {
        id = node.id .. ":outgoing",
        node_id = node.id,
        direction = "outgoing",
        cycle = node.has_cycle_subtree == true,
        count = #tooltip_lines,
        tooltip_lines = tooltip_lines,
        tooltip = tooltip,
      }
    end
  end
  return indicators
end

local function _decorate_display_edges(display_edges, node_rects, node_layer_map, child_feedback_set)
  local route_input = {}
  for _, edge in ipairs(display_edges or {}) do
    local next_edge = {}
    for key, value in pairs(edge) do
      next_edge[key] = value
    end
    next_edge.module_edges = common.copy_array(edge.module_edges or {})
    next_edge.tooltip = common.copy_array(edge.tooltip or {})
    next_edge.tooltip_lines = common.copy_array(edge.tooltip_lines or {})
    next_edge.feedback = child_feedback_set[common.edge_key(edge.from, edge.to)] == true
    next_edge.from_rect = node_rects[edge.from]
    next_edge.to_rect = node_rects[edge.to]
    next_edge.from_layer = node_layer_map[edge.from] or 0
    next_edge.to_layer = node_layer_map[edge.to] or 0
    next_edge.id = edge.from .. "->" .. edge.to
    route_input[#route_input + 1] = next_edge
  end

  local routed = route_engine.route_edges(route_input)
  for _, edge in ipairs(routed) do
    edge.module_edges = edge.module_edges or {}
    edge.cycle = edge.feedback == true
    if edge.cycle ~= true then
      for _, module_edge in ipairs(edge.module_edges) do
        if module_edge.cycle == true then
          edge.cycle = true
          break
        end
      end
    end
  end
  return routed
end

local function _build_view(architecture, prefix_segments)
  local scoped_modules = _collect_scoped_modules(architecture.modules, prefix_segments)
  local module_child_map = _module_to_child(scoped_modules, prefix_segments)
  local child_info = _child_to_info(scoped_modules, prefix_segments, module_child_map)
  local module_node_map = _module_to_node(child_info)
  local node_modules = _node_to_modules(module_node_map)
  local child_nodes = common.sorted_keys(node_modules)
  local child_graph = {
    nodes = child_nodes,
    edges = {},
  }
  local child_layout = layers.assign_layers({
    nodes = child_nodes,
    edges = {},
  })
  local child_feedback_set = {}
  local node_layer_map = {}
  local module_feedback = _module_feedback_set(architecture.layout)
  local display_labels = {}
  local full_names = {}
  local node_items = {}

  local edge_maps = _build_edge_maps(architecture, scoped_modules, module_node_map, module_feedback)
  for _, edge in ipairs(edge_maps.classified_edges) do
    child_graph.edges[#child_graph.edges + 1] = {
      from = edge.from,
      to = edge.to,
    }
  end
  child_layout = layers.assign_layers(child_graph)
  for _, edge in ipairs((child_layout and child_layout.feedback_edges) or {}) do
    child_feedback_set[common.edge_key(edge.from, edge.to)] = true
  end
  node_layer_map = child_layout.module_to_layer or {}

  for node_id in common.sorted_pairs(node_modules) do
    display_labels[node_id] = _display_label_for_node(node_id, child_info, architecture.modules)
    full_names[node_id] = _full_name_for_node(node_id, prefix_segments, child_info, architecture.modules)
  end

  local node_rects, layer_items = _build_node_rects(child_layout, display_labels, full_names)

  for node_id, module_ids in common.sorted_pairs(node_modules) do
    local child_name = _node_child_name(node_id)
    local info = child_info[child_name]
    local exact_module = info and info.exact_module or nil
    local has_descendants = info ~= nil and next(info.descendant_modules) ~= nil or false
    local leaf = exact_module ~= nil and not has_descendants or _is_mixed_leaf(node_id)
    local child_prefix = common.copy_array(prefix_segments)
    child_prefix[#child_prefix + 1] = child_name
    local source_file_name = exact_module and common.source_filename_base(architecture.modules[exact_module] and architecture.modules[exact_module].source_path or nil) or nil
    local item = {
      id = node_id,
      label = display_labels[node_id],
      display_label = display_labels[node_id],
      full_name = full_names[node_id],
      child_name = child_name,
      source_file_name = source_file_name,
      layer = node_layer_map[node_id] or 0,
      leaf = leaf,
      drillable = has_descendants,
      component = _node_component(architecture.modules, module_ids),
      abstract = _node_abstract(architecture.modules, module_ids),
      has_cycle_subtree = false,
      cycle = false,
      module_ids = common.copy_array(module_ids),
      rect = node_rects[node_id],
      view_key = has_descendants and common.view_key(child_prefix) or nil,
      incoming_dependencies = common.copy_array(edge_maps.incoming_by_node[node_id] or {}),
      outgoing_dependencies = common.copy_array(edge_maps.outgoing_by_node[node_id] or {}),
    }

    for _, descendant_id in ipairs(module_ids) do
      if module_feedback[descendant_id] == true then
        item.has_cycle_subtree = true
        item.cycle = true
        break
      end
    end

    if exact_module ~= nil then
      local module_info = architecture.modules[exact_module]
      item.module_id = exact_module
      item.source_path = module_info.source_path
      item.source_text = module_info.source_text
      item.internal_requires = common.copy_array(module_info.internal_requires)
      item.external_requires = common.copy_array(module_info.external_requires)
    end

    node_items[#node_items + 1] = item
  end

  table.sort(node_items, function(left, right)
    if left.layer == right.layer then
      return left.display_label < right.display_label
    end
    return left.layer < right.layer
  end)

  local display_edges = _decorate_display_edges(edge_maps.display_edges, node_rects, node_layer_map, child_feedback_set)
  local indicators = _build_indicators(node_items)
  local canvas_height = PADDING_TOP + math.max(1, #layer_items) * LAYER_GAP + NODE_HEIGHT + 80.0

  local views = {
    [common.view_key(prefix_segments)] = {
      key = common.view_key(prefix_segments),
      label = #prefix_segments == 0 and "src" or prefix_segments[#prefix_segments],
      title = #prefix_segments == 0 and "src" or prefix_segments[#prefix_segments],
      breadcrumb = _build_breadcrumb(prefix_segments),
      canvas = {
        width = CANVAS_WIDTH,
        height = canvas_height,
      },
      layers = layer_items,
      nodes = node_items,
      edges = display_edges,
      classified_edges = edge_maps.classified_edges,
      display_edges = display_edges,
      indicators = indicators,
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
