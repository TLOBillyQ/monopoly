---@diagnostic disable: undefined-global, undefined-field, need-check-nil, unused-local

local common = require("shared.lib.common")
local json_reader = require("arch_view.runtime.json_reader")
require("spec.support.shared_support")

local _original_arg0 = arg and arg[0] or nil
if arg ~= nil then
  arg[0] = "tools/quality/scrap.lua"
end
local scrap = require("quality.scrap")
if arg ~= nil then
  arg[0] = _original_arg0
end

local function buffer()
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

local function assert_contains(text, expected, message)
  if tostring(text or ""):find(expected, 1, true) == nil then
    error((message or "missing expected text") .. "\nexpected: " .. tostring(expected) .. "\nactual: " .. tostring(text))
  end
end

local function temp_path(name)
  return common.make_temp_path(name, ".json")
end

local function temp_dir(name)
  local path = common.make_temp_path(name, "")
  local ok, err = common.ensure_dir(path)
  if not ok then
    error(err)
  end
  return path
end

local function with_vendor_cli_stub(stub, fn)
  local original = package.loaded["scrap4lua.cli"]
  package.loaded["scrap4lua.cli"] = stub
  local ok, result = xpcall(fn, debug.traceback)
  package.loaded["scrap4lua.cli"] = original
  if not ok then
    error(result)
  end
  return result
end

