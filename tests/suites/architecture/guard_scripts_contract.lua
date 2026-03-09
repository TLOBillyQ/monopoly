local dep_rules = require("internal.dep_rules")
local forbidden_globals = require("internal.forbidden_globals")
local legacy_path_guard = require("internal.legacy_path_guard")

local path_sep = package.config:sub(1, 1)
local tmp_root = (function()
  local env = nil
  if path_sep == "\\" then
    env = os.getenv("TEMP") or os.getenv("TMP")
    if env == nil or env == "" then
      env = "C:/Windows/Temp"
    end
  else
    env = os.getenv("TMPDIR")
    if env == nil or env == "" then
      env = "/tmp"
    end
  end
  env = tostring(env):gsub("\\", "/")
  return env .. "/monopoly_guard_contract_output"
end)()

local function _shell_quote(path)
  return '"' .. tostring(path) .. '"'
end

local function _remove_tree(path)
  if package.config:sub(1, 1) == "\\" then
    os.execute("cmd /c rmdir /s /q " .. _shell_quote(path))
  else
    os.execute("rm -rf " .. _shell_quote(path))
  end
end

local function _ensure_dir(path)
  if package.config:sub(1, 1) == "\\" then
    os.execute("mkdir " .. _shell_quote(path) .. " >nul 2>nul")
  else
    os.execute("mkdir -p " .. _shell_quote(path))
  end
end

local function _write_file(path, text)
  local file = assert(io.open(path, "w"))
  file:write(text)
  file:close()
end

local function _with_fixture(files, fn)
  _remove_tree(tmp_root)
  for relpath, text in pairs(files) do
    local normalized = relpath:gsub("/", path_sep)
    local dir = nil
    if path_sep == "\\" then
      dir = normalized:match("^(.*)\\[^\\]+$")
    else
      dir = normalized:match("^(.*)/[^/]+$")
    end
    if dir then
      _ensure_dir(tmp_root .. path_sep .. dir)
    end
    _write_file(tmp_root .. path_sep .. normalized, text)
  end

  local ok, err = xpcall(fn, debug.traceback)
  _remove_tree(tmp_root)
  if not ok then
    error(err)
  end
end

local function _test_dep_rules_catches_ui_runtime_bypass()
  _with_fixture({
    ["src/turn.lua"] = "local state = {}\nstate.ui_dirty = true\n",
  }, function()
    local result = dep_rules.run({
      rules = {
        {
          roots = { tmp_root .. "/src" },
          forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
          description = "turn flow must route UI writes through output/ui_sync ports",
        },
      },
      forbidden_files = {},
    })

    assert(result.ok == false, "dep_rules should reject direct state.ui_* writes")
    assert(result.violation ~= nil, "dep_rules should report a violation")
    assert(result.violation.path:find("src/turn.lua", 1, true) ~= nil, "dep_rules should point to fixture file")
  end)
end

local function _test_legacy_path_guard_catches_exact_and_prefix_paths()
  local retired_exact = "src.presentation.runtime." .. "presentation_ports"
  local retired_prefix = "src.game.systems.items.item" .. "_"
  _with_fixture({
    ["src/exact.lua"] = 'return require("' .. retired_exact .. '")\n',
    ["tests/prefix.lua"] = 'return require("' .. retired_prefix .. 'executor")\n',
  }, function()
    local result = legacy_path_guard.run({
      scan_roots = { tmp_root .. "/src", tmp_root .. "/tests" },
      retired_exact_paths = { retired_exact },
      retired_prefixes = { retired_prefix },
    })

    assert(result.ok == false, "legacy_path_guard should reject retired paths")
    assert(result.violations ~= nil and #result.violations == 2, "legacy_path_guard should report both exact and prefix hits")
  end)
end

local function _test_forbidden_globals_catches_numeric_cast()
  local forbidden_call = "ton" .. "umber"
  _with_fixture({
    ["scripts/bad.lua"] = "return " .. forbidden_call .. "('1')\n",
  }, function()
    local result = forbidden_globals.run({
      scan_roots = { tmp_root .. "/scripts" },
    })

    assert(result.ok == false, "forbidden_globals should reject tonumber")
    assert(result.violations ~= nil and #result.violations == 1, "forbidden_globals should report one violation")
    assert(result.violations[1].name == "tonumber", "forbidden_globals should identify tonumber")
  end)
end

local function _test_guard_scripts_allow_clean_fixtures()
  _with_fixture({
    ["src/clean.lua"] = "local state = {}\nstate.output = true\nreturn state\n",
    ["tests/clean.lua"] = 'return require("src.game.flow.turn.engine")\n',
    ["scripts/clean.lua"] = "return 1\n",
  }, function()
    local dep_result = dep_rules.run({
      rules = {
        {
          roots = { tmp_root .. "/src" },
          forbidden_patterns = { "state%.ui_[A-Za-z0-9_]+%s*=" },
          description = "turn flow must route UI writes through output/ui_sync ports",
        },
      },
      forbidden_files = {},
    })
    local legacy_result = legacy_path_guard.run({
      scan_roots = { tmp_root .. "/src", tmp_root .. "/tests" },
      retired_exact_paths = { "src.presentation.runtime." .. "presentation_ports" },
      retired_prefixes = { "src.game.systems.items.item" .. "_" },
    })
    local globals_result = forbidden_globals.run({
      scan_roots = { tmp_root .. "/scripts" },
    })

    assert(dep_result.ok == true, "dep_rules should allow clean fixtures")
    assert(legacy_result.ok == true, "legacy_path_guard should allow clean fixtures")
    assert(globals_result.ok == true, "forbidden_globals should allow clean fixtures")
  end)
end

return {
  name = "guard_scripts_contract",
  tests = {
    { name = "dep_rules_catches_ui_runtime_bypass", run = _test_dep_rules_catches_ui_runtime_bypass },
    { name = "legacy_path_guard_catches_exact_and_prefix_paths", run = _test_legacy_path_guard_catches_exact_and_prefix_paths },
    { name = "forbidden_globals_catches_numeric_cast", run = _test_forbidden_globals_catches_numeric_cast },
    { name = "guard_scripts_allow_clean_fixtures", run = _test_guard_scripts_allow_clean_fixtures },
  },
}
