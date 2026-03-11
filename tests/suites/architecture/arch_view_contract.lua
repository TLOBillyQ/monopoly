package.path = package.path .. ";./scripts/arch/?.lua;./scripts/arch/?/?.lua"

local build = require("arch_view.build")
local cli = require("arch_view.cli")
local checker = require("arch_view.checker")
local common = require("arch_view.common")
local dependency_extract = require("arch_view.dependency_extract")
local json_reader = require("arch_view.json_reader")
local json_writer = require("arch_view.json_writer")
local layout = require("arch_view.layers")
local route_engine = require("arch_view.route_engine")
local source_scan = require("arch_view.source_scan")
local config = require("config")

local cached_architecture = nil
local tmp_root = common.system_tmp_dir() .. "/monopoly_arch_view_test_output"

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

local function _test_source_scan_treats_init_as_package_entry()
    local root = tmp_root .. "/source_scan/pkg_root"
    local package_dir = root .. "/demo/pkg"
    local ok, err = common.ensure_dir(package_dir)
    if not ok then
        error(err)
    end

    local init_file = assert(io.open(package_dir .. "/init.lua", "w"))
    init_file:write("return {}\n")
    init_file:close()

    local child_file = assert(io.open(package_dir .. "/child.lua", "w"))
    child_file:write("return {}\n")
    child_file:close()

    local scan_result, scan_err = source_scan.scan({
        source_roots = { root },
    })
    if scan_result == nil then
        error(scan_err)
    end

    local root_module = common.normalize_path(root):gsub("/", ".") .. ".demo.pkg"
    local child_module = root_module .. ".child"
    assert(scan_result.module_ids[root_module] == true, "init.lua should resolve to package module id")
    assert(scan_result.module_ids[child_module] == true, "package child should keep nested module id")
    assert(scan_result.module_ids[root_module .. ".init"] ~= true, "init.lua should not emit foo.init module id")
end

