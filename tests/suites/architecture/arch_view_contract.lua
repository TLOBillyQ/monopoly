local bootstrap = require("tests.bootstrap")

bootstrap.install_package_paths()

local arch_view = require("arch_view")
local common = require("arch_view.runtime.common")
local json_reader = require("arch_view.runtime.json_reader")

local cached_snapshot = nil
local cached_scan_result = nil
local tmp_root = common.make_temp_path("arch_view_test_output", "")
local arch_view_root = "vendor/arch_view"

local function _first_existing(paths)
  for _, path in ipairs(paths or {}) do
    if common.path_exists(path) == true then
      return path
    end
  end
  return paths and paths[1] or nil
end

local arch_config_path = _first_existing({
  "tools/quality/arch/config.json",
})
local snapshot_json_path = _first_existing({
  "tools/quality/arch/viewer/architecture.json",
})

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

local function _contains(list, expected)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return true
    end
  end
  return false
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

local function _snapshot_architecture()
  if cached_snapshot == nil then
    cached_snapshot = json_reader.decode(_read_file(snapshot_json_path))
  end
  return cached_snapshot
end

local function _scan_architecture_json()
  if cached_scan_result == nil then
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

    cached_scan_result = {
      out_path = out_path,
      payload = json_reader.decode(_read_file(out_path)),
    }
  end
  return cached_scan_result
end

