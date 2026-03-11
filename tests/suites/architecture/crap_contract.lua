local bootstrap = require("tests.bootstrap")
local crap_cli = require("crap")
local common = require("crap.common")
local luac_listing = require("crap.luac_listing")
local report = require("crap.report")
local viewer = require("crap.viewer")

bootstrap.install_package_paths()

local path_sep = package.config:sub(1, 1)
local tmp_root = (function()
  local env = nil
  if path_sep == "\\" then
    env = os.getenv("TEMP") or os.getenv("TMP") or "C:/Windows/Temp"
  else
    env = os.getenv("TMPDIR") or "/tmp"
  end
  return tostring(env):gsub("\\", "/") .. "/monopoly_crap_contract"
end)()

local function _shell_quote(path)
  return '"' .. tostring(path or ""):gsub("/", path_sep) .. '"'
end

local function _remove_tree(path)
  local normalized = tostring(path or ""):gsub("\\", "/")
  if path_sep == "\\" then
    os.execute("rmdir /s /q " .. _shell_quote(normalized) .. " >nul 2>nul")
  else
    os.execute("rm -rf " .. _shell_quote(normalized))
  end
end

local function _write_file(path, text)
  local ok, err = common.ensure_parent_dir(path)
  if not ok then
    error(err)
  end
  ok, err = common.write_file(path, text)
  if not ok then
    error(err)
  end
end

local function _with_fixture(files, fn)
  _remove_tree(tmp_root)
  for relpath, text in pairs(files) do
    _write_file(tmp_root .. "/" .. relpath, text)
  end
  local ok, err = xpcall(fn, debug.traceback)
  _remove_tree(tmp_root)
  if not ok then
    error(err)
  end
end

local function _assert_eq(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(actual))
  end
end

