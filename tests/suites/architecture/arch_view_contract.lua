package.path = package.path .. ";./scripts/architecture/?.lua;./scripts/architecture/?/?.lua"

local build = require("arch_view.build")
local checker = require("arch_view.checker")
local common = require("arch_view.common")
local dependency_extract = require("arch_view.dependency_extract")
local layout = require("arch_view.layers")
local config = require("monopoly_architecture")

local cached_architecture = nil

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _assert_contains(list, expected, message)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return
    end
  end
  error((message or "value missing") .. "\nmissing: " .. tostring(expected))
end

local function _read_file(path)
  local content, err = common.read_file(path)
  if content == nil then
    error(err)
  end
  return content
end

local function _exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function _analyze_architecture()
  if cached_architecture == nil then
    local architecture, err = build.analyze(config)
    if architecture == nil then
      error(err)
    end
    cached_architecture = architecture
  end
  return cached_architecture
end

local function _test_dependency_extract_supports_static_requires()
  local scan_result = {
    module_ids = {
      ["src.demo.a"] = true,
      ["src.demo.b"] = true,
      ["src.demo.c"] = true,
      ["src.demo.d"] = true,
    },
    module_list = {
      "src.demo.a",
      "src.demo.b",
      "src.demo.c",
      "src.demo.d",
    },
    modules = {
      ["src.demo.a"] = {
        module_id = "src.demo.a",
        module_segments = { "src", "demo", "a" },
        namespace_segments = { "demo", "a" },
        source_path = "src/demo/a.lua",
        source_text = table.concat({
          'local b = require("src.demo.b")',
          "local c = require('src.demo.c')",
          'require "src.demo.d"',
          "require 'external.pkg'",
          "local ignored = require(module_name)",
        }, "\n"),
        root = "src",
      },
      ["src.demo.b"] = {
        module_id = "src.demo.b",
        module_segments = { "src", "demo", "b" },
        namespace_segments = { "demo", "b" },
        source_path = "src/demo/b.lua",
        source_text = "",
        root = "src",
      },
      ["src.demo.c"] = {
        module_id = "src.demo.c",
        module_segments = { "src", "demo", "c" },
        namespace_segments = { "demo", "c" },
        source_path = "src/demo/c.lua",
        source_text = "",
        root = "src",
      },
      ["src.demo.d"] = {
        module_id = "src.demo.d",
        module_segments = { "src", "demo", "d" },
        namespace_segments = { "demo", "d" },
        source_path = "src/demo/d.lua",
        source_text = "",
        root = "src",
      },
    },
  }

  local extracted = dependency_extract.build(scan_result)
  local module_info = extracted.modules["src.demo.a"]

  _assert_eq(#module_info.internal_requires, 3, "static requires should capture three internal modules")
  _assert_contains(module_info.internal_requires, "src.demo.b", "require(...) should be captured")
  _assert_contains(module_info.internal_requires, "src.demo.c", "require('...') should be captured")
  _assert_contains(module_info.internal_requires, "src.demo.d", "require '...' should be captured")
  _assert_eq(#module_info.external_requires, 1, "external literal require should be captured once")
  _assert_eq(module_info.external_requires[1], "external.pkg", "dynamic require(module_name) should be ignored")
end

local function _test_layers_assign_feedback_edges_for_cycles()
  local layered = layout.assign_layers({
    nodes = { "a", "b", "c" },
    edges = {
      { from = "a", to = "b" },
      { from = "b", to = "a" },
      { from = "b", to = "c" },
    },
  })

  assert(#layered.feedback_edges > 0, "cycle graph should produce feedback_edges")
  assert(layered.module_to_layer.a ~= nil, "layer assignment should include node a")
  assert(layered.module_to_layer.b ~= nil, "layer assignment should include node b")
  assert(layered.module_to_layer.c ~= nil, "layer assignment should include node c")
end

local function _test_projection_builds_root_and_game_views()
  local architecture = _analyze_architecture()
  local root_view = architecture.views.root
  local game_view = architecture.views.game

  assert(root_view ~= nil, "root view should exist")
  assert(game_view ~= nil, "game view should exist")
  _assert_eq(root_view.breadcrumb[1].key, "root", "root breadcrumb should start from root")

  local root_labels = {}
  for _, node in ipairs(root_view.nodes or {}) do
    root_labels[#root_labels + 1] = node.label
  end
  _assert_contains(root_labels, "game", "root view should expose game subtree")
  _assert_contains(root_labels, "presentation", "root view should expose presentation subtree")

  local game_labels = {}
  for _, node in ipairs(game_view.nodes or {}) do
    game_labels[#game_labels + 1] = node.label
  end
  _assert_contains(game_labels, "flow", "game view should drill down into flow")
  _assert_contains(game_labels, "systems", "game view should drill down into systems")
end

local function _test_config_classifies_runtime_game_and_ports()
  local architecture = _analyze_architecture()

  for module_id, module_info in pairs(architecture.modules or {}) do
    assert(module_info.component ~= nil, "every src module should be classified: " .. tostring(module_id))
  end

  _assert_eq(
    architecture.modules["src.game.core.runtime.game"].component,
    "state",
    "runtime.game should be classified as state"
  )
  _assert_eq(
    architecture.modules["src.core.ports.runtime_ports"].abstract,
    true,
    "core ports should be marked abstract"
  )
end

local function _test_cycle_baseline_rejects_unexpected_cycles()
  local architecture = {
    graph = {
      nodes = { "a", "b", "c" },
      edges = {
        { from = "a", to = "b" },
        { from = "b", to = "c" },
        { from = "c", to = "a" },
      },
    },
    modules = {
      a = { component = "demo" },
      b = { component = "demo" },
      c = { component = "demo" },
    },
  }
  local result = checker.run(architecture, {
    component_rules = {},
    abstract_rules = {},
    forbidden_dependency_rules = {},
    cycle_baseline = {
      { "a", "b" },
    },
  })

  assert(result.ok == false, "unexpected cycle should fail check")
  _assert_eq(result.violations[1].kind, "unexpected_cycle", "unexpected cycle should be reported first")
  assert(#result.cycles == 1 and #result.cycles[1] == 3, "cycle output should expose module arrays")
end

local function _test_viewer_command_writes_static_bundle()
  local out_dir = ".tmp_arch_view_test_output/viewer"
  local ok, err = common.ensure_dir(out_dir)
  if not ok then
    error(err)
  end

  local command = 'lua scripts/architecture/arch_view_cli.lua viewer --out-dir "' .. out_dir .. '"'
  if common.is_windows() then
    command = command .. " >nul 2>nul"
  else
    command = command .. " >/dev/null 2>&1"
  end
  local status = os.execute(command)
  assert(status == true or status == 0, "viewer command should succeed")
  assert(_exists(out_dir .. "/index.html"), "viewer should export index.html")
  assert(_exists(out_dir .. "/script.js"), "viewer should export script.js")
  assert(_exists(out_dir .. "/styles.css"), "viewer should export styles.css")
  local data_script = _read_file(out_dir .. "/architecture_data.js")
  assert(data_script:find("window%.ARCH_VIEW_DATA%s*=", 1) ~= nil, "viewer bundle should expose global payload")
end

return {
  name = "architecture.arch_view_contract",
  tests = {
    { name = "dependency_extract_supports_static_requires", run = _test_dependency_extract_supports_static_requires },
    { name = "layers_assign_feedback_edges_for_cycles", run = _test_layers_assign_feedback_edges_for_cycles },
    { name = "projection_builds_root_and_game_views", run = _test_projection_builds_root_and_game_views },
    { name = "config_classifies_runtime_game_and_ports", run = _test_config_classifies_runtime_game_and_ports },
    { name = "cycle_baseline_rejects_unexpected_cycles", run = _test_cycle_baseline_rejects_unexpected_cycles },
    { name = "viewer_command_writes_static_bundle", run = _test_viewer_command_writes_static_bundle },
  },
}
