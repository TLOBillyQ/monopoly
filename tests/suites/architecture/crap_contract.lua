local bootstrap = require("tests.bootstrap")
local crap_cli = require("crap_cli")
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

return {
  name = "architecture.crap_contract",
  tests = {
    { name = "luac_listing_extracts_named_functions", run = _test_luac_listing_extracts_named_functions },
    { name = "report_builds_function_metrics_from_coverage", run = _test_report_builds_function_metrics_from_coverage },
    { name = "viewer_writes_static_bundle", run = _test_viewer_writes_static_bundle },
    { name = "cli_report_uses_injected_runner", run = _test_cli_report_uses_injected_runner },
    { name = "cli_viewer_uses_json_loader_and_writer", run = _test_cli_viewer_uses_json_loader_and_writer },
  },
}