local function _test_luac_listing_extracts_named_functions()
  _with_fixture({
    ["src/sample.lua"] = table.concat({
      "local function alpha(flag)",
      "  if flag then",
      "    return 1",
      "  end",
      "  return 0",
      "end",
      "",
      "local sample = {}",
      "function sample.beta(n)",
      "  local total = 0",
      "  for i = 1, n do",
      "    total = total + i",
      "  end",
      "  return total",
      "end",
      "",
      "sample.gamma = function(value)",
      "  while value > 0 do",
      "    value = value - 1",
      "  end",
      "  return value",
      "end",
      "",
      "return sample",
    }, "\n"),
  }, function()
    local source_text = assert(common.read_file(tmp_root .. "/src/sample.lua"))
    local functions, err = luac_listing.analyze_module({
      module_id = "src.sample",
      source_path = tmp_root .. "/src/sample.lua",
      relative_source_path = "src/sample.lua",
      source_name = "src/sample",
      source_text = source_text,
    })
    if functions == nil then
      error(err)
    end
    _assert_eq(#functions, 3, "fixture should expose three named functions")
    _assert_eq(functions[1].name, "alpha", "first function should preserve local name")
    _assert_eq(functions[2].name, "sample.beta", "second function should preserve dotted name")
    _assert_eq(functions[3].name, "sample.gamma", "third function should preserve assignment name")
    assert(functions[2].complexity >= 2, "loop should increase complexity")
  end)
end

local function _test_report_builds_function_metrics_from_coverage()
  _with_fixture({
    ["src/sample.lua"] = table.concat({
      "local function alpha(flag)",
      "  if flag then",
      "    return 1",
      "  end",
      "  return 0",
      "end",
      "",
      "local sample = {}",
      "function sample.beta(n)",
      "  local total = 0",
      "  for i = 1, n do",
      "    total = total + i",
      "  end",
      "  return total",
      "end",
      "",
      "return sample",
    }, "\n"),
  }, function()
    local result, err = report.build({
      project_root = tmp_root,
      lanes = { "behavior" },
      top = 5,
      collect_coverage = function()
        return {
          line_hits = {
            ["src/sample.lua"] = {
              [1] = true,
              [2] = true,
              [3] = true,
              [9] = true,
              [10] = true,
              [11] = true,
              [12] = true,
            },
          },
          lanes = {
            {
              lane = "behavior",
              mode = "release_trimmed",
              total = 1,
              failed = false,
              failure_count = 0,
              failures = {},
            },
          },
        }
      end,
    })
    if result == nil then
      error(err)
    end
    _assert_eq(result.summary.module_count, 1, "fixture should yield one module")
    _assert_eq(result.summary.function_count, 2, "fixture should yield two functions")
    assert(result.functions[1].crap >= result.functions[2].crap, "functions should be sorted by crap descending")
    assert(result.functions[1].coverage <= 1, "coverage should be normalized ratio")
  end)
end

local function _test_viewer_writes_static_bundle()
  _with_fixture({}, function()
    local ok, err = viewer.write({
      script_dir = common.normalize_path(common.current_dir() .. "/scripts/quality"),
      out_dir = tmp_root .. "/viewer_out",
    }, {
      summary = { module_count = 1, function_count = 1, total_crap = 12.5, critical_function_count = 0 },
      modules = {
        { source_name = "src/sample", source_path = "src/sample.lua", max_function_crap = 12.5, function_count = 1 },
      },
      functions = {
        {
          name = "alpha",
          source_path = "src/sample.lua",
          start_line = 1,
          end_line = 4,
          crap = 12.5,
          complexity = 3,
          coverage = 0.5,
          executable_line_count = 4,
          hit_line_count = 2,
          risk_band = "warning",
        },
      },
    }, {
      open = false,
    })
    if not ok then
      error(err)
    end
    local index_content = assert(common.read_file(tmp_root .. "/viewer_out/index.html"))
    assert(index_content:find("CRAP Hotspots", 1, true) ~= nil, "viewer index should be copied")
    local data_js = assert(common.read_file(tmp_root .. "/viewer_out/crap_report_data.js"))
    assert(data_js:find("window.CRAP_REPORT_DATA", 1, true) ~= nil, "viewer should embed report payload")
  end)
end

local function _test_viewer_open_prints_index_and_uses_open_path()
  _with_fixture({}, function()
    local printed = {}
    local original_print = print
    local original_open_path = common.open_path
    local opened_path = nil
    print = function(...)
      local parts = {}
      for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
      end
      printed[#printed + 1] = table.concat(parts, "\t")
    end
    common.open_path = function(path)
      opened_path = path
      return true
    end

    local ok, err = viewer.write({
      script_dir = common.normalize_path(common.current_dir() .. "/scripts/quality"),
      out_dir = tmp_root .. "/viewer_open_out",
    }, {
      summary = { module_count = 1, function_count = 1, total_crap = 1.0, critical_function_count = 0 },
      modules = {},
      functions = {},
    }, {
      open = true,
    })

    print = original_print
    common.open_path = original_open_path
    if not ok then
      error(err)
    end

    local expected_index = tmp_root .. "/viewer_open_out/index.html"
    local saw_index = false
    local saw_opened = false
    for _, line in ipairs(printed) do
      if line:find("[crap] viewer_index=" .. expected_index, 1, true) ~= nil then
        saw_index = true
      end
      if line:find("[crap] viewer_opened=" .. expected_index, 1, true) ~= nil then
        saw_opened = true
      end
    end
    assert(opened_path == expected_index, "viewer should open resolved index path")
    assert(saw_index == true, "viewer should print resolved index path")
    assert(saw_opened == true, "viewer should print opened index path")
  end)
end

local function _test_cli_report_uses_injected_runner()
  _with_fixture({}, function()
    local called = false
    local ok = crap_cli.run({
      "report",
      "--lane", "behavior",
      "--out", tmp_root .. "/report.json",
      "--top", "5",
    }, {
      run_report = function(opts)
        called = true
        _assert_eq(opts.top, 5, "cli should pass top through")
        return { exit_code = 0 }
      end,
    })
    assert(ok == true, "cli report should return true")
    assert(called == true, "cli should delegate to injected runner")
  end)
end

local function _test_cli_viewer_uses_json_loader_and_writer()
  _with_fixture({}, function()
    local load_called = false
    local write_called = false
    local ok = crap_cli.run({
      "viewer",
      "--in-json", tmp_root .. "/input.json",
      "--out-dir", tmp_root .. "/viewer",
    }, {
      load_report = function(path)
        load_called = path:find("input.json", 1, true) ~= nil
        return { summary = {}, modules = {}, functions = {} }
      end,
      write_viewer = function(paths, data)
        write_called = paths.out_dir:find("viewer", 1, true) ~= nil and data.summary ~= nil
        return true
      end,
    })
    assert(ok == true, "cli viewer should return true")
    assert(load_called == true, "cli viewer should load json through injected loader")
    assert(write_called == true, "cli viewer should write bundle through injected writer")
  end)
end

local function _test_cli_viewer_defaults_to_tmp_alias_without_auto_open()
  _with_fixture({}, function()
    local captured_out_dir = nil
    local open_calls = 0
    local ok = crap_cli.run({
      "viewer",
    }, {
      run_report = function(opts)
        return {
          summary = { module_count = 0, function_count = 0, total_crap = 0, critical_function_count = 0 },
          modules = {},
          functions = {},
        }
      end,
      write_viewer = function(paths, data, opts)
        captured_out_dir = paths.out_dir
        if opts and opts.open then
          open_calls = open_calls + 1
        end
        return data and data.summary ~= nil
      end,
    })
    assert(ok == true, "cli viewer should return true")
    assert(captured_out_dir ~= nil, "cli viewer should supply a default output dir")
    assert(captured_out_dir:find(common.default_tmp_root(), 1, true) == 1, "viewer default output should resolve under tmp alias root")
    _assert_eq(open_calls, 0, "explicit viewer command should not auto-open")
  end)
end

local function _test_cli_without_args_defaults_to_opened_viewer()
  _with_fixture({}, function()
    local captured_out_dir = nil
    local open_calls = 0
    local ok = crap_cli.run({}, {
      run_report = function(opts)
        return {
          summary = { module_count = 0, function_count = 0, total_crap = 0, critical_function_count = 0 },
          modules = {},
          functions = {},
        }
      end,
      write_viewer = function(paths, data, opts)
        captured_out_dir = paths.out_dir
        if opts and opts.open then
          open_calls = open_calls + 1
        end
        return data and data.summary ~= nil
      end,
    })
    assert(ok == true, "bare cli should return true")
    assert(captured_out_dir ~= nil, "bare cli should supply viewer output dir")
    assert(captured_out_dir:find(common.default_tmp_root(), 1, true) == 1, "bare cli should resolve tmp alias root")
    _assert_eq(open_calls, 1, "bare cli should auto-open viewer")
  end)
end

local function _test_cli_viewer_reports_missing_json_with_actionable_error()
  _with_fixture({}, function()
    local ok, err = pcall(function()
      crap_cli.run({
        "viewer",
        "--in-json", tmp_root .. "/missing.json",
        "--out-dir", tmp_root .. "/viewer",
      }, {
        load_report = function(path)
          return nil, "cannot open file: " .. tostring(path)
        end,
      })
    end)
    assert(ok == false, "cli viewer should fail when input json is missing")
    assert(tostring(err):find("viewer input json not found or unreadable", 1, true) ~= nil, "error should explain missing input json")
    assert(tostring(err):find("report --out", 1, true) ~= nil, "error should suggest generating report first")
  end)
end

local function _test_common_resolve_cli_path_maps_tmp_alias_to_system_tmp_root()
  local resolved_report = common.resolve_cli_path("/repo/monopoly", "tmp/crap_report.json")
  local resolved_view = common.resolve_cli_path("/repo/monopoly", "tmp/crap_view")
  local expected_root = common.default_tmp_root()
  assert(resolved_report:find(expected_root, 1, true) == 1, "tmp alias should resolve under system tmp root")
  assert(resolved_view:find(expected_root, 1, true) == 1, "tmp alias should resolve viewer under system tmp root")
end

local function _test_cli_report_resolves_tmp_alias_before_runner()
  _with_fixture({}, function()
    local captured_out_path = nil
    local ok = crap_cli.run({
      "report",
      "--out", "tmp/crap_report.json",
    }, {
      run_report = function(opts)
        captured_out_path = opts.out_path
        return { exit_code = 0 }
      end,
    })
    assert(ok == true, "cli report should return true")
    assert(captured_out_path ~= nil, "cli report should pass resolved out path")
    assert(captured_out_path:find(common.default_tmp_root(), 1, true) == 1, "tmp alias should be expanded before runner")
  end)
end

local function _test_cli_viewer_resolves_tmp_alias_before_loader_and_writer()
  _with_fixture({}, function()
    local captured_in_json = nil
    local captured_out_dir = nil
    local ok = crap_cli.run({
      "viewer",
      "--in-json", "tmp/crap_report.json",
      "--out-dir", "tmp/crap_view",
    }, {
      load_report = function(path)
        captured_in_json = path
        return { summary = {}, modules = {}, functions = {} }
      end,
      write_viewer = function(paths, data)
        captured_out_dir = paths.out_dir
        return data and data.summary ~= nil
      end,
    })
    assert(ok == true, "cli viewer should return true")
    assert(captured_in_json:find(common.default_tmp_root(), 1, true) == 1, "tmp alias should be expanded before loader")
    assert(captured_out_dir:find(common.default_tmp_root(), 1, true) == 1, "tmp alias should be expanded before writer")
  end)
end

return {
  name = "architecture.crap_contract",
  tests = {
    { name = "common_resolve_cli_path_maps_tmp_alias_to_system_tmp_root", run = _test_common_resolve_cli_path_maps_tmp_alias_to_system_tmp_root },
    { name = "luac_listing_extracts_named_functions", run = _test_luac_listing_extracts_named_functions },
    { name = "report_builds_function_metrics_from_coverage", run = _test_report_builds_function_metrics_from_coverage },
    { name = "viewer_writes_static_bundle", run = _test_viewer_writes_static_bundle },
    { name = "viewer_open_prints_index_and_uses_open_path", run = _test_viewer_open_prints_index_and_uses_open_path },
    { name = "cli_report_resolves_tmp_alias_before_runner", run = _test_cli_report_resolves_tmp_alias_before_runner },
    { name = "cli_report_uses_injected_runner", run = _test_cli_report_uses_injected_runner },
    { name = "cli_viewer_resolves_tmp_alias_before_loader_and_writer", run = _test_cli_viewer_resolves_tmp_alias_before_loader_and_writer },
    { name = "cli_viewer_uses_json_loader_and_writer", run = _test_cli_viewer_uses_json_loader_and_writer },
    { name = "cli_viewer_defaults_to_tmp_alias_without_auto_open", run = _test_cli_viewer_defaults_to_tmp_alias_without_auto_open },
    { name = "cli_without_args_defaults_to_opened_viewer", run = _test_cli_without_args_defaults_to_opened_viewer },
    { name = "cli_viewer_reports_missing_json_with_actionable_error", run = _test_cli_viewer_reports_missing_json_with_actionable_error },
  },
}
