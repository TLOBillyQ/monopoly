local bootstrap = require("tests.bootstrap")
local common = require("shared.lib.common")
local json_reader = require("arch_view.runtime.json_reader")
local scrap = require("quality.scrap")

bootstrap.install_package_paths()

local function _buffer()
  local parts = {}
  return {
    write = function(_, text)
      parts[#parts + 1] = text
    end,
    text = function()
      return table.concat(parts)
    end,
  }
end

local function _assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function _temp_path(name)
  return common.make_temp_path(name, ".json")
end

local function _temp_dir(name)
  local path = common.make_temp_path(name, "")
  local ok, err = common.ensure_dir(path)
  if not ok then
    error(err)
  end
  return path
end

local function _with_vendor_cli_stub(stub, fn)
  local original = package.loaded["scrap4lua.cli"]
  package.loaded["scrap4lua.cli"] = stub
  local ok, result = xpcall(fn, debug.traceback)
  package.loaded["scrap4lua.cli"] = original
  if not ok then
    error(result)
  end
  return result
end

local function _test_default_tmp_root_preserves_monopoly_path_convention()
  assert(scrap.default_tmp_root():find("monopoly_scrap", 1, true) ~= nil,
    "default tmp root should preserve monopoly-specific directory name")
  assert(scrap.resolve_cli_path("/repo", "tmp/demo.json") == scrap.default_tmp_root() .. "/demo.json",
    "tmp alias should resolve under default tmp root")
end

local function _test_help_is_bilingual()
  local out = _buffer()
  local err = _buffer()
  local exit_code = scrap.run({ "--help" }, {
    stdout = out,
    stderr = err,
  })

  assert(exit_code == 0, "help should succeed")
  _assert_contains(out:text(), "用法", "help should include Chinese usage")
  _assert_contains(out:text(), "Usage", "help should include English usage")
  assert(err:text() == "", "help should not write stderr")
end

local function _test_index_forwards_resolved_out_path_to_vendor_cli()
  local captured_args = nil
  _with_vendor_cli_stub({
    run = function(args)
      captured_args = args
      return 0
    end,
  }, function()
    local exit_code = scrap.run({ "index", "--out", "tmp/demo.json" }, {
      stdout = _buffer(),
      stderr = _buffer(),
    })
    assert(exit_code == 0, "index wrapper should succeed")
  end)

  assert(captured_args[1] == "index", "wrapper should forward index command")
  assert(captured_args[2] == "--config", "wrapper should always forward config flag")
  assert(captured_args[4] == "--out", "wrapper should forward out flag")
  assert(captured_args[5] == scrap.default_tmp_root() .. "/demo.json",
    "wrapper should resolve tmp alias before calling vendor cli")
end

local function _test_find_forwards_query_and_limit_to_vendor_cli()
  local captured_args = nil
  _with_vendor_cli_stub({
    run = function(args)
      captured_args = args
      return 0
    end,
  }, function()
    local exit_code = scrap.run({ "find", "--query", "bankruptcy feedback", "--limit", "7" }, {
      stdout = _buffer(),
      stderr = _buffer(),
    })
    assert(exit_code == 0, "find wrapper should succeed")
  end)

  assert(captured_args[1] == "find", "wrapper should forward find command")
  assert(captured_args[4] == "--query", "wrapper should forward query flag")
  assert(captured_args[5] == "bankruptcy feedback", "wrapper should preserve query text")
  assert(captured_args[6] == "--limit", "wrapper should forward limit flag")
  assert(captured_args[7] == "7", "wrapper should preserve limit value")
end

local function _test_bare_cli_defaults_to_viewer_contract()
  local captured_args = nil
  local captured_has_open_path = false
  _with_vendor_cli_stub({
    run = function(args, env)
      captured_args = args
      captured_has_open_path = type(env and env.open_path) == "function"
      return 0
    end,
  }, function()
    local exit_code = scrap.run({}, {
      stdout = _buffer(),
      stderr = _buffer(),
      open_path = function()
        return true
      end,
    })
    assert(exit_code == 0, "bare cli wrapper should succeed")
  end)

  assert(captured_args[1] == "viewer", "bare cli should default to viewer command")
  assert(captured_args[4] == "--out-dir", "bare cli should forward viewer output dir")
  assert(captured_args[5] == common.join_path(scrap.default_tmp_root(), "scrap_view"),
    "bare cli should resolve default viewer dir under scrap tmp root")
  assert(captured_args[6] == "--open", "bare cli should request viewer open by default")
  assert(captured_has_open_path == true, "bare cli should pass open_path through to vendor cli")
end

local function _test_index_writes_json_contract()
  local out_file = _temp_path("scrap4lua_index")
  local exit_code = scrap.run({ "index", "--out", out_file }, {
    stdout = _buffer(),
    stderr = _buffer(),
  })
  assert(exit_code == 0, "index should succeed")

  local payload = assert(common.read_file(out_file))
  local decoded = json_reader.decode(payload)
  common.remove_path(out_file)

  assert(decoded.metadata.project_name == "Monopoly", "index metadata should include project name")
  assert(type(decoded.scraps) == "table" and #decoded.scraps > 0, "index should emit scraps")
  assert(type(decoded.themes) == "table", "index should emit themes")
end

local function _test_find_keeps_query_without_historical_aliases()
  local out = _buffer()
  local exit_code = scrap.run({ "find", "--query", "src.game.systems", "--limit", "5" }, {
    stdout = out,
    stderr = _buffer(),
  })
  assert(exit_code == 0, "find should succeed")

  local decoded = json_reader.decode(out:text())
  assert(type(decoded.expanded_terms) == "table" and #decoded.expanded_terms > 0, "find should emit expanded terms")
  local expanded = table.concat(decoded.expanded_terms, " ")
  assert(expanded:find("src.rules", 1, true) == nil,
    "find should not expand retired historical aliases to current roots")

  local doc = assert(common.read_file("docs/architecture/scrap4lua.md"))
  assert(doc:find("历史搜索词 `src.game.*`", 1, true) == nil,
    "scrap4lua doc should not advertise retired historical search terms")
end

local function _test_find_hits_bankruptcy_feedback_port()
  local out = _buffer()
  local exit_code = scrap.run({ "find", "--query", "bankruptcy feedback", "--limit", "10" }, {
    stdout = out,
    stderr = _buffer(),
  })
  assert(exit_code == 0, "find should succeed")

  local decoded = json_reader.decode(out:text())
  local found = false
  for _, match in ipairs(decoded.matches or {}) do
    if tostring(match.path):find("src/rules/ports/bankruptcy_feedback.lua", 1, true) ~= nil then
      found = true
      break
    end
  end
  assert(found == true, "bankruptcy feedback query should hit bankruptcy_feedback_port")
end

local function _test_viewer_exports_static_bundle_from_generated_index()
  local out_dir = _temp_dir("scrap4lua_viewer_bundle")
  local exit_code = scrap.run({ "viewer", "--out-dir", out_dir }, {
    stdout = _buffer(),
    stderr = _buffer(),
  })

  assert(exit_code == 0, "viewer should succeed")
  assert(common.path_exists(common.join_path(out_dir, "index.html")) == true, "viewer should export index.html")
  assert(common.path_exists(common.join_path(out_dir, "styles.css")) == true, "viewer should export styles.css")
  assert(common.path_exists(common.join_path(out_dir, "script.js")) == true, "viewer should export script.js")
  assert(common.path_exists(common.join_path(out_dir, "scrap_index.json")) == true, "viewer should export scrap_index.json")
  assert(common.path_exists(common.join_path(out_dir, "scrap_data.js")) == true, "viewer should export scrap_data.js")
end

local function _test_viewer_supports_in_json_input()
  local index_file = _temp_path("scrap4lua_viewer_index")
  local out_dir = _temp_dir("scrap4lua_viewer_from_json")
  local out = _buffer()

  assert(scrap.run({ "index", "--out", index_file }, {
    stdout = _buffer(),
    stderr = _buffer(),
  }) == 0, "index pre-step should succeed")

  local exit_code = scrap.run({
    "viewer",
    "--in-json", index_file,
    "--out-dir", out_dir,
  }, {
    stdout = out,
    stderr = _buffer(),
  })

  assert(exit_code == 0, "viewer --in-json should succeed")
  _assert_contains(out:text(), "scrap4lua viewer ok", "viewer output should include English success text")
  _assert_contains(out:text(), "视图已生成", "viewer output should include Chinese success text")
  assert(common.path_exists(common.join_path(out_dir, "scrap_index.json")) == true, "viewer --in-json should export scrap_index.json")
end

local function _test_bare_cli_defaults_to_viewer_bundle()
  local out_dir = common.join_path(scrap.default_tmp_root(), "scrap_view")
  common.remove_path(out_dir)

  local exit_code = scrap.run({}, {
    stdout = _buffer(),
    stderr = _buffer(),
    open_path = function()
      return true
    end,
  })

  assert(exit_code == 0, "bare cli should default to viewer bundle")
  assert(common.path_exists(common.join_path(out_dir, "index.html")) == true, "bare cli should export default viewer index")
end

return {
  name = "architecture.scrap4lua_contract",
  tests = {
    { name = "default_tmp_root_preserves_monopoly_path_convention", run = _test_default_tmp_root_preserves_monopoly_path_convention },
    { name = "help_is_bilingual", run = _test_help_is_bilingual },
    { name = "index_forwards_resolved_out_path_to_vendor_cli", run = _test_index_forwards_resolved_out_path_to_vendor_cli },
    { name = "find_forwards_query_and_limit_to_vendor_cli", run = _test_find_forwards_query_and_limit_to_vendor_cli },
    { name = "bare_cli_defaults_to_viewer_contract", run = _test_bare_cli_defaults_to_viewer_contract },
  },
  tooling_tests = {
    { name = "index_writes_json_contract", run = _test_index_writes_json_contract },
    { name = "find_keeps_query_without_historical_aliases", run = _test_find_keeps_query_without_historical_aliases },
    { name = "find_hits_bankruptcy_feedback_port", run = _test_find_hits_bankruptcy_feedback_port },
    { name = "viewer_exports_static_bundle_from_generated_index", run = _test_viewer_exports_static_bundle_from_generated_index },
    { name = "viewer_supports_in_json_input", run = _test_viewer_supports_in_json_input },
    { name = "bare_cli_defaults_to_viewer_bundle", run = _test_bare_cli_defaults_to_viewer_bundle },
  },
}
