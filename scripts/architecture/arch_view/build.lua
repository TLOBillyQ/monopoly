local source_scan = require("arch_view.source_scan")
local dependency_extract = require("arch_view.dependency_extract")
local checker = require("arch_view.checker")
local layers = require("arch_view.layers")
local projection = require("arch_view.projection")

local build = {}

function build.analyze(config)
  local scan_result, scan_err = source_scan.scan(config)
  if scan_result == nil then
    return nil, scan_err
  end

  local extracted = dependency_extract.build(scan_result)
  local classified_modules = checker.classify_modules(extracted.modules, config)
  local graph = {
    nodes = extracted.graph.nodes,
    edges = extracted.graph.edges,
  }
  local layout = layers.assign_layers(graph)

  local architecture = {
    graph = graph,
    modules = classified_modules,
    layout = layout,
  }

  architecture.views = projection.build_views(architecture)
  architecture.check = checker.run(architecture, config)

  return architecture
end

return build
