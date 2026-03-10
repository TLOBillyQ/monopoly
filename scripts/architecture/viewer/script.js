(function () {
  var NODE_WIDTH = 188;
  var NODE_HEIGHT = 86;
  var CARD_GAP_X = 44;
  var CARD_GAP_Y = 0;
  var LAYER_TOP = 100;
  var LAYER_GAP = 176;
  var SURFACE_PADDING_X = 72;
  var SURFACE_PADDING_BOTTOM = 80;
  var LABEL_Y_OFFSET = 28;
  var TRIANGLE_OFFSET = 10;

  function by_id(id) {
    return document.getElementById(id);
  }

  function to_array(value) {
    if (Array.isArray(value)) {
      return value;
    }
    if (value === null || value === undefined) {
      return [];
    }
    if (typeof value === "object") {
      return Object.keys(value).map(function (key) {
        var item = value[key];
        if (item && typeof item === "object" && !Array.isArray(item)) {
          return Object.assign({ id: item.id || key }, item);
        }
        return { id: key, value: item };
      });
    }
    return [];
  }

  function unique_sorted(list) {
    return Array.from(new Set((list || []).filter(Boolean))).sort();
  }

  function html_escape(text) {
    return String(text === undefined || text === null ? "" : text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function plain_label(text) {
    return String(text || "").replace(/^src\./, "");
  }

  function source_file_name(path) {
    if (!path) {
      return "";
    }
    var normalized = String(path).replace(/\\/g, "/");
    var match = normalized.match(/([^/]+)\.[^.]+$/);
    return match ? match[1] : normalized.split("/").pop();
  }

  function finite_number(value) {
    return typeof value === "number" && Number.isFinite(value);
  }

  function feedback_lookup(data) {
    var lookup = Object.create(null);
    var layout = data.layout || {};
    to_array(layout.feedback_edges).forEach(function (edge) {
      var from = edge && (edge.from || edge.source || edge.start);
      var to = edge && (edge.to || edge.target || edge.finish);
      if (from && to) {
        lookup[from + "->" + to] = true;
      }
    });
    return lookup;
  }

  function cycle_lookup(data) {
    var lookup = Object.create(null);
    var check = data.check || {};
    to_array(check.cycles).forEach(function (cycle) {
      if (Array.isArray(cycle)) {
        cycle.forEach(function (id) {
          lookup[id] = true;
        });
      } else if (cycle && Array.isArray(cycle.modules)) {
        cycle.modules.forEach(function (id) {
          lookup[id] = true;
        });
      }
    });
    return lookup;
  }

  function normalize_module(module_id, raw_module, cycle_by_id) {
    var source_text =
      raw_module &&
      (raw_module.source_text ||
        raw_module.source ||
        raw_module.contents ||
        "");
    return {
      id: module_id,
      name:
        (raw_module &&
          (raw_module.name || raw_module.label || raw_module.display_label)) ||
        plain_label(module_id),
      full_name:
        (raw_module &&
          (raw_module.full_name || raw_module.module_id || module_id)) ||
        module_id,
      component:
        raw_module && raw_module.component ? raw_module.component : null,
      abstract:
        raw_module &&
        (raw_module.abstract === true || raw_module.kind === "abstract"),
      source_path:
        raw_module && raw_module.source_path ? raw_module.source_path : "",
      source_text:
        typeof source_text === "string"
          ? source_text
          : JSON.stringify(source_text, null, 2),
      internal_requires: unique_sorted(
        (raw_module &&
          (raw_module.internal_requires ||
            raw_module.internal_dependencies ||
            raw_module.requires)) ||
          [],
      ),
      external_requires: unique_sorted(
        (raw_module &&
          (raw_module.external_requires || raw_module.external_dependencies)) ||
          [],
      ),
      cycle:
        cycle_by_id[module_id] === true ||
        (raw_module && raw_module.cycle === true),
    };
  }

  function normalize_modules(data) {
    var cycle_by_id = cycle_lookup(data);
    var modules = Object.create(null);
    Object.keys(data.modules || {}).forEach(function (module_id) {
      modules[module_id] = normalize_module(
        module_id,
        data.modules[module_id],
        cycle_by_id,
      );
    });
    return modules;
  }

  function view_key_for_breadcrumb(crumb, index) {
    if (crumb && typeof crumb === "object") {
      return crumb.key || crumb.id || crumb.view_key || crumb.path || "";
    }
    return index === 0 ? "root" : String(crumb || "");
  }

  function normalize_breadcrumb(view_key, raw_breadcrumb) {
    var crumbs = to_array(raw_breadcrumb);
    if (crumbs.length === 0) {
      crumbs = [{ key: "root", label: "src" }];
      if (view_key && view_key !== "root") {
        crumbs.push({ key: view_key, label: view_key });
      }
    }
    return crumbs.map(function (crumb, index) {
      if (typeof crumb === "string") {
        return {
          key: index === 0 && crumb === "" ? "root" : crumb,
          label: crumb === "" ? "src" : crumb,
        };
      }
      return {
        key:
          view_key_for_breadcrumb(crumb, index) ||
          (index === 0 ? "root" : view_key),
        label:
          crumb.label ||
          crumb.name ||
          crumb.title ||
          crumb.key ||
          crumb.id ||
          (index === 0 ? "src" : view_key),
      };
    });
  }

  function normalized_layer_map(data) {
    var map = Object.create(null);
    var layout = data.layout || {};
    var raw = layout.module_to_layer || layout.module_to_level || {};
    Object.keys(raw).forEach(function (key) {
      map[key] = raw[key];
    });
    return map;
  }

  function normalize_dependency_entry(entry, fallback_text, cycle_by_id) {
    if (!entry) {
      return {
        text: fallback_text || "",
        cycle: false,
      };
    }
    if (typeof entry === "string") {
      return {
        text: entry,
        cycle: false,
      };
    }
    var text = entry.text;
    if (!text && entry.from && entry.to) {
      text = plain_label(entry.from) + " -> " + plain_label(entry.to);
      if (entry.count) {
        text = text + " (" + String(entry.count) + ")";
      }
    }
    if (!text) {
      text = fallback_text || "";
    }
    var cycle = entry.cycle === true || entry.feedback === true;
    if (!cycle && entry.module_edges) {
      cycle = to_array(entry.module_edges).some(function (module_edge) {
        return (
          cycle_by_id[module_edge.from] === true ||
          cycle_by_id[module_edge.to] === true
        );
      });
    }
    return {
      text: text,
      cycle: cycle,
    };
  }

  function normalize_indicator(direction, raw, cycle_by_id) {
    var indicator = raw || {};
    var dependencies = unique_sorted(
      to_array(indicator.tooltip_lines)
        .map(function (line) {
          return typeof line === "string" ? line : (line && line.text) || "";
        })
        .filter(Boolean),
    ).map(function (line) {
      return {
        text: line,
        cycle: false,
      };
    });

    if (dependencies.length === 0) {
      dependencies = to_array(indicator.dependencies).map(
        function (dep, index) {
          return normalize_dependency_entry(
            dep,
            direction + "_" + index,
            cycle_by_id,
          );
        },
      );
    }

    return {
      direction: direction,
      cycle:
        indicator.cycle === true ||
        indicator.has_cycle === true ||
        dependencies.some(function (dep) {
          return dep.cycle;
        }),
      dependencies: dependencies,
    };
  }

  function node_indicators_from_dependencies(node, cycle_by_id) {
    return {
      incoming: normalize_indicator(
        "incoming",
        {
          dependencies: to_array(node.incoming_dependencies).map(
            function (dep) {
              return normalize_dependency_entry(dep, "", cycle_by_id);
            },
          ),
        },
        cycle_by_id,
      ),
      outgoing: normalize_indicator(
        "outgoing",
        {
          dependencies: to_array(node.outgoing_dependencies).map(
            function (dep) {
              return normalize_dependency_entry(dep, "", cycle_by_id);
            },
          ),
        },
        cycle_by_id,
      ),
    };
  }

  function normalize_node(
    raw_node,
    index,
    modules,
    layer_map,
    feedback_by_edge,
    cycle_by_id,
  ) {
    var node = raw_node || {};
    var id =
      node.id ||
      node.key ||
      node.module_id ||
      node.module ||
      node.name ||
      "node_" + index;
    var module_ref = node.module_id || node.module || (modules[id] ? id : null);
    var module_info = module_ref ? modules[module_ref] : null;
    var is_leaf =
      node.leaf === true ||
      node.is_leaf === true ||
      (!!module_info && node.branch !== true && node.group !== true);
    var layer = node.layer;
    if (layer === undefined || layer === null) {
      layer = layer_map[id];
      if ((layer === undefined || layer === null) && module_ref) {
        layer = layer_map[module_ref];
      }
    }
    var abstract_flag =
      node.abstract === true ||
      node.is_abstract === true ||
      (module_info && module_info.abstract === true);
    var cycle_flag =
      node.cycle === true ||
      node.is_cycle === true ||
      node.has_cycle_subtree === true ||
      cycle_by_id[id] === true ||
      (module_ref && cycle_by_id[module_ref] === true);

    var normalized = {
      id: id,
      label: node.label || node.name || node.title || id,
      display_label:
        node.display_label || node.label || node.name || node.title || id,
      full_name:
        node.full_name ||
        (module_info && module_info.full_name) ||
        module_ref ||
        id,
      description: node.description || node.summary || "",
      view_key: node.view_key || node.child_view_key || node.next_view || id,
      module_id: module_ref,
      leaf: is_leaf,
      abstract: abstract_flag,
      cycle: cycle_flag,
      has_cycle_subtree: cycle_flag,
      drillable:
        node.drillable === true ||
        (!is_leaf &&
          !!(node.view_key || node.child_view_key || node.next_view)),
      component:
        node.component || (module_info && module_info.component) || null,
      source_path:
        node.source_path || (module_info && module_info.source_path) || "",
      source_text:
        node.source_text || (module_info && module_info.source_text) || "",
      source_file_name:
        node.source_file_name ||
        source_file_name(
          node.source_path || (module_info && module_info.source_path) || "",
        ),
      internal_requires: unique_sorted(
        node.internal_requires ||
          node.internal_dependencies ||
          (module_info && module_info.internal_requires) ||
          [],
      ),
      external_requires: unique_sorted(
        node.external_requires ||
          node.external_dependencies ||
          (module_info && module_info.external_requires) ||
          [],
      ),
      incoming_dependencies: to_array(node.incoming_dependencies),
      outgoing_dependencies: to_array(node.outgoing_dependencies),
      layer: typeof layer === "number" ? layer : 0,
      geometry: node.geometry || node.rect || null,
    };

    normalized.indicators = {
      incoming: normalize_indicator(
        "incoming",
        node.indicators && node.indicators.incoming,
        cycle_by_id,
      ),
      outgoing: normalize_indicator(
        "outgoing",
        node.indicators && node.indicators.outgoing,
        cycle_by_id,
      ),
    };

    if (
      normalized.indicators.incoming.dependencies.length === 0 &&
      normalized.indicators.outgoing.dependencies.length === 0
    ) {
      normalized.indicators = node_indicators_from_dependencies(
        normalized,
        cycle_by_id,
      );
    }

    return normalized;
  }

  function polyline_to_path(points) {
    if (!points || points.length === 0) {
      return "";
    }
    var commands = ["M " + points[0][0] + " " + points[0][1]];
    for (var index = 1; index < points.length; index += 1) {
      commands.push("L " + points[index][0] + " " + points[index][1]);
    }
    return commands.join(" ");
  }

  function edge_label(edge) {
    var text = plain_label(edge.from) + " -> " + plain_label(edge.to);
    return text + " (" + String(edge.count || 1) + ")";
  }

  function normalize_route_points(edge) {
    return to_array(edge.route_points)
      .map(function (point) {
        if (Array.isArray(point) && point.length >= 2) {
          return [Number(point[0]) || 0, Number(point[1]) || 0];
        }
        return null;
      })
      .filter(Boolean);
  }

  function normalize_edge(edge, fallback_id, feedback_by_edge, cycle_by_id) {
    if (!edge) {
      return null;
    }
    var from = edge.from || edge.source || edge.start;
    var to = edge.to || edge.target || edge.finish;
    if (!from || !to) {
      return null;
    }
    var module_edges = to_array(edge.module_edges);
    var cycle =
      edge.cycle === true ||
      edge.is_cycle === true ||
      edge.feedback === true ||
      edge.cycle_break === true;
    if (!cycle) {
      cycle = feedback_by_edge[from + "->" + to] === true;
    }
    if (!cycle) {
      cycle = module_edges.some(function (module_edge) {
        return (
          cycle_by_id[module_edge.from] === true ||
          cycle_by_id[module_edge.to] === true
        );
      });
    }
    var tooltip_lines = to_array(edge.tooltip_lines).map(function (line) {
      if (typeof line === "string") {
        return { text: line, cycle: false };
      }
      return normalize_dependency_entry(line, "", cycle_by_id);
    });
    if (tooltip_lines.length === 0 && module_edges.length > 0) {
      tooltip_lines = module_edges.map(function (module_edge) {
        return normalize_dependency_entry(
          {
            from: module_edge.from,
            to: module_edge.to,
            cycle:
              cycle_by_id[module_edge.from] === true ||
              cycle_by_id[module_edge.to] === true,
          },
          "",
          cycle_by_id,
        );
      });
    }

    return {
      id: edge.id || fallback_id || from + "->" + to,
      from: from,
      to: to,
      count:
        Number(edge.count) ||
        (module_edges.length > 0 ? module_edges.length : 1),
      type: edge.type || edge.kind || "direct",
      cycle: cycle,
      module_edges: module_edges,
      tooltip_lines: tooltip_lines,
      route_points: normalize_route_points(edge),
      path: "",
      label:
        edge.label ||
        edge_label({
          from: from,
          to: to,
          count:
            Number(edge.count) ||
            (module_edges.length > 0 ? module_edges.length : 1),
        }),
    };
  }

  function derived_layers(nodes, raw_view) {
    var raw_layers = to_array(raw_view && raw_view.layers);
    if (raw_layers.length > 0) {
      return raw_layers.map(function (layer, index) {
        var node_ids = [];
        if (Array.isArray(layer.node_ids) && layer.node_ids.length > 0) {
          node_ids = unique_sorted(layer.node_ids);
        } else if (Array.isArray(layer.nodes) && layer.nodes.length > 0) {
          node_ids = unique_sorted(
            layer.nodes
              .map(function (node) {
                return typeof node === "string" ? node : node && node.id;
              })
              .filter(Boolean),
          );
        } else {
          node_ids = unique_sorted(layer.modules || []);
        }
        return {
          index: typeof layer.index === "number" ? layer.index : index,
          label:
            layer.label ||
            "Layer " +
              String(typeof layer.index === "number" ? layer.index : index),
          nodes: node_ids,
          rect: layer.rect || null,
        };
      });
    }

    var buckets = Object.create(null);
    nodes.forEach(function (node) {
      var key = String(node.layer || 0);
      if (!buckets[key]) {
        buckets[key] = [];
      }
      buckets[key].push(node.id);
    });

    return Object.keys(buckets)
      .map(function (key) {
        return {
          index: Number(key),
          label: "Layer " + key,
          nodes: buckets[key],
          rect: null,
        };
      })
      .sort(function (left, right) {
        return left.index - right.index;
      });
  }

  function fallback_root_view(
    modules,
    layer_map,
    feedback_by_edge,
    cycle_by_id,
  ) {
    var root_modules = Object.keys(modules).map(function (module_id) {
      return {
        id: module_id,
        label: modules[module_id].name,
        display_label: modules[module_id].name,
        full_name: modules[module_id].full_name,
        module_id: module_id,
        leaf: true,
        abstract: modules[module_id].abstract,
        cycle: modules[module_id].cycle,
        component: modules[module_id].component,
        source_path: modules[module_id].source_path,
        source_text: modules[module_id].source_text,
        internal_requires: modules[module_id].internal_requires,
        external_requires: modules[module_id].external_requires,
        layer: layer_map[module_id] || 0,
      };
    });
    var graph_edges = to_array(
      (window.ARCH_VIEW_DATA.graph && window.ARCH_VIEW_DATA.graph.edges) || [],
    )
      .map(function (edge, index) {
        return normalize_edge(
          edge,
          "root_edge_" + index,
          feedback_by_edge,
          cycle_by_id,
        );
      })
      .filter(Boolean);
    return {
      title: "root",
      breadcrumb: [{ key: "root", label: "src" }],
      nodes: root_modules,
      display_edges: graph_edges,
    };
  }

  function normalize_view(
    view_key,
    raw_view,
    modules,
    layer_map,
    feedback_by_edge,
    cycle_by_id,
  ) {
    var view = raw_view || {};
    var nodes = to_array(view.nodes).map(function (node, index) {
      return normalize_node(
        node,
        index,
        modules,
        layer_map,
        feedback_by_edge,
        cycle_by_id,
      );
    });
    var node_ids = Object.create(null);
    nodes.forEach(function (node) {
      node_ids[node.id] = true;
    });

    var display_edges = to_array(
      view.display_edges && view.display_edges.length
        ? view.display_edges
        : view.edges || [],
    )
      .map(function (edge, index) {
        return normalize_edge(
          edge,
          view_key + "_edge_" + index,
          feedback_by_edge,
          cycle_by_id,
        );
      })
      .filter(function (edge) {
        return (
          !!edge && node_ids[edge.from] === true && node_ids[edge.to] === true
        );
      });

    return {
      key: view_key,
      title: view.title || view.label || view_key,
      breadcrumb: normalize_breadcrumb(view_key, view.breadcrumb),
      nodes: nodes,
      display_edges: display_edges,
      layers: derived_layers(nodes, view),
    };
  }

  function normalize_data(raw_data) {
    var data = raw_data || {};
    var feedback_by_edge = feedback_lookup(data);
    var cycle_by_id = cycle_lookup(data);
    var modules = normalize_modules(data);
    var layer_map = normalized_layer_map(data);
    var normalized_views = Object.create(null);

    Object.keys(data.views || {}).forEach(function (view_key) {
      normalized_views[view_key] = normalize_view(
        view_key,
        data.views[view_key],
        modules,
        layer_map,
        feedback_by_edge,
        cycle_by_id,
      );
    });

    if (!normalized_views.root) {
      normalized_views.root = normalize_view(
        "root",
        fallback_root_view(modules, layer_map, feedback_by_edge, cycle_by_id),
        modules,
        layer_map,
        feedback_by_edge,
        cycle_by_id,
      );
    }

    return {
      raw: data,
      modules: modules,
      views: normalized_views,
      feedback_by_edge: feedback_by_edge,
      cycle_by_id: cycle_by_id,
    };
  }

  function render_metadata(target, rows) {
    if (!rows || rows.length === 0) {
      target.innerHTML = "<dt>Status</dt><dd>Unavailable</dd>";
      return;
    }
    target.innerHTML = rows
      .map(function (row) {
        return (
          "<dt>" +
          html_escape(row.label) +
          "</dt><dd>" +
          html_escape(row.value) +
          "</dd>"
        );
      })
      .join("");
  }

  function create_empty_message(target, text) {
    target.classList.add("empty_state");
    target.innerHTML = "<li>" + html_escape(text) + "</li>";
  }

  function render_token_list(target, items, fallback) {
    if (!items || items.length === 0) {
      create_empty_message(target, fallback);
      return;
    }
    target.classList.remove("empty_state");
    target.innerHTML = items
      .map(function (item) {
        return "<li>" + html_escape(item) + "</li>";
      })
      .join("");
  }

  function render_inspector(node) {
    var title = by_id("detail_title");
    var subtitle = by_id("detail_subtitle");
    var metadata = by_id("metadata_list");
    var internal_list = by_id("internal_dependency_list");
    var external_list = by_id("external_dependency_list");
    var source_code = by_id("source_code");
    var source_path = by_id("source_path_label");

    if (!node) {
      title.textContent = "Select a leaf module";
      subtitle.textContent =
        "Click a non-leaf node to drill down. Click a leaf node to inspect source and dependencies.";
      render_metadata(metadata, []);
      create_empty_message(internal_list, "No module selected.");
      create_empty_message(external_list, "No module selected.");
      source_path.textContent = "";
      source_code.textContent = "No module selected.";
      source_code.classList.add("empty_state");
      return;
    }

    title.textContent = node.display_label || node.label;
    subtitle.textContent = node.cycle
      ? "This module participates in, or sits under, a known dependency cycle."
      : "Leaf module details from the exported architecture payload.";

    render_metadata(metadata, [
      { label: "Module", value: node.module_id || node.id },
      {
        label: "Full Name",
        value: plain_label(node.full_name || node.module_id || node.id),
      },
      { label: "Component", value: node.component || "unclassified" },
      { label: "Layer", value: String(node.layer) },
      { label: "Abstract", value: node.abstract ? "yes" : "no" },
      { label: "Cycle", value: node.cycle ? "yes" : "no" },
    ]);

    render_token_list(
      internal_list,
      node.internal_requires,
      "No internal dependencies.",
    );
    render_token_list(
      external_list,
      node.external_requires,
      "No external dependencies.",
    );
    source_path.textContent = node.source_path || "";
    source_code.textContent =
      node.source_text || "Source text missing from payload.";
    source_code.classList.toggle("empty_state", !node.source_text);
  }

  function update_summary(view) {
    by_id("current_view_label").textContent = view.title || view.key;
    by_id("node_count_label").textContent = String(view.nodes.length);
    by_id("edge_count_label").textContent = String(view.display_edges.length);
    by_id("cycle_count_label").textContent = String(
      view.nodes.filter(function (node) {
        return node.cycle;
      }).length,
    );
  }

  function render_breadcrumb(view, state) {
    var root = by_id("breadcrumb");
    root.innerHTML = "";
    view.breadcrumb.forEach(function (crumb, index) {
      if (index > 0) {
        var divider = document.createElement("span");
        divider.textContent = "/";
        divider.className = "breadcrumb_current";
        root.appendChild(divider);
      }
      if (index === view.breadcrumb.length - 1) {
        var current = document.createElement("span");
        current.className = "breadcrumb_current";
        current.textContent = crumb.label;
        root.appendChild(current);
        return;
      }
      var button = document.createElement("button");
      button.type = "button";
      button.className = "breadcrumb_button";
      button.textContent = crumb.label;
      button.addEventListener("click", function () {
        state.open_view(crumb.key, false);
      });
      root.appendChild(button);
    });
  }

  function derive_layout(view) {
    var positions = Object.create(null);
    var layers = view.layers.slice().sort(function (left, right) {
      return left.index - right.index;
    });
    var max_width = 0;
    var max_height = 0;

    layers.forEach(function (layer, layer_index) {
      var y = null;
      layer.nodes.forEach(function (node_id) {
        var view_node = view.nodes.find(function (entry) {
          return entry.id === node_id;
        });
        var rect = view_node && view_node.geometry;
        if (rect && finite_number(rect.y)) {
          y = y === null ? rect.y : Math.min(y, rect.y);
        }
      });
      if (y === null) {
        y = LAYER_TOP + layer_index * LAYER_GAP + LABEL_Y_OFFSET;
      }
      layer.y = y - LABEL_Y_OFFSET;

      layer.nodes.forEach(function (node_id, index) {
        var view_node = view.nodes.find(function (entry) {
          return entry.id === node_id;
        });
        var rect = view_node && view_node.geometry;
        var width = rect && finite_number(rect.width) ? rect.width : NODE_WIDTH;
        var height =
          rect && finite_number(rect.height) ? rect.height : NODE_HEIGHT;
        var x =
          rect && finite_number(rect.x)
            ? rect.x
            : SURFACE_PADDING_X + index * (NODE_WIDTH + CARD_GAP_X);
        var node_y = rect && finite_number(rect.y) ? rect.y : y;
        positions[node_id] = {
          x: x,
          y: node_y,
          width: width,
          height: height,
          center_x: x + width / 2,
          center_y: node_y + height / 2,
        };
        max_width = Math.max(max_width, x + width + SURFACE_PADDING_X);
        max_height = Math.max(
          max_height,
          node_y + height + SURFACE_PADDING_BOTTOM,
        );
      });
    });

    var surface_width = Math.max(max_width, 1180);
    var surface_height = Math.max(
      max_height,
      LAYER_TOP +
        Math.max(layers.length, 1) * LAYER_GAP +
        NODE_HEIGHT +
        SURFACE_PADDING_BOTTOM,
    );

    return {
      layers: layers,
      positions: positions,
      width: surface_width,
      height: surface_height,
    };
  }

  function make_route_points(edge, positions) {
    if (edge.route_points.length > 0) {
      return edge.route_points;
    }
    var from = positions[edge.from];
    var to = positions[edge.to];
    if (!from || !to) {
      return [];
    }

    var from_y = from.y + from.height + TRIANGLE_OFFSET;
    var to_y = to.y - TRIANGLE_OFFSET;
    var pivot_y = (from_y + to_y) / 2;

    if (to.y <= from.y) {
      pivot_y = Math.min(from.y, to.y) - 34;
      from_y = from.y - TRIANGLE_OFFSET;
      to_y = to.y - TRIANGLE_OFFSET;
    }

    return [
      [from.center_x, from_y],
      [from.center_x, pivot_y],
      [to.center_x, pivot_y],
      [to.center_x, to_y],
    ];
  }

  function arrow_points(points) {
    if (!points || points.length < 2) {
      return "";
    }
    var end = points[points.length - 1];
    var prev = points[points.length - 2];
    var dx = end[0] - prev[0];
    var dy = end[1] - prev[1];
    var length = Math.sqrt(dx * dx + dy * dy) || 1;
    var ux = dx / length;
    var uy = dy / length;
    var px = -uy;
    var py = ux;
    var size = 9;
    var back_x = end[0] - ux * size;
    var back_y = end[1] - uy * size;
    var left_x = back_x + px * (size * 0.6);
    var left_y = back_y + py * (size * 0.6);
    var right_x = back_x - px * (size * 0.6);
    var right_y = back_y - py * (size * 0.6);
    return [
      end[0] + "," + end[1],
      left_x + "," + left_y,
      right_x + "," + right_y,
    ].join(" ");
  }

  function make_svg_el(tag) {
    return document.createElementNS("http://www.w3.org/2000/svg", tag);
  }

  function surface_point_from_event(event) {
    var surface_rect = by_id("graph_surface").getBoundingClientRect();
    return {
      x: event.clientX - surface_rect.left,
      y: event.clientY - surface_rect.top,
    };
  }

  function set_tooltip(content, x, y) {
    var tooltip = by_id("tooltip");
    tooltip.innerHTML = content;
    tooltip.hidden = false;
    var surface = by_id("graph_surface").getBoundingClientRect();
    var left = x + 18;
    var top = y + 18;
    tooltip.style.left = String(left) + "px";
    tooltip.style.top = String(top) + "px";

    requestAnimationFrame(function () {
      var box = tooltip.getBoundingClientRect();
      var surface_width = surface.width;
      var surface_height = surface.height;
      if (left + box.width > surface_width - 16) {
        tooltip.style.left = String(Math.max(16, x - box.width - 18)) + "px";
      }
      if (top + box.height > surface_height - 16) {
        tooltip.style.top = String(Math.max(16, y - box.height - 18)) + "px";
      }
    });
  }

  function hide_tooltip() {
    by_id("tooltip").hidden = true;
  }

  function tooltip_markup(title, lines) {
    return (
      '<p class="tooltip_title">' +
      html_escape(title) +
      "</p>" +
      '<ul class="tooltip_list">' +
      (lines || [])
        .map(function (entry) {
          return (
            '<li class="' +
            (entry.cycle ? "is_cycle" : "") +
            '">' +
            html_escape(entry.text) +
            "</li>"
          );
        })
        .join("") +
      "</ul>"
    );
  }

  function indicator_markup(direction, cycle) {
    var points =
      direction === "incoming" ? "10,0 20,16 0,16" : "0,0 20,0 10,16";
    return (
      '<svg viewBox="0 0 20 16" aria-hidden="true">' +
      '<polygon points="' +
      points +
      '"></polygon>' +
      "</svg>"
    );
  }

  function build_node_card(node, state) {
    var button = document.createElement("button");
    var class_name = "node_card";
    class_name += node.leaf ? " node_is_leaf" : " node_is_branch";
    if (node.abstract) {
      class_name += " node_is_abstract";
    }
    if (node.cycle) {
      class_name += " node_is_cycle";
    }
    if (node.drillable) {
      class_name += " node_is_drillable";
    }
    if (state.selected_leaf_id === node.id) {
      class_name += " node_is_selected";
    }
    button.type = "button";
    button.className = class_name;
    button.style.left = String(node.position.x) + "px";
    button.style.top = String(node.position.y) + "px";
    button.style.width = String(node.position.width) + "px";
    button.style.height = String(node.position.height) + "px";
    button.dataset.nodeId = node.id;

    button.innerHTML =
      '<div class="node_kicker">' +
      '<span class="node_tag">' +
      html_escape(node.leaf ? "leaf" : "group") +
      "</span>" +
      (node.component
        ? '<span class="node_tag">' + html_escape(node.component) + "</span>"
        : "") +
      (node.abstract
        ? '<span class="node_tag node_tag_abstract">abstract</span>'
        : "") +
      (node.cycle ? '<span class="node_tag node_tag_cycle">cycle</span>' : "") +
      "</div>" +
      '<div class="node_heading">' +
      "<div>" +
      '<h3 class="node_heading_title">' +
      html_escape(node.display_label || node.label) +
      "</h3>" +
      (node.source_file_name
        ? '<div class="node_source_name">' +
          html_escape(node.source_file_name) +
          "</div>"
        : "") +
      "</div>" +
      "</div>" +
      '<p class="node_supporting">' +
      html_escape(
        node.description ||
          (node.leaf
            ? "Inspect source and dependencies."
            : "Drill into nested namespace view."),
      ) +
      "</p>" +
      '<div class="node_dependency_summary">' +
      "<span>in " +
      String(node.indicators.incoming.dependencies.length) +
      "</span>" +
      "<span>out " +
      String(node.indicators.outgoing.dependencies.length) +
      "</span>" +
      "</div>";

    function attach_indicator(direction, indicator) {
      if (
        !indicator ||
        !indicator.dependencies ||
        indicator.dependencies.length === 0
      ) {
        return;
      }
      var anchor = document.createElement("button");
      anchor.type = "button";
      anchor.className =
        "node_dependency_button is_" +
        (direction === "incoming" ? "top" : "bottom");
      if (indicator.cycle) {
        anchor.className += " is_cycle";
      }
      anchor.innerHTML = indicator_markup(direction, indicator.cycle);
      function show_indicator_tooltip(event) {
        event.stopPropagation();
        set_tooltip(
          tooltip_markup(
            direction === "incoming" ? "Incoming" : "Outgoing",
            indicator.dependencies,
          ),
          node.position.center_x,
          direction === "incoming"
            ? node.position.y - 12
            : node.position.y + node.position.height + 12,
        );
      }
      anchor.addEventListener("mouseenter", show_indicator_tooltip);
      anchor.addEventListener("mousemove", show_indicator_tooltip);
      anchor.addEventListener("mouseleave", hide_tooltip);
      button.appendChild(anchor);
    }

    attach_indicator("incoming", node.indicators.incoming);
    attach_indicator("outgoing", node.indicators.outgoing);

    button.addEventListener("mouseenter", function (event) {
      if (
        event.target &&
        event.target.closest &&
        event.target.closest(".node_dependency_button")
      ) {
        return;
      }
      var point = surface_point_from_event(event);
      set_tooltip(
        tooltip_markup("Module", [
          {
            text: plain_label(node.full_name || node.module_id || node.id),
            cycle: node.cycle,
          },
        ]),
        point.x,
        point.y,
      );
    });
    button.addEventListener("mousemove", function (event) {
      if (
        event.target &&
        event.target.closest &&
        event.target.closest(".node_dependency_button")
      ) {
        return;
      }
      var point = surface_point_from_event(event);
      set_tooltip(
        tooltip_markup("Module", [
          {
            text: plain_label(node.full_name || node.module_id || node.id),
            cycle: node.cycle,
          },
        ]),
        point.x,
        point.y,
      );
    });
    button.addEventListener("mouseleave", hide_tooltip);
    button.addEventListener("click", function () {
      if (node.leaf) {
        state.selected_leaf_id = node.id;
        state.view_state[state.current_view_key] = Object.assign(
          {},
          state.view_state[state.current_view_key],
          {
            selected_leaf_id: node.id,
          },
        );
        render_inspector(node);
        render_view(state.current_view_key, state);
        return;
      }
      if (node.drillable && node.view_key) {
        state.open_view(node.view_key, true);
      }
    });

    return button;
  }

  function render_layer_labels(layout) {
    var layer_labels = by_id("layer_labels");
    layer_labels.innerHTML = "";
    layout.layers.forEach(function (layer) {
      if (layer.nodes.length === 0) {
        return;
      }
      var first_node = layout.positions[layer.nodes[0]];
      var last_node = layout.positions[layer.nodes[layer.nodes.length - 1]];
      var label = document.createElement("div");
      label.className = "layer_label";
      label.textContent = layer.label || "Layer " + String(layer.index);
      label.style.left =
        String((first_node.center_x + last_node.center_x) / 2) + "px";
      label.style.top = String(layer.y - LABEL_Y_OFFSET) + "px";
      label.addEventListener("mouseenter", function () {
        set_tooltip(
          tooltip_markup("Layer", [
            {
              text: String(layer.label || "Layer " + String(layer.index)),
              cycle: false,
            },
          ]),
          (first_node.center_x + last_node.center_x) / 2,
          layer.y - LABEL_Y_OFFSET,
        );
      });
      label.addEventListener("mouseleave", hide_tooltip);
      layer_labels.appendChild(label);
    });
  }

  function render_edges(view) {
    var svg = by_id("graph_svg");
    svg.innerHTML = "";
    view.display_edges.forEach(function (edge) {
      if (!edge.path) {
        return;
      }
      var path = make_svg_el("path");
      path.setAttribute("d", edge.path);
      path.setAttribute(
        "class",
        "graph_edge edge_type_" +
          html_escape(edge.type || "direct") +
          (edge.cycle ? " edge_is_cycle" : ""),
      );
      svg.appendChild(path);

      var hit = make_svg_el("path");
      hit.setAttribute("d", edge.path);
      hit.setAttribute("class", "graph_edge_hit");
      hit.addEventListener("mouseenter", function (event) {
        var point = surface_point_from_event(event);
        var tooltip_lines =
          edge.tooltip_lines.length > 0
            ? edge.tooltip_lines
            : [{ text: edge.label, cycle: edge.cycle }];
        set_tooltip(
          tooltip_markup("Dependency", tooltip_lines),
          point.x,
          point.y,
        );
      });
      hit.addEventListener("mousemove", function (event) {
        var point = surface_point_from_event(event);
        set_tooltip(
          tooltip_markup(
            "Dependency",
            edge.tooltip_lines.length > 0
              ? edge.tooltip_lines
              : [{ text: edge.label, cycle: edge.cycle }],
          ),
          point.x,
          point.y,
        );
      });
      hit.addEventListener("mouseleave", hide_tooltip);
      svg.appendChild(hit);

      var arrow = make_svg_el("polygon");
      arrow.setAttribute("points", arrow_points(edge.route_points));
      arrow.setAttribute(
        "class",
        "graph_arrow arrow_type_" +
          html_escape(edge.type || "direct") +
          (edge.cycle ? " arrow_is_cycle" : ""),
      );
      svg.appendChild(arrow);
    });
  }

  function render_nodes(view, state) {
    var node_layer = by_id("node_layer");
    node_layer.innerHTML = "";
    view.nodes.forEach(function (node) {
      node_layer.appendChild(build_node_card(node, state));
    });
  }

  function save_current_view_state(state) {
    var scroller = by_id("graph_scroller");
    if (!state.current_view_key) {
      return;
    }
    state.view_state[state.current_view_key] = {
      scroll_left: scroller.scrollLeft,
      scroll_top: scroller.scrollTop,
      selected_leaf_id: state.selected_leaf_id,
    };
  }

  function restore_view_state(state) {
    var scroller = by_id("graph_scroller");
    var remembered = state.view_state[state.current_view_key];
    if (!remembered) {
      scroller.scrollLeft = 0;
      scroller.scrollTop = 0;
      return;
    }
    requestAnimationFrame(function () {
      scroller.scrollLeft = remembered.scroll_left || 0;
      scroller.scrollTop = remembered.scroll_top || 0;
    });
  }

  function render_view(view_key, state) {
    var view = state.normalized.views[view_key];
    if (!view) {
      return;
    }
    var selected_in_view = view.nodes.some(function (node) {
      return node.id === state.selected_leaf_id;
    });
    state.current_view_key = view_key;
    if (!selected_in_view) {
      state.selected_leaf_id = state.view_state[view_key]
        ? state.view_state[view_key].selected_leaf_id || null
        : null;
    }
    render_breadcrumb(view, state);
    update_summary(view);

    var notice = by_id("graph_notice");
    var cycle_nodes = view.nodes.filter(function (node) {
      return node.cycle;
    }).length;
    if (cycle_nodes > 0) {
      notice.hidden = false;
      notice.textContent =
        String(cycle_nodes) +
        " node(s) in this view are marked by cycle or cycle-adjacent dependencies.";
    } else {
      notice.hidden = true;
    }

    var layout = derive_layout(view);
    view.nodes.forEach(function (node) {
      node.position = layout.positions[node.id];
    });
    view.display_edges.forEach(function (edge) {
      edge.route_points = make_route_points(edge, layout.positions);
      edge.path = polyline_to_path(edge.route_points);
    });

    var surface = by_id("graph_surface");
    var svg = by_id("graph_svg");
    surface.style.width = String(layout.width) + "px";
    surface.style.height = String(layout.height) + "px";
    svg.setAttribute("viewBox", "0 0 " + layout.width + " " + layout.height);
    svg.setAttribute("width", String(layout.width));
    svg.setAttribute("height", String(layout.height));

    render_layer_labels(layout);
    render_edges(view);
    render_nodes(view, state);

    if (state.selected_leaf_id) {
      var selected = view.nodes.find(function (node) {
        return node.id === state.selected_leaf_id;
      });
      render_inspector(selected || null);
    } else {
      render_inspector(null);
    }

    by_id("back_button").disabled = state.history.length === 0;
    restore_view_state(state);
  }

  function start() {
    var payload = window.ARCH_VIEW_DATA;
    if (!payload) {
      var graph_notice = by_id("graph_notice");
      graph_notice.hidden = false;
      graph_notice.textContent =
        "Missing window.ARCH_VIEW_DATA. Generate architecture_data.js before opening this viewer.";
      by_id("back_button").disabled = true;
      return;
    }

    var normalized = normalize_data(payload);
    var state = {
      normalized: normalized,
      current_view_key: "root",
      history: [],
      selected_leaf_id: null,
      view_state: Object.create(null),
      open_view: function (view_key, push_history) {
        if (!normalized.views[view_key]) {
          return;
        }
        save_current_view_state(state);
        if (
          push_history &&
          state.current_view_key &&
          state.current_view_key !== view_key
        ) {
          state.history.push(state.current_view_key);
        }
        state.selected_leaf_id = null;
        render_view(view_key, state);
      },
    };

    by_id("back_button").addEventListener("click", function () {
      if (state.history.length === 0) {
        return;
      }
      save_current_view_state(state);
      var previous = state.history.pop();
      render_view(previous, state);
    });

    by_id("graph_scroller").addEventListener("scroll", function () {
      save_current_view_state(state);
      hide_tooltip();
    });

    by_id("graph_surface").addEventListener("mouseleave", hide_tooltip);

    render_inspector(null);
    render_view("root", state);
  }

  document.addEventListener("DOMContentLoaded", start);
})();
