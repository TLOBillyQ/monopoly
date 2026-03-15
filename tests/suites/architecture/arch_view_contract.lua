local bootstrap = require("tests.bootstrap")

bootstrap.install_package_paths()

local arch_view = require("arch_view")
local common = require("arch_view.common")
local json_reader = require("arch_view.json_reader")
local json_writer = require("arch_view.json_writer")
local projection = require("arch_view.projection")

local cached_architecture = nil
local tmp_root = common.system_tmp_dir() .. "/monopoly_arch_view_test_output"
local arch_view_root = "vendor/arch_view"
local arch_config_path = "scripts/quality/arch/config.json"

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

local function _decode_arch_data_script(path)
  local data_script = _read_file(path)
  local payload = data_script:gsub("^%s*window%.ARCH_VIEW_DATA%s*=%s*", "", 1)
  payload = payload:gsub(";%s*$", "", 1)
  return json_reader.decode(payload), data_script
end

local function _find_node(view, node_id)
  for _, node in ipairs((view and view.nodes) or {}) do
    if node.id == node_id then
      return node
    end
  end
  return nil
end

local function _exists(path)
  return common.path_exists(path) == true
end

local function _analyze_architecture()
  if cached_architecture == nil then
    local architecture, err = arch_view.analyze({
      project_root = ".",
      config_path = arch_config_path,
    })
    if architecture == nil then
      error(err)
    end
    cached_architecture = architecture
  end
  return cached_architecture
end