local function _test_projection_builds_root_and_app_views()
  local architecture = _snapshot_architecture()
  local root_view = architecture.views.root
  local app_view = architecture.views.app
  local app_bootstrap_view = architecture.views["app.bootstrap"]

  assert(root_view ~= nil, "root view should exist")
  assert(app_view ~= nil, "app view should exist")
  assert(app_bootstrap_view ~= nil, "app.bootstrap view should exist")
  _assert_eq(root_view.breadcrumb[1].key, "root", "root breadcrumb should start from root")

  local root_labels = {}
  for _, node in ipairs(root_view.nodes or {}) do
    root_labels[#root_labels + 1] = node.label
  end
  _assert_contains(root_labels, "app", "root view should expose app subtree")
  _assert_contains(root_labels, "infrastructure", "root view should expose infrastructure subtree")
  _assert_contains(root_labels, "presentation", "root view should expose presentation subtree")
  assert(_contains(root_labels, "flow") or _contains(root_labels, "turn"),
    "root view should expose flow/turn subtree")

  local app_labels = {}
  for _, node in ipairs(app_view.nodes or {}) do
    app_labels[#app_labels + 1] = node.label
  end
  _assert_contains(app_labels, "bootstrap", "app view should expose bootstrap")

  local app_bootstrap_labels = {}
  for _, node in ipairs(app_bootstrap_view.nodes or {}) do
    app_bootstrap_labels[#app_bootstrap_labels + 1] = node.label
  end
  _assert_contains(app_bootstrap_labels, "runtime_install", "app.bootstrap view should expose runtime_install")
  _assert_contains(app_bootstrap_labels, "startup_roster", "app.bootstrap view should expose startup_roster")
end

local function _test_projection_collapses_package_init_nodes_into_single_drillable_node()
  local architecture = _snapshot_architecture()
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

  local app_node = _find_node(root_view, "app")
  assert(app_node ~= nil, "root view should keep a single app node")
  _assert_eq(app_node.display_label, "app", "package nodes with descendants should display namespace label")
  assert(app_node.drillable == true, "package nodes with descendants should remain drillable")
  assert(app_node.leaf == false, "package nodes with descendants should not be marked leaf")

  local market_node = _find_node(rules_view, "market")
  assert(market_node ~= nil, "rules view should expose market package node")
  _assert_eq(market_node.module_id, "src.rules.market", "market package node should keep its init module id")
end

local function _test_config_classifies_runtime_game_and_ports()
  local architecture = _snapshot_architecture()

  for module_id, module_info in pairs(architecture.modules or {}) do
    assert(module_info.component ~= nil, "every src module should be classified: " .. tostring(module_id))
  end

  _assert_eq(
    architecture.modules["src.state.game_state"].component,
    "runtime",
    "state.game_state should be classified as runtime"
  )
  _assert_eq(
    architecture.modules["src.app.bootstrap"].component,
    "app",
    "app.bootstrap package should be classified as app"
  )
  _assert_eq(
    architecture.modules["src.core.ports.runtime_ports"].abstract,
    true,
    "core ports should be marked abstract"
  )
end

local function _test_projection_exposes_full_names_and_display_edges()
  local architecture = _snapshot_architecture()
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
  local architecture = _snapshot_architecture()
  _assert_eq(architecture.schema_version, 1, "build should stamp schema_version")
  assert(architecture.project_root ~= nil and architecture.project_root ~= "", "build should stamp project_root")
  assert(architecture.config_path ~= nil and architecture.config_path ~= "", "build should stamp config_path")
end

local function _test_cli_scan_writes_metadata()
  local payload = _scan_architecture_json().payload
  _assert_eq(payload.schema_version, 1, "scan command should write schema_version")
  assert(payload.project_root ~= nil and payload.project_root ~= "", "scan command should write project_root")
  assert(payload.config_path ~= nil and payload.config_path ~= "", "scan command should write config_path")
end

local function _test_cli_viewer_supports_in_json()
  local out_dir = tmp_root .. "/viewer_from_json"
  local scan = _scan_architecture_json()

  arch_view.run_cli({
    "viewer",
    "--in-json", scan.out_path,
    "--out-dir", out_dir,
  }, {
    default_config_path = arch_config_path,
    asset_root = arch_view_root .. "/viewer",
    cwd = ".",
  })

  assert(_exists(out_dir .. "/index.html"), "viewer --in-json should export index.html")
  assert(_exists(out_dir .. "/architecture.json"), "viewer --in-json should export architecture.json")
end

local function _test_raw_scan_has_no_presentation_namespace_projection_cycles()
  local scan = _scan_architecture_json()
  local payload = json_reader.decode(_read_file(scan.out_path))
  for _, violation in ipairs((payload.check and payload.check.violations) or {}) do
    assert(violation.view ~= "ui", "raw scan should not report presentation namespace ui projection cycle")
    assert(violation.view ~= "ui.ctl", "raw scan should not report presentation namespace ui.ctl projection cycle")
  end
end

local function _test_json_modules_are_self_contained()
  local common_source = _read_file("vendor/arch_view/arch_view/runtime/common.lua")
  local host_source = _read_file("vendor/arch_view/arch_view/runtime/host.lua")
  assert(common_source:find('require("shared.lib.common")', 1, true) == nil, "arch_view common should not depend on monopoly lib.common")
  assert(host_source:find('src.core.utils.number_utils', 1, true) == nil,
    "arch_view host runtime should not depend on monopoly src modules")
end

local function _test_snapshot_files_exist_in_repo()
  local snapshot_root = _first_existing({
    "tools/quality/arch/viewer",
  })
  assert(_exists(snapshot_root .. "/index.html"), "snapshot viewer index should exist")
  assert(_exists(snapshot_root .. "/script.js"), "snapshot viewer script should exist")
  assert(_exists(snapshot_root .. "/styles.css"), "snapshot viewer styles should exist")
  assert(_exists(snapshot_root .. "/architecture.json"), "snapshot architecture json should exist")
  assert(_exists(snapshot_root .. "/architecture_data.js"), "snapshot architecture data should exist")
end

local contract_tests = {
  { name = "projection_builds_root_and_app_views", run = _test_projection_builds_root_and_app_views },
  { name = "projection_collapses_package_init_nodes_into_single_drillable_node", run = _test_projection_collapses_package_init_nodes_into_single_drillable_node },
  { name = "config_classifies_runtime_game_and_ports", run = _test_config_classifies_runtime_game_and_ports },
  { name = "projection_exposes_full_names_and_display_edges", run = _test_projection_exposes_full_names_and_display_edges },
  { name = "build_includes_metadata_for_project_root_and_config_path", run = _test_build_includes_metadata_for_project_root_and_config_path },
  { name = "json_modules_are_self_contained", run = _test_json_modules_are_self_contained },
  { name = "snapshot_files_exist_in_repo", run = _test_snapshot_files_exist_in_repo },
}

local tooling_tests = {
  { name = "cli_scan_writes_metadata", run = _test_cli_scan_writes_metadata },
  { name = "cli_viewer_supports_in_json", run = _test_cli_viewer_supports_in_json },
  { name = "raw_scan_has_no_presentation_namespace_projection_cycles", run = _test_raw_scan_has_no_presentation_namespace_projection_cycles },
}

return {
  name = "architecture.arch_view_contract",
  tests = contract_tests,
  tooling_tests = tooling_tests,
}