describe("scrap4lua_contract", function()
  it("default_tmp_root_preserves_monopoly_path_convention", function()
    assert.is_not_nil(scrap.default_tmp_root():find("monopoly_scrap", 1, true),
      "default tmp root should preserve monopoly-specific directory name")
    assert.equals(scrap.default_tmp_root() .. "/demo.json", scrap.resolve_cli_path("/repo", "tmp/demo.json"),
      "tmp alias should resolve under default tmp root")
  end)

  it("help_is_bilingual", function()
    local out = buffer()
    local err = buffer()
    local exit_code = scrap.run({ "--help" }, {
      stdout = out,
      stderr = err,
    })

    assert.equals(0, exit_code, "help should succeed")
    assert_contains(out:text(), "用法", "help should include Chinese usage")
    assert_contains(out:text(), "Usage", "help should include English usage")
    assert.equals("", err:text(), "help should not write stderr")
  end)

  it("index_forwards_resolved_out_path_to_vendor_cli", function()
    local captured_args = nil
    with_vendor_cli_stub({
      run = function(args)
        captured_args = args
        return 0
      end,
    }, function()
      local exit_code = scrap.run({ "index", "--out", "tmp/demo.json" }, {
        stdout = buffer(),
        stderr = buffer(),
      })
      assert.equals(0, exit_code, "index wrapper should succeed")
    end)

    assert.equals("index", captured_args[1], "wrapper should forward index command")
    assert.equals("--config", captured_args[2], "wrapper should always forward config flag")
    assert.equals("--out", captured_args[4], "wrapper should forward out flag")
    assert.equals(scrap.default_tmp_root() .. "/demo.json", captured_args[5],
      "wrapper should resolve tmp alias before calling vendor cli")
  end)

  it("find_forwards_query_and_limit_to_vendor_cli", function()
    local captured_args = nil
    with_vendor_cli_stub({
      run = function(args)
        captured_args = args
        return 0
      end,
    }, function()
      local exit_code = scrap.run({ "find", "--query", "bankruptcy feedback", "--limit", "7" }, {
        stdout = buffer(),
        stderr = buffer(),
      })
      assert.equals(0, exit_code, "find wrapper should succeed")
    end)

    assert.equals("find", captured_args[1], "wrapper should forward find command")
    assert.equals("--query", captured_args[4], "wrapper should forward query flag")
    assert.equals("bankruptcy feedback", captured_args[5], "wrapper should preserve query text")
    assert.equals("--limit", captured_args[6], "wrapper should forward limit flag")
    assert.equals("7", captured_args[7], "wrapper should preserve limit value")
  end)

  it("bare_cli_defaults_to_viewer_contract", function()
    local captured_args = nil
    local captured_has_open_path = false
    with_vendor_cli_stub({
      run = function(args, env)
        captured_args = args
        captured_has_open_path = type(env and env.open_path) == "function"
        return 0
      end,
    }, function()
      local exit_code = scrap.run({}, {
        stdout = buffer(),
        stderr = buffer(),
        open_path = function()
          return true
        end,
      })
      assert.equals(0, exit_code, "bare cli wrapper should succeed")
    end)

    assert.equals("viewer", captured_args[1], "bare cli should default to viewer command")
    assert.equals("--out-dir", captured_args[4], "bare cli should forward viewer output dir")
    assert.equals(common.join_path(scrap.default_tmp_root(), "scrap_view"), captured_args[5],
      "bare cli should resolve default viewer dir under scrap tmp root")
    assert.equals("--open", captured_args[6], "bare cli should request viewer open by default")
    assert.is_true(captured_has_open_path, "bare cli should pass open_path through to vendor cli")
  end)

  it("index_writes_json_contract", function()
    local out_file = temp_path("scrap4lua_index")
    local exit_code = scrap.run({ "index", "--out", out_file }, {
      stdout = buffer(),
      stderr = buffer(),
    })
    assert.equals(0, exit_code, "index should succeed")

    local payload = assert(common.read_file(out_file))
    local decoded = json_reader.decode(payload)
    common.remove_path(out_file)

    assert.equals("Monopoly", decoded.metadata.project_name, "index metadata should include project name")
    assert.is_true(type(decoded.scraps) == "table" and #decoded.scraps > 0, "index should emit scraps")
    assert.is_true(type(decoded.themes) == "table", "index should emit themes")
  end)

  it("find_keeps_query_without_historical_aliases", function()
    local out = buffer()
    local exit_code = scrap.run({ "find", "--query", "src.game.systems", "--limit", "5" }, {
      stdout = out,
      stderr = buffer(),
    })
    assert.equals(0, exit_code, "find should succeed")

    local decoded = json_reader.decode(out:text())
    assert.is_true(type(decoded.expanded_terms) == "table" and #decoded.expanded_terms > 0, "find should emit expanded terms")
    local expanded = table.concat(decoded.expanded_terms, " ")
    assert.is_nil(expanded:find("src.rules", 1, true),
      "find should not expand retired historical aliases to current roots")

    local doc = assert(common.read_file("docs/architecture/scrap4lua.md"))
    assert.is_nil(doc:find("历史搜索词 `src.game.*`", 1, true),
      "scrap4lua doc should not advertise retired historical search terms")
  end)

  it("find_hits_bankruptcy_feedback_port", function()
    local out = buffer()
    local exit_code = scrap.run({ "find", "--query", "bankruptcy feedback", "--limit", "10" }, {
      stdout = out,
      stderr = buffer(),
    })
    assert.equals(0, exit_code, "find should succeed")

    local decoded = json_reader.decode(out:text())
    local found = false
    for _, match in ipairs(decoded.matches or {}) do
      if tostring(match.path):find("src/rules/ports/bankruptcy_feedback.lua", 1, true) ~= nil then
        found = true
        break
      end
    end
    assert.is_true(found, "bankruptcy feedback query should hit bankruptcy_feedback_port")
  end)

  it("viewer_exports_static_bundle_from_generated_index", function()
    local out_dir = temp_dir("scrap4lua_viewer_bundle")
    local exit_code = scrap.run({ "viewer", "--out-dir", out_dir }, {
      stdout = buffer(),
      stderr = buffer(),
    })

    assert.equals(0, exit_code, "viewer should succeed")
    assert.is_true(common.path_exists(common.join_path(out_dir, "index.html")), "viewer should export index.html")
    assert.is_true(common.path_exists(common.join_path(out_dir, "styles.css")), "viewer should export styles.css")
    assert.is_true(common.path_exists(common.join_path(out_dir, "script.js")), "viewer should export script.js")
    assert.is_true(common.path_exists(common.join_path(out_dir, "scrap_index.json")), "viewer should export scrap_index.json")
    assert.is_true(common.path_exists(common.join_path(out_dir, "scrap_data.js")), "viewer should export scrap_data.js")
  end)

  it("viewer_supports_in_json_input", function()
    local index_file = temp_path("scrap4lua_viewer_index")
    local out_dir = temp_dir("scrap4lua_viewer_from_json")
    local out = buffer()

    assert.equals(0, scrap.run({ "index", "--out", index_file }, {
      stdout = buffer(),
      stderr = buffer(),
    }), "index pre-step should succeed")

    local exit_code = scrap.run({
      "viewer",
      "--in-json", index_file,
      "--out-dir", out_dir,
    }, {
      stdout = out,
      stderr = buffer(),
    })

    assert.equals(0, exit_code, "viewer --in-json should succeed")
    assert_contains(out:text(), "scrap4lua viewer ok", "viewer output should include English success text")
    assert_contains(out:text(), "视图已生成", "viewer output should include Chinese success text")
    assert.is_true(common.path_exists(common.join_path(out_dir, "scrap_index.json")), "viewer --in-json should export scrap_index.json")
  end)

  it("bare_cli_defaults_to_viewer_bundle", function()
    local out_dir = common.join_path(scrap.default_tmp_root(), "scrap_view")
    common.remove_path(out_dir)

    local exit_code = scrap.run({}, {
      stdout = buffer(),
      stderr = buffer(),
      open_path = function()
        return true
      end,
    })

    assert.equals(0, exit_code, "bare cli should default to viewer bundle")
    assert.is_true(common.path_exists(common.join_path(out_dir, "index.html")), "bare cli should export default viewer index")
  end)
end)