local function _test_source_scan_resolves_relative_root_against_project_root()
    local project_root = tmp_root .. "/sample_project"
    local package_dir = project_root .. "/src/demo/pkg"
    local ok, err = common.ensure_dir(package_dir)
    if not ok then
        error(err)
    end

    local init_file = assert(io.open(package_dir .. "/init.lua", "w"))
    init_file:write('local util = require("src.demo.util")\nreturn util\n')
    init_file:close()

    local util_dir = project_root .. "/src/demo"
    ok, err = common.ensure_dir(util_dir)
    if not ok then
        error(err)
    end
    local util_file = assert(io.open(util_dir .. "/util.lua", "w"))
    util_file:write("return {}\n")
    util_file:close()

    local scan_result, scan_err = source_scan.scan_with_options({
        source_roots = { "src" },
    }, {
        project_root = project_root,
    })
    if scan_result == nil then
        error(scan_err)
    end

    assert(scan_result.module_ids["src.demo.pkg"] == true, "relative source root should resolve package module id")
    assert(scan_result.module_ids["src.demo.util"] == true, "relative source root should resolve sibling module id")
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

    local game_node
    for _, node in ipairs(root_view.nodes or {}) do
        if node.id == "game" then
            game_node = node
            break
        end
    end
    assert(game_node ~= nil, "root view should contain game node")
    assert(#(game_node.incoming_dependencies or {}) > 0, "game node should expose incoming dependency indicators")
    assert(#(game_node.outgoing_dependencies or {}) > 0, "game node should expose outgoing dependency indicators")
end

local function _test_projection_collapses_package_init_nodes_into_single_drillable_node()
    local architecture = _analyze_architecture()
    local root_view = architecture.views.root
    local game_view = architecture.views.game
    local presentation_view = architecture.views.presentation

    for _, view in ipairs({ root_view, game_view, presentation_view }) do
        for _, node in ipairs(view.nodes or {}) do
            assert(
                tostring(node.id):find("|file", 1, true) == nil,
                "projection should not emit duplicate init leaf nodes: " .. tostring(node.id)
            )
        end
    end

    local app_node = nil
    for _, node in ipairs(root_view.nodes or {}) do
        if node.id == "app" then
            app_node = node
            break
        end
    end
    assert(app_node ~= nil, "root view should keep a single app node")
    _assert_eq(app_node.display_label, "app", "package nodes with descendants should display namespace label")
    assert(app_node.drillable == true, "package nodes with descendants should remain drillable")
    assert(app_node.leaf == false, "package nodes with descendants should not be marked leaf")
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

local function _test_any_cycle_fails_check()
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
    })

    assert(result.ok == false, "cycle should fail check")
    _assert_eq(result.violations[1].kind, "unexpected_cycle", "cycle should be reported")
    assert(#result.cycles == 1 and #result.cycles[1] == 3, "cycle output should expose module arrays")
end

local function _test_route_engine_emits_orthogonal_paths_without_exact_overlap()
    local routed = route_engine.route_edges({
        {
            id = "a->c",
            from = "a",
            to = "c",
            from_layer = 0,
            to_layer = 1,
            from_rect = { x = 0.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 220.0, y = 160.0, width = 100.0, height = 60.0 },
        },
        {
            id = "b->c",
            from = "b",
            to = "c",
            from_layer = 0,
            to_layer = 1,
            from_rect = { x = 130.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 220.0, y = 160.0, width = 100.0, height = 60.0 },
        },
    })

    _assert_eq(#routed, 2, "route engine should preserve both edges")
    _assert_eq(#(routed[1].route_points or {}), 4, "route engine should emit orthogonal route points")
    _assert_eq(#(routed[2].route_points or {}), 4, "route engine should emit orthogonal route points for adjacent edges")

    local first_signature = table.concat({
        routed[1].route_points[1][1], routed[1].route_points[1][2],
        routed[1].route_points[2][1], routed[1].route_points[2][2],
        routed[1].route_points[3][1], routed[1].route_points[3][2],
        routed[1].route_points[4][1], routed[1].route_points[4][2],
    }, ",")
    local second_signature = table.concat({
        routed[2].route_points[1][1], routed[2].route_points[1][2],
        routed[2].route_points[2][1], routed[2].route_points[2][2],
        routed[2].route_points[3][1], routed[2].route_points[3][2],
        routed[2].route_points[4][1], routed[2].route_points[4][2],
    }, ",")
    assert(first_signature ~= second_signature, "adjacent edges should not fully overlap")
end

local function _test_route_engine_spreads_cross_layer_ports_away_from_center()
    local routed = route_engine.route_edges({
        {
            id = "a->c",
            from = "a",
            to = "c",
            from_layer = 0,
            to_layer = 1,
            from_rect = { x = 0.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 220.0, y = 160.0, width = 100.0, height = 60.0 },
        },
        {
            id = "a->d",
            from = "a",
            to = "d",
            from_layer = 0,
            to_layer = 1,
            from_rect = { x = 0.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 360.0, y = 160.0, width = 100.0, height = 60.0 },
        },
    })

    local first_start = routed[1].route_points[1]
    local second_start = routed[2].route_points[1]
    assert(first_start[1] ~= second_start[1], "cross-layer sibling edges should not share the same start port")
    assert(math.abs(first_start[1] - 50.0) >= 20.0, "cross-layer edge should avoid the top/bottom center exclusion zone")
    assert(math.abs(second_start[1] - 50.0) >= 20.0, "cross-layer edge should avoid the top/bottom center exclusion zone")
    assert(first_start[2] > 60.0, "downward edge should start outside the source node")
end

local function _test_route_engine_uses_side_ports_for_same_layer_edges()
    local routed = route_engine.route_edges({
        {
            id = "a->b",
            from = "a",
            to = "b",
            from_layer = 0,
            to_layer = 0,
            from_rect = { x = 0.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 220.0, y = 0.0, width = 100.0, height = 60.0 },
        },
    })

    local points = routed[1].route_points
    assert(points[1][1] > 100.0, "same-layer edge should leave from the side of the source node")
    assert(points[4][1] < 220.0, "same-layer edge should enter from the side of the target node")
    assert(math.abs(points[1][2] - 30.0) <= 24.0, "same-layer edge should stay near the node side center, not the top edge")
    assert(math.abs(points[4][2] - 30.0) <= 24.0, "same-layer edge should end near the node side center, not the top edge")
end

local function _test_route_engine_avoids_top_bottom_button_lane_for_single_edge()
    local routed = route_engine.route_edges({
        {
            id = "a->c",
            from = "a",
            to = "c",
            from_layer = 0,
            to_layer = 1,
            from_rect = { x = 0.0, y = 0.0, width = 100.0, height = 60.0 },
            to_rect = { x = 0.0, y = 160.0, width = 100.0, height = 60.0 },
        },
    })

    local points = routed[1].route_points
    assert(math.abs(points[1][1] - 50.0) >= 20.0, "single downward edge should not use the button center lane on source")
    assert(math.abs(points[4][1] - 50.0) >= 20.0, "single downward edge should not use the button center lane on target")
    assert(points[4][2] < 160.0, "single downward edge should terminate outside the target node")
end

local function _test_projection_exposes_full_names_and_display_edges()
    local architecture = _analyze_architecture()
    local utils_view = architecture.views["core.utils"]
    assert(utils_view ~= nil, "core.utils view should exist")

    local number_utils_node
    for _, node in ipairs(utils_view.nodes or {}) do
        if node.module_id == "src.core.utils.number_utils" then
            number_utils_node = node
            break
        end
    end

    assert(number_utils_node ~= nil, "core.utils view should contain number_utils leaf")
    _assert_eq(number_utils_node.display_label, "number_utils", "leaf display label should use source file basename")
    _assert_eq(number_utils_node.full_name, "core.utils.number_utils", "leaf full name should strip top-level src prefix")

    local root_view = architecture.views.root
    assert(#(root_view.display_edges or {}) > 0, "root view should expose routed display edges")
    local first_edge = root_view.display_edges[1]
    assert(first_edge ~= nil, "root view should contain at least one display edge")
    assert(#(first_edge.route_points or {}) >= 4, "display edges should expose route points")
    assert(#(first_edge.tooltip_lines or {}) > 0, "display edges should expose tooltip lines")
    assert(first_edge.count >= 1, "display edges should keep aggregate count")
end

local function _test_build_includes_metadata_for_project_root_and_config_path()
    local architecture, err = build.analyze(config, {
        project_root = ".",
        config_path = "scripts/arch/config.lua",
    })
    if architecture == nil then
        error(err)
    end

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

    cli.run({
        "scan",
        "--out", out_path,
    }, {
        script_dir = "scripts/arch",
        default_project_root = ".",
    })

    local payload = json_reader.decode(_read_file(out_path))
    _assert_eq(payload.schema_version, 1, "scan command should write schema_version")
    assert(payload.project_root ~= nil and payload.project_root ~= "", "scan command should write project_root")
    assert(payload.config_path ~= nil and payload.config_path ~= "", "scan command should write config_path")
    assert(payload.views ~= nil and payload.views.root ~= nil, "scan command should keep architecture views")
end

local function _test_cli_supports_external_project_root_and_config()
    local project_root = tmp_root .. "/cli_sample"
    local src_dir = project_root .. "/src/demo"
    local ok, err = common.ensure_dir(src_dir)
    if not ok then
        error(err)
    end

    local alpha_file = assert(io.open(src_dir .. "/alpha.lua", "w"))
    alpha_file:write('local beta = require("src.demo.beta")\nreturn beta\n')
    alpha_file:close()

    local beta_file = assert(io.open(src_dir .. "/beta.lua", "w"))
    beta_file:write("return {}\n")
    beta_file:close()

    local config_path = project_root .. "/sample_architecture.lua"
    local config_file = assert(io.open(config_path, "w"))
    config_file:write(table.concat({
        "return {",
        '  source_roots = { "src" },',
        "  component_rules = {",
        '    { name = "demo", match = { "^src%.demo$", "^src%.demo%..+" }, component = "demo" },',
        "  },",
        "  abstract_rules = {},",
        "  forbidden_dependency_rules = {},",
        "}",
        "",
    }, "\n"))
    config_file:close()

    local out_path = project_root .. "/out/architecture.json"
    cli.run({
        "scan",
        "--project-root", project_root,
        "--config", config_path,
        "--out", out_path,
    }, {
        script_dir = "scripts/arch",
        default_project_root = ".",
    })

    local payload = json_reader.decode(_read_file(out_path))
    assert(payload.modules["src.demo.alpha"] ~= nil, "external project scan should include alpha module")
    assert(payload.modules["src.demo.beta"] ~= nil, "external project scan should include beta module")
    _assert_eq(payload.modules["src.demo.alpha"].component, "demo", "external config should classify modules")
end

local function _test_viewer_command_writes_static_bundle()
    local out_dir = tmp_root .. "/viewer"
    local ok, err = common.ensure_dir(out_dir)
    if not ok then
        error(err)
    end

    local command = 'lua scripts/arch.lua viewer --out-dir "' .. out_dir .. '"'
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
    assert(data_script:find('"display_edges"', 1, true) ~= nil, "viewer payload should contain display_edges")
    assert(data_script:find('"route_points"', 1, true) ~= nil, "viewer payload should contain route_points")
    assert(data_script:find('"indicators"', 1, true) ~= nil, "viewer payload should contain indicators")
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

    cli.run({
        "viewer",
        "--in-json", json_path,
        "--out-dir", out_dir,
    }, {
        script_dir = "scripts/arch",
        default_project_root = ".",
    })

    assert(_exists(out_dir .. "/index.html"), "viewer --in-json should export index.html")
    assert(_exists(out_dir .. "/architecture.json"), "viewer --in-json should export architecture.json")
    local payload = json_reader.decode(_read_file(out_dir .. "/architecture.json"))
    assert(payload.views ~= nil and payload.views.root ~= nil, "viewer --in-json should preserve architecture payload")
end

local function _test_common_builds_open_command()
    local command = common.build_open_command("/tmp/arch_view/index.html")
    assert(command ~= nil and command ~= "", "open command should be non-empty")
    if common.is_windows() then
        assert(command:find("start", 1, true) ~= nil, "windows open command should use start")
    elseif common.is_macos() then
        assert(command:find("open", 1, true) ~= nil, "mac open command should use open")
    else
        assert(command:find("xdg-open", 1, true) ~= nil, "linux open command should use xdg-open")
    end
end

local function _test_json_modules_are_self_contained()
    local reader_source = _read_file("scripts/arch/arch_view/json_reader.lua")
    local writer_source = _read_file("scripts/arch/arch_view/json_writer.lua")
    assert(reader_source:find('src.core.utils.number_utils', 1, true) == nil,
        "json_reader should not depend on src.core.utils.number_utils")
    assert(writer_source:find('src.core.utils.number_utils', 1, true) == nil,
        "json_writer should not depend on src.core.utils.number_utils")
    assert(reader_source:find('require("arch_view.common")', 1, true) ~= nil,
        "json_reader should depend on arch_view.common")
    assert(writer_source:find('require("arch_view.common")', 1, true) ~= nil,
        "json_writer should depend on arch_view.common")
end

local function _test_projection_propagates_deep_subtree_cycles_to_parents()
    local architecture = {
        graph = {
            nodes = {
                "src.alpha.entry",
                "src.alpha.beta.gamma.a",
                "src.alpha.beta.gamma.b",
                "src.delta.core",
            },
            edges = {
                { from = "src.alpha.beta.gamma.a", to = "src.alpha.beta.gamma.b" },
                { from = "src.alpha.beta.gamma.b", to = "src.alpha.beta.gamma.a" },
                { from = "src.delta.core",         to = "src.alpha.entry" },
            },
        },
        modules = {
            ["src.alpha.entry"] = {
                module_id = "src.alpha.entry",
                module_segments = { "src", "alpha", "entry" },
                namespace_segments = { "alpha", "entry" },
                source_path = "src/alpha/entry.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.alpha.beta.gamma.a"] = {
                module_id = "src.alpha.beta.gamma.a",
                module_segments = { "src", "alpha", "beta", "gamma", "a" },
                namespace_segments = { "alpha", "beta", "gamma", "a" },
                source_path = "src/alpha/beta/gamma/a.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.alpha.beta.gamma.b"] = {
                module_id = "src.alpha.beta.gamma.b",
                module_segments = { "src", "alpha", "beta", "gamma", "b" },
                namespace_segments = { "alpha", "beta", "gamma", "b" },
                source_path = "src/alpha/beta/gamma/b.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.delta.core"] = {
                module_id = "src.delta.core",
                module_segments = { "src", "delta", "core" },
                namespace_segments = { "delta", "core" },
                source_path = "src/delta/core.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
        },
        classified_edges = {
            { from = "src.alpha.beta.gamma.a", to = "src.alpha.beta.gamma.b", type = "direct" },
            { from = "src.alpha.beta.gamma.b", to = "src.alpha.beta.gamma.a", type = "direct" },
            { from = "src.delta.core",         to = "src.alpha.entry",        type = "direct" },
        },
        layout = layout.assign_layers({
            nodes = {
                "src.alpha.entry",
                "src.alpha.beta.gamma.a",
                "src.alpha.beta.gamma.b",
                "src.delta.core",
            },
            edges = {
                { from = "src.alpha.beta.gamma.a", to = "src.alpha.beta.gamma.b" },
                { from = "src.alpha.beta.gamma.b", to = "src.alpha.beta.gamma.a" },
                { from = "src.delta.core",         to = "src.alpha.entry" },
            },
        }),
    }

    architecture.views = require("arch_view.projection").build_views(architecture)

    local root_view = architecture.views.root
    local alpha_view = architecture.views.alpha
    local beta_view = architecture.views["alpha.beta"]
    local gamma_view = architecture.views["alpha.beta.gamma"]

    assert(root_view ~= nil, "root view should exist for deep subtree cycle test")
    assert(alpha_view ~= nil, "alpha view should exist for deep subtree cycle test")
    assert(beta_view ~= nil, "alpha.beta view should exist for deep subtree cycle test")
    assert(gamma_view ~= nil, "alpha.beta.gamma view should exist for deep subtree cycle test")

    local root_alpha
    for _, node in ipairs(root_view.nodes or {}) do
        if node.id == "alpha" then
            root_alpha = node
            break
        end
    end
    assert(root_alpha ~= nil, "root view should expose alpha subtree")
    assert(root_alpha.has_cycle_subtree == true, "root alpha node should reflect deep subtree cycle")

    local alpha_beta
    for _, node in ipairs(alpha_view.nodes or {}) do
        if node.id == "beta" then
            alpha_beta = node
            break
        end
    end
    assert(alpha_beta ~= nil, "alpha view should expose beta subtree")
    assert(alpha_beta.has_cycle_subtree == true, "alpha beta node should reflect deep subtree cycle")

    local beta_gamma
    for _, node in ipairs(beta_view.nodes or {}) do
        if node.id == "gamma" then
            beta_gamma = node
            break
        end
    end
    assert(beta_gamma ~= nil, "alpha.beta view should expose gamma subtree")
    assert(beta_gamma.has_cycle_subtree == true, "alpha.beta gamma node should reflect deep subtree cycle")

    local gamma_cycle_count = 0
    for _, edge in ipairs(gamma_view.display_edges or {}) do
        if edge.cycle == true then
            gamma_cycle_count = gamma_cycle_count + 1
        end
    end
    assert(gamma_cycle_count > 0, "deepest view should expose cycle-marked display edges")
end

local function _test_layout_renderer_preserves_viewer_contract_shape()
    local layout_renderer = require("arch_view.layout_renderer")
    local node_rects, layer_items = layout_renderer.build_node_rects({
        layers = {
            { index = 0, modules = { "a", "b" } },
            { index = 1, modules = { "c" } },
        },
    }, {
        a = "A",
        b = "B",
        c = "C",
    }, {
        a = "demo.a",
        b = "demo.b",
        c = "demo.c",
    })

    assert(node_rects.a ~= nil and node_rects.a.width ~= nil, "layout renderer should create node rect for a")
    assert(node_rects.c ~= nil and node_rects.c.height ~= nil, "layout renderer should create node rect for c")
    assert(#layer_items == 2, "layout renderer should create one layer item per layer")
    assert(layer_items[1].nodes[1].display_label == "A", "layout renderer should preserve display labels")

    local decorated = layout_renderer.decorate_display_edges({
        {
            from = "a",
            to = "c",
            type = "direct",
            count = 1,
            module_edges = {
                { from = "src.demo.a", to = "src.demo.c", type = "direct", cycle = false, text = "demo.a -> demo.c" },
            },
            tooltip = {
                { text = "demo.a -> demo.c (1)", cycle = false, type = "direct" },
            },
            tooltip_lines = { "demo.a -> demo.c (1)" },
        },
    }, node_rects, { a = 0, b = 0, c = 1 }, {})

    assert(#decorated == 1, "layout renderer should preserve edge count")
    assert(#(decorated[1].route_points or {}) >= 4, "layout renderer should route display edges")

    local indicators = layout_renderer.build_indicators({
        {
            id = "a",
            has_cycle_subtree = true,
            incoming_dependencies = {
                { text = "x -> a (1)", cycle = false, type = "direct" },
            },
            outgoing_dependencies = {
                { text = "a -> c (1)", cycle = true, type = "direct" },
            },
        },
    })
    assert(#indicators == 2, "layout renderer should emit incoming and outgoing indicators")

    local canvas = layout_renderer.canvas_size(layer_items)
    assert(canvas.width ~= nil and canvas.height ~= nil, "layout renderer should expose canvas dimensions")
end

local function _test_common_resolves_tmp_path_for_windows_shell_compat()
    local original_is_windows = common.is_windows
    local original_system_tmp_dir = common.system_tmp_dir

    common.is_windows = function()
        return true
    end
    common.system_tmp_dir = function()
        return "C:/Users/test/AppData/Local/Temp"
    end

    local resolved = common.resolve_path("C:/repo/monopoly", "/tmp/monopoly_arch_view")
    _assert_eq(
        resolved,
        "C:/Users/test/AppData/Local/Temp/monopoly_arch_view",
        "windows /tmp path should resolve into the system temp directory"
    )

    local drive_resolved = common.resolve_path("C:/repo/monopoly", "/c/work/demo")
    _assert_eq(
        drive_resolved,
        "c:/work/demo",
        "windows /c/... path should resolve to drive-qualified form"
    )

    common.is_windows = original_is_windows
    common.system_tmp_dir = original_system_tmp_dir
end

local function _test_check_includes_projection_cycles()
    local projection = require("arch_view.projection")
    local architecture = {
        graph = {
            nodes = {
                "src.alpha.a1",
                "src.alpha.a2",
                "src.beta.b1",
                "src.beta.b2",
            },
            edges = {
                { from = "src.alpha.a1", to = "src.beta.b1" },
                { from = "src.beta.b2",  to = "src.alpha.a2" },
            },
        },
        modules = {
            ["src.alpha.a1"] = {
                module_id = "src.alpha.a1",
                module_segments = { "src", "alpha", "a1" },
                namespace_segments = { "alpha", "a1" },
                source_path = "src/alpha/a1.lua",
                source_text = "",
                internal_requires = { "src.beta.b1" },
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.alpha.a2"] = {
                module_id = "src.alpha.a2",
                module_segments = { "src", "alpha", "a2" },
                namespace_segments = { "alpha", "a2" },
                source_path = "src/alpha/a2.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.beta.b1"] = {
                module_id = "src.beta.b1",
                module_segments = { "src", "beta", "b1" },
                namespace_segments = { "beta", "b1" },
                source_path = "src/beta/b1.lua",
                source_text = "",
                internal_requires = {},
                external_requires = {},
                component = "demo",
                abstract = false,
            },
            ["src.beta.b2"] = {
                module_id = "src.beta.b2",
                module_segments = { "src", "beta", "b2" },
                namespace_segments = { "beta", "b2" },
                source_path = "src/beta/b2.lua",
                source_text = "",
                internal_requires = { "src.alpha.a2" },
                external_requires = {},
                component = "demo",
                abstract = false,
            },
        },
        classified_edges = {
            { from = "src.alpha.a1", to = "src.beta.b1", type = "direct" },
            { from = "src.beta.b2",  to = "src.alpha.a2", type = "direct" },
        },
        layout = layout.assign_layers({
            nodes = {
                "src.alpha.a1",
                "src.alpha.a2",
                "src.beta.b1",
                "src.beta.b2",
            },
            edges = {
                { from = "src.alpha.a1", to = "src.beta.b1" },
                { from = "src.beta.b2",  to = "src.alpha.a2" },
            },
        }),
    }

    local module_cycles = layout.find_cycles(architecture.graph)
    _assert_eq(#module_cycles, 0, "module-level graph should have no cycles")

    architecture.views = projection.build_views(architecture)

    local projection_cycles = projection.collect_projection_cycles(architecture.views)
    assert(type(projection_cycles) == "table", "projection_cycles should be a table")
    assert(#projection_cycles > 0, "should detect at least one projection-level cycle")

    local root_entry = nil
    for _, entry in ipairs(projection_cycles) do
        if entry.view == "root" then
            root_entry = entry
            break
        end
    end
    assert(root_entry ~= nil, "root view should have a projection cycle")
    assert(#root_entry.feedback_edges > 0, "root projection cycle should have feedback edges")

    local found_feedback = false
    for _, fe in ipairs(root_entry.feedback_edges) do
        if #fe.module_edges > 0 then
            found_feedback = true
        end
    end
    assert(found_feedback, "feedback edges should carry module_edges")
end

return {
    name = "architecture.arch_view_contract",
    tests = {
        { name = "dependency_extract_supports_static_requires",               run = _test_dependency_extract_supports_static_requires },
        { name = "layers_assign_feedback_edges_for_cycles",                   run = _test_layers_assign_feedback_edges_for_cycles },
        { name = "source_scan_treats_init_as_package_entry",                  run = _test_source_scan_treats_init_as_package_entry },
        { name = "source_scan_resolves_relative_root_against_project_root",   run = _test_source_scan_resolves_relative_root_against_project_root },
        { name = "projection_builds_root_and_game_views",                     run = _test_projection_builds_root_and_game_views },
        { name = "projection_collapses_package_init_nodes_into_single_drillable_node", run = _test_projection_collapses_package_init_nodes_into_single_drillable_node },
        { name = "config_classifies_runtime_game_and_ports",                  run = _test_config_classifies_runtime_game_and_ports },
        { name = "any_cycle_fails_check",                                      run = _test_any_cycle_fails_check },
        { name = "route_engine_emits_orthogonal_paths_without_exact_overlap", run = _test_route_engine_emits_orthogonal_paths_without_exact_overlap },
        { name = "route_engine_spreads_cross_layer_ports_away_from_center",   run = _test_route_engine_spreads_cross_layer_ports_away_from_center },
        { name = "route_engine_uses_side_ports_for_same_layer_edges",         run = _test_route_engine_uses_side_ports_for_same_layer_edges },
        { name = "route_engine_avoids_top_bottom_button_lane_for_single_edge", run = _test_route_engine_avoids_top_bottom_button_lane_for_single_edge },
        { name = "projection_exposes_full_names_and_display_edges",           run = _test_projection_exposes_full_names_and_display_edges },
        { name = "build_includes_metadata_for_project_root_and_config_path",  run = _test_build_includes_metadata_for_project_root_and_config_path },
        { name = "cli_scan_writes_metadata",                                  run = _test_cli_scan_writes_metadata },
        { name = "cli_supports_external_project_root_and_config",             run = _test_cli_supports_external_project_root_and_config },
        { name = "viewer_command_writes_static_bundle",                       run = _test_viewer_command_writes_static_bundle },
        { name = "cli_viewer_supports_in_json",                               run = _test_cli_viewer_supports_in_json },
        { name = "common_builds_open_command",                                run = _test_common_builds_open_command },
        { name = "json_modules_are_self_contained",                           run = _test_json_modules_are_self_contained },
        { name = "projection_propagates_deep_subtree_cycles_to_parents",      run = _test_projection_propagates_deep_subtree_cycles_to_parents },
        { name = "layout_renderer_preserves_viewer_contract_shape",           run = _test_layout_renderer_preserves_viewer_contract_shape },
        { name = "common_resolves_tmp_path_for_windows_shell_compat",         run = _test_common_resolves_tmp_path_for_windows_shell_compat },
        { name = "check_includes_projection_cycles",                           run = _test_check_includes_projection_cycles },
    },
}
