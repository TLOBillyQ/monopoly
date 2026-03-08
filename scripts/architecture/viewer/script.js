(function () {
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

  function normalize_edge(edge, fallback_id) {
    if (!edge) {
      return null;
    }
    if (typeof edge === "string") {
      return { id: fallback_id || edge, from: edge, to: edge };
    }
    var from = edge.from || edge.source || edge.start;
    var to = edge.to || edge.target || edge.finish;
    if (!from || !to) {
      return null;
    }
    return {
      id: edge.id || fallback_id || from + "->" + to,
      from: from,
      to: to,
      cycle: edge.cycle === true || edge.is_cycle === true || edge.feedback === true || edge.cycle_break === true,
      label: edge.label || edge.type || ""
    };
  }

  function feedback_lookup(data) {
    var lookup = Object.create(null);
    var layout = data.layout || {};
    to_array(layout.feedback_edges).forEach(function (edge, index) {
      var normalized = normalize_edge(edge, "feedback_" + index);
      if (normalized) {
        lookup[normalized.from + "->" + normalized.to] = true;
      }
    });
    return lookup;
  }

  function cycle_lookup(data) {
    var lookup = Object.create(null);
    var check = data.check || {};
    var cycles = to_array(check.cycles);
    cycles.forEach(function (cycle) {
      if (Array.isArray(cycle)) {
        cycle.forEach(function (id) {
          lookup[id] = true;
        });
        return;
      }
      if (cycle && Array.isArray(cycle.modules)) {
        cycle.modules.forEach(function (id) {
          lookup[id] = true;
        });
      }
    });
    return lookup;
  }

  function normalize_module(module_id, raw_module, cycle_by_id) {
    var source_text = raw_module && (raw_module.source_text || raw_module.source || raw_module.contents || "");
    return {
      id: module_id,
      name: (raw_module && (raw_module.name || raw_module.label)) || module_id,
      component: raw_module && raw_module.component ? raw_module.component : null,
      abstract: raw_module && (raw_module.abstract === true || raw_module.kind === "abstract"),
      source_path: raw_module && raw_module.source_path ? raw_module.source_path : "",
      source_text: typeof source_text === "string" ? source_text : JSON.stringify(source_text, null, 2),
      internal_requires: unique_sorted(
        (raw_module && (raw_module.internal_requires || raw_module.internal_dependencies || raw_module.requires)) || []
      ),
      external_requires: unique_sorted(
        (raw_module && (raw_module.external_requires || raw_module.external_dependencies)) || []
      ),
      cycle: cycle_by_id[module_id] === true || (raw_module && raw_module.cycle === true)
    };
  }

  function normalize_modules(data) {
    var cycle_by_id = cycle_lookup(data);
    var modules = Object.create(null);
    Object.keys(data.modules || {}).forEach(function (module_id) {
      modules[module_id] = normalize_module(module_id, data.modules[module_id], cycle_by_id);
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
      crumbs = [{ key: "root", label: "root" }];
      if (view_key && view_key !== "root") {
        crumbs.push({ key: view_key, label: view_key });
      }
    }
    return crumbs.map(function (crumb, index) {
      if (typeof crumb === "string") {
        return {
          key: index === 0 && crumb === "" ? "root" : crumb,
          label: crumb === "" ? "root" : crumb
        };
      }
      return {
        key: view_key_for_breadcrumb(crumb, index) || (index === 0 ? "root" : view_key),
        label: crumb.label || crumb.name || crumb.title || crumb.key || crumb.id || (index === 0 ? "root" : view_key)
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

  function normalize_node(raw_node, index, modules, layer_map, feedback_by_edge, cycle_by_id) {
    var node = raw_node || {};
    var id = node.id || node.key || node.module_id || node.module || node.name || ("node_" + index);
    var module_ref = node.module_id || node.module || (modules[id] ? id : null);
    var module_info = module_ref ? modules[module_ref] : null;
    var is_leaf = node.leaf === true || node.is_leaf === true || (!!module_info && node.branch !== true && node.group !== true);
    var layer = node.layer;
    if (layer === undefined || layer === null) {
      layer = layer_map[id];
      if ((layer === undefined || layer === null) && module_ref) {
        layer = layer_map[module_ref];
      }
    }
    var abstract_flag = node.abstract === true || node.is_abstract === true || (module_info && module_info.abstract === true);
    var cycle_flag = node.cycle === true || node.is_cycle === true || cycle_by_id[id] === true || (module_ref && cycle_by_id[module_ref] === true);
    return {
      id: id,
      label: node.label || node.name || node.title || id,
      description: node.description || node.summary || "",
      view_key: node.view_key || node.child_view_key || node.next_view || id,
      module_id: module_ref,
      leaf: is_leaf,
      abstract: abstract_flag,
      cycle: cycle_flag,
      component: node.component || (module_info && module_info.component) || null,
      source_path: node.source_path || (module_info && module_info.source_path) || "",
      source_text: node.source_text || (module_info && module_info.source_text) || "",
      internal_requires: unique_sorted(
        node.internal_requires || node.internal_dependencies || (module_info && module_info.internal_requires) || []
      ),
      external_requires: unique_sorted(
        node.external_requires || node.external_dependencies || (module_info && module_info.external_requires) || []
      ),
      layer: typeof layer === "number" ? layer : 0,
      edge_cycle_lookup: feedback_by_edge
    };
  }

  function normalize_view(view_key, raw_view, modules, layer_map, feedback_by_edge, cycle_by_id) {
    var nodes = to_array(raw_view && raw_view.nodes).map(function (node, index) {
      return normalize_node(node, index, modules, layer_map, feedback_by_edge, cycle_by_id);
    });
    var node_ids = Object.create(null);
    nodes.forEach(function (node) {
      node_ids[node.id] = true;
    });

    var edges = to_array(raw_view && raw_view.edges)
      .map(function (edge, index) {
        var normalized = normalize_edge(edge, view_key + "_edge_" + index);
        if (!normalized) {
          return null;
        }
        normalized.cycle = normalized.cycle === true || feedback_by_edge[normalized.from + "->" + normalized.to] === true;
        return normalized;
      })
      .filter(function (edge) {
        return !!edge && node_ids[edge.from] === true && node_ids[edge.to] === true;
      });

    nodes.forEach(function (node) {
      node.outgoing = edges.filter(function (edge) {
        return edge.from === node.id;
      });
      node.incoming = edges.filter(function (edge) {
        return edge.to === node.id;
      });
      if (!node.cycle) {
        node.cycle = node.outgoing.some(function (edge) {
          return edge.cycle;
        }) || node.incoming.some(function (edge) {
          return edge.cycle;
        });
      }
    });

    nodes.sort(function (left, right) {
      if (left.layer !== right.layer) {
        return left.layer - right.layer;
      }
      return left.label.localeCompare(right.label);
    });

    return {
      key: view_key,
      title: (raw_view && raw_view.title) || view_key,
      breadcrumb: normalize_breadcrumb(view_key, raw_view && raw_view.breadcrumb),
      nodes: nodes,
      edges: edges
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
        cycle_by_id
      );
    });

    if (!normalized_views.root) {
      var root_modules = Object.keys(modules).map(function (module_id) {
        return {
          id: module_id,
          label: modules[module_id].name,
          module_id: module_id,
          leaf: true,
          abstract: modules[module_id].abstract,
          cycle: modules[module_id].cycle,
          component: modules[module_id].component,
          source_path: modules[module_id].source_path,
          source_text: modules[module_id].source_text,
          internal_requires: modules[module_id].internal_requires,
          external_requires: modules[module_id].external_requires,
          layer: layer_map[module_id] || 0
        };
      });
      normalized_views.root = normalize_view(
        "root",
        {
          title: "root",
          breadcrumb: [{ key: "root", label: "root" }],
          nodes: root_modules,
          edges: to_array((data.graph && data.graph.edges) || [])
        },
        modules,
        layer_map,
        feedback_by_edge,
        cycle_by_id
      );
    }

    return {
      raw: data,
      modules: modules,
      views: normalized_views
    };
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
    target.innerHTML = items.map(function (item) {
      return "<li>" + html_escape(item) + "</li>";
    }).join("");
  }

  function render_metadata(target, rows) {
    if (!rows || rows.length === 0) {
      target.innerHTML = "<dt>Status</dt><dd>Unavailable</dd>";
      return;
    }
    target.innerHTML = rows.map(function (row) {
      return "<dt>" + html_escape(row.label) + "</dt><dd>" + html_escape(row.value) + "</dd>";
    }).join("");
  }

  function render_inspector(node) {
    var title = document.getElementById("detail_title");
    var subtitle = document.getElementById("detail_subtitle");
    var metadata = document.getElementById("metadata_list");
    var internal_list = document.getElementById("internal_dependency_list");
    var external_list = document.getElementById("external_dependency_list");
    var source_code = document.getElementById("source_code");
    var source_path = document.getElementById("source_path_label");

    if (!node) {
      title.textContent = "Select a leaf module";
      subtitle.textContent = "Click a non-leaf node to drill down. Click a leaf node to inspect source and dependencies.";
      render_metadata(metadata, []);
      create_empty_message(internal_list, "No module selected.");
      create_empty_message(external_list, "No module selected.");
      source_path.textContent = "";
      source_code.textContent = "No module selected.";
      source_code.classList.add("empty_state");
      return;
    }

    title.textContent = node.label;
    subtitle.textContent = node.cycle
      ? "This module participates in, or is adjacent to, a known dependency cycle."
      : "Leaf module details from the exported architecture payload.";

    render_metadata(metadata, [
      { label: "Module", value: node.module_id || node.id },
      { label: "Component", value: node.component || "unclassified" },
      { label: "Layer", value: String(node.layer) },
      { label: "Abstract", value: node.abstract ? "yes" : "no" },
      { label: "Cycle", value: node.cycle ? "yes" : "no" }
    ]);

    render_token_list(internal_list, node.internal_requires, "No internal dependencies.");
    render_token_list(external_list, node.external_requires, "No external dependencies.");
    source_path.textContent = node.source_path || "";
    source_code.textContent = node.source_text || "Source text missing from payload.";
    source_code.classList.toggle("empty_state", !node.source_text);
  }

  function grouped_nodes(view) {
    var buckets = Object.create(null);
    view.nodes.forEach(function (node) {
      var key = String(node.layer || 0);
      if (!buckets[key]) {
        buckets[key] = [];
      }
      buckets[key].push(node);
    });
    return Object.keys(buckets)
      .map(function (key) {
        return {
          layer: Number(key),
          nodes: buckets[key]
        };
      })
      .sort(function (left, right) {
        return left.layer - right.layer;
      });
  }

  function render_edges(node) {
    var outgoing = node.outgoing || [];
    if (outgoing.length === 0) {
      return "";
    }
    return (
      '<div class="edge_list">' +
      outgoing.map(function (edge) {
        return (
          '<div class="edge_row' + (edge.cycle ? " edge_is_cycle" : "") + '">' +
          '<span class="edge_name">' + html_escape(edge.from) + "</span>" +
          "<span>&rarr;</span>" +
          '<span class="edge_name">' + html_escape(edge.to) + "</span>" +
          "</div>"
        );
      }).join("") +
      "</div>"
    );
  }

  function render_breadcrumb(view, state) {
    var root = document.getElementById("breadcrumb");
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

  function update_summary(view) {
    document.getElementById("current_view_label").textContent = view.title || view.key;
    document.getElementById("node_count_label").textContent = String(view.nodes.length);
    document.getElementById("edge_count_label").textContent = String(view.edges.length);
    document.getElementById("cycle_count_label").textContent = String(
      view.nodes.filter(function (node) {
        return node.cycle;
      }).length
    );
  }

  function render_view(view, state) {
    var canvas = document.getElementById("graph_canvas");
    var notice = document.getElementById("graph_notice");
    var back_button = document.getElementById("back_button");
    render_breadcrumb(view, state);
    update_summary(view);

    var cycle_nodes = view.nodes.filter(function (node) {
      return node.cycle;
    }).length;
    if (cycle_nodes > 0) {
      notice.hidden = false;
      notice.textContent = cycle_nodes + " node(s) in this view are marked by cycle or cycle-adjacent dependencies.";
    } else {
      notice.hidden = true;
    }

    back_button.disabled = state.history.length === 0;
    canvas.innerHTML = "";

    grouped_nodes(view).forEach(function (bucket) {
      var section = document.createElement("section");
      section.className = "layer_section";

      var header = document.createElement("div");
      header.className = "layer_header";
      header.innerHTML =
        "<h3>Layer " + html_escape(bucket.layer) + "</h3>" +
        '<span class="layer_meta">' + bucket.nodes.length + " node(s)</span>";
      section.appendChild(header);

      var grid = document.createElement("div");
      grid.className = "layer_nodes";
      bucket.nodes.forEach(function (node) {
        var button = document.createElement("button");
        var class_name = "node_card";
        class_name += node.leaf ? " node_is_leaf" : " node_is_branch";
        if (node.abstract) {
          class_name += " node_is_abstract";
        }
        if (node.cycle) {
          class_name += " node_is_cycle";
        }
        if (state.selected_leaf_id === node.id) {
          class_name += " node_is_selected";
        }
        button.type = "button";
        button.className = class_name;
        button.innerHTML =
          '<div class="node_kicker">' +
          '<span class="node_tag">' + html_escape(node.leaf ? "leaf" : "group") + "</span>" +
          (node.component ? '<span class="node_tag">' + html_escape(node.component) + "</span>" : "") +
          (node.abstract ? '<span class="node_tag node_tag_abstract">abstract</span>' : "") +
          (node.cycle ? '<span class="node_tag node_tag_cycle">cycle</span>' : "") +
          "</div>" +
          "<h4>" + html_escape(node.label) + "</h4>" +
          "<p>" + html_escape(node.description || (node.leaf ? "Inspect source and dependencies." : "Drill into nested namespace view.")) + "</p>" +
          render_edges(node);
        button.addEventListener("click", function () {
          if (node.leaf) {
            state.selected_leaf_id = node.id;
            render_inspector(node);
            render_view(view, state);
            return;
          }
          state.open_view(node.view_key, true);
        });
        grid.appendChild(button);
      });
      section.appendChild(grid);
      canvas.appendChild(section);
    });
  }

  function start() {
    var payload = window.ARCH_VIEW_DATA;
    if (!payload) {
      var graph_notice = document.getElementById("graph_notice");
      graph_notice.hidden = false;
      graph_notice.textContent = "Missing window.ARCH_VIEW_DATA. Generate architecture_data.js before opening this viewer.";
      document.getElementById("back_button").disabled = true;
      return;
    }

    var normalized = normalize_data(payload);
    var state = {
      normalized: normalized,
      current_view_key: "root",
      history: [],
      selected_leaf_id: null,
      open_view: function (view_key, push_history) {
        var next_view = normalized.views[view_key];
        if (!next_view) {
          return;
        }
        if (push_history && state.current_view_key && state.current_view_key !== view_key) {
          state.history.push(state.current_view_key);
        }
        if (!push_history) {
          var idx = state.history.indexOf(view_key);
          if (idx >= 0) {
            state.history = state.history.slice(0, idx);
          }
        }
        state.current_view_key = view_key;
        state.selected_leaf_id = null;
        render_inspector(null);
        render_view(next_view, state);
      }
    };

    document.getElementById("back_button").addEventListener("click", function () {
      if (state.history.length === 0) {
        return;
      }
      var previous = state.history.pop();
      state.current_view_key = previous;
      state.selected_leaf_id = null;
      render_inspector(null);
      render_view(normalized.views[previous], state);
    });

    render_inspector(null);
    render_view(normalized.views.root, state);
  }

  document.addEventListener("DOMContentLoaded", start);
})();