local function _test_projection_builds_root_and_entry_views()
  local architecture = _analyze_architecture()
  local root_view = architecture.views.root
  local entry_view = architecture.views.entry

  assert(root_view ~= nil, "root view should exist")
  assert(entry_view ~= nil, "entry view should exist")
  _assert_eq(root_view.breadcrumb[1].key, "root", "root breadcrumb should start from root")

  local root_labels = {}
  for _, node in ipairs(root_view.nodes or {}) do
    root_labels[#root_labels + 1] = node.label
  end
  _assert_contains(root_labels, "entry", "root view should expose entry subtree")
  _assert_contains(root_labels, "turn", "root view should expose turn subtree")
  _assert_contains(root_labels, "ui", "root view should expose ui subtree")

  local entry_labels = {}
  for _, node in ipairs(entry_view.nodes or {}) do
    entry_labels[#entry_labels + 1] = node.label
  end
  _assert_contains(entry_labels, "boot", "entry view should expose boot")
  _assert_contains(entry_labels, "start_game", "entry view should expose start_game")
  _assert_contains(entry_labels, "wire_host", "entry view should expose wire_host")
end

local function _test_projection_collapses_package_init_nodes_into_single_drillable_node()
  local architecture = _analyze_architecture()
  local root_view = architecture.views.root
  local rules_view = architecture.views.rules

  for _, view in ipairs({ root_view, rules_view }) do
    for _, node in ipairs(view.nodes or {}) do
      assert(
        tostring(node.id):find("|file", 1, true) == nil,
        "projection should not emit duplicate init leaf nodes: " .. tostring(node.id)
      )
    end
  end

  local entry_node = _find_node(root_view, "entry")
  assert(entry_node ~= nil, "root view should keep a single entry node")
  _assert_eq(entry_node.display_label, "entry", "package nodes with descendants should display namespace label")
  assert(entry_node.drillable == true, "package nodes with descendants should remain drillable")
  assert(entry_node.leaf == false, "package nodes with descendants should not be marked leaf")

  local market_node = _find_node(rules_view, "market")
  assert(market_node ~= nil, "rules view should expose market package node")
  _assert_eq(market_node.module_id, "src.rules.market", "market package node should keep its init module id")
end

local function _test_config_classifies_runtime_game_and_ports()
  local architecture = _analyze_architecture()

  for module_id, module_info in pairs(architecture.modules or {}) do
    assert(module_info.component ~= nil, "every src module should be classified: " .. tostring(module_id))
  end

  _assert_eq(
    architecture.modules["src.state.game_state"].component,
    "state",
    "state.game_state should be classified as state"
  )
  _assert_eq(
    architecture.modules["src.core.ports.runtime_ports"].abstract,
    true,
    "core ports should be marked abstract"
  )
end

local function _test_projection_exposes_full_names_and_display_edges()
  local architecture = _analyze_architecture()
  local utils_view = architecture.views["core.utils"]
  assert(utils_view ~= nil, "core.utils view should exist")

  local number_utils_node = nil
  for _, node in ipairs(utils_view.nodes or {}) do
    if node.module_id == "src.core.utils.number_utils" then
      number_utils_node = node
      break
    end
  end

  assert(number_utils_node ~= nil, "core.utils view should contain number_utils leaf")
  _assert_eq(number_utils_node.display_label, "number_utils", "leaf display label should use source file basename")
  _assert_eq(number_utils_node.full_name, "core.utils.number_utils", "leaf full name should strip top-level src prefix")
  assert(#(architecture.views.root.display_edges or {}) > 0, "root view should expose routed display edges")
end

local function _test_build_includes_metadata_for_project_root_and_config_path()
  local architecture = _analyze_architecture()
  _assert_eq(architecture.schema_version, 1, "build should stamp schema_version")
  assert(architecture.project_root ~= nil and architecture.project_root ~= "", "build should stamp project_root")
  assert(architecture.config_path ~= nil and architecture.config_path ~= "", "build should stamp config_path")
end

local function _test_cli_scan_writes_metadata()
  local out_path = tmp_root .. "/scan/architecture.json"
  local ok, err = common.ensure_parent_dir(out_path)
  if not ok then
    error(err)
  end

  arch_view.run_cli({
    "scan",
    "--out", out_path,
  }, {
    default_config_path = arch_config_path,
    asset_root = arch_view_root .. "/viewer",
    cwd = ".",
  })

  local payload = json_reader.decode(_read_file(out_path))
  _assert_eq(payload.schema_version, 1, "scan command should write schema_version")
  assert(payload.project_root ~= nil and payload.project_root ~= "", "scan command should write project_root")
  assert(payload.config_path ~= nil and payload.config_path ~= "", "scan command should write config_path")
end

local function _test_cli_viewer_supports_in_json()
  local out_dir = tmp_root .. "/viewer_from_json"
  local json_path = tmp_root .. "/viewer_from_json_input/architecture.json"
  local ok, err = common.ensure_parent_dir(json_path)
  if not ok then
    error(err)
  end
  local architecture = _analyze_architecture()
  local write_ok, write_err = common.write_file(json_path, json_writer.encode(architecture))
  if not write_ok then
    error(write_err)
  end

  arch_view.run_cli({
    "viewer",
    "--in-json", json_path,
    "--out-dir", out_dir,
  }, {
    default_config_path = arch_config_path,
    asset_root = arch_view_root .. "/viewer",
    cwd = ".",
  })

  assert(_exists(out_dir .. "/index.html"), "viewer --in-json should export index.html")
  assert(_exists(out_dir .. "/architecture.json"), "viewer --in-json should export architecture.json")
end

local function _test_json_modules_are_self_contained()
  local common_source = _read_file("vendor/arch_view/arch_view/common.lua")
  local script_common_source = _read_file("vendor/arch_view/arch_view/script_common.lua")
  assert(common_source:find('require("shared.lib.common")', 1, true) == nil, "arch_view common should not depend on monopoly lib.common")
  assert(script_common_source:find('src.core.utils.number_utils', 1, true) == nil,
    "arch_view script_common should not depend on monopoly src modules")
end

local function _test_real_repo_projection_cycles_exclude_new_subtrees()
  local architecture = _analyze_architecture()
  architecture.views = architecture.views or projection.build_views(architecture)

  local projection_cycles = projection.collect_projection_cycles(architecture.views)
  local blocked_views = {
    turn = true,
    rules = true,
    ui = true,
  }

  for _, entry in ipairs(projection_cycles or {}) do
    assert(
      blocked_views[entry.view] ~= true,
      "projection_cycles should not include " .. tostring(entry.view)
    )
  end
end

local function _test_snapshot_files_exist_in_repo()
  assert(_exists("scripts/quality/arch/viewer/index.html"), "snapshot viewer index should exist")
  assert(_exists("scripts/quality/arch/viewer/script.js"), "snapshot viewer script should exist")
  assert(_exists("scripts/quality/arch/viewer/styles.css"), "snapshot viewer styles should exist")
  assert(_exists("scripts/quality/arch/viewer/architecture.json"), "snapshot architecture json should exist")
  assert(_exists("scripts/quality/arch/viewer/architecture_data.js"), "snapshot architecture data should exist")
end

local contract_tests = {
  { name = "projection_builds_root_and_entry_views", run = _test_projection_builds_root_and_entry_views },
  { name = "projection_collapses_package_init_nodes_into_single_drillable_node", run = _test_projection_collapses_package_init_nodes_into_single_drillable_node },
  { name = "config_classifies_runtime_game_and_ports", run = _test_config_classifies_runtime_game_and_ports },
  { name = "projection_exposes_full_names_and_display_edges", run = _test_projection_exposes_full_names_and_display_edges },
  { name = "build_includes_metadata_for_project_root_and_config_path", run = _test_build_includes_metadata_for_project_root_and_config_path },
  { name = "json_modules_are_self_contained", run = _test_json_modules_are_self_contained },
  { name = "real_repo_projection_cycles_exclude_new_subtrees", run = _test_real_repo_projection_cycles_exclude_new_subtrees },
  { name = "snapshot_files_exist_in_repo", run = _test_snapshot_files_exist_in_repo },
}

local tooling_tests = {
  { name = "cli_scan_writes_metadata", run = _test_cli_scan_writes_metadata },
  { name = "cli_viewer_supports_in_json", run = _test_cli_viewer_supports_in_json },
}

return {
  name = "architecture.arch_view_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
}
