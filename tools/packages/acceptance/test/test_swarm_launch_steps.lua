-- Unit tests for the SwarmForge launch acceptance steps
-- (packages.acceptance.steps.swarm_launch, features/swarmforge/swarm_launch.feature):
-- config declaration parsing, supported engines, unique session names, and
-- engine availability. File system reads and PATH lookups are the only
-- stubbed boundaries; everything else goes through the public step-handler
-- seam.
local lu = require("luaunit")
local fs_lib = require("foundation.fs")
local proc_lib = require("foundation.proc")
local steps = require("packages.acceptance.steps.swarm_launch")

local _CONF = table.concat({
  "# role declarations for the four-pack",
  "",
  "window-invisible specifier codex master",
  "window-invisible coder codex coder",
  "window-invisible refactorer codex refactorer",
  "window-invisible architect codex architect batch",
  "launcher boss bogus other",
}, "\n")

local function _handlers()
  return steps.handlers()
end

local function _with_stubbed(target, field, value, fn)
  local original = target[field]
  target[field] = value
  local ok, err = pcall(fn)
  target[field] = original
  if not ok then
    error(err, 0)
  end
end

local function _with_read_file(content, fn)
  _with_stubbed(fs_lib, "read_file", function()
    return content
  end, fn)
end

local function _world_with_rows(rows)
  return { project_root = ".", swarm_conf_rows = rows }
end

local function _declared_rows()
  return {
    { role = "specifier", engine = "codex", worktree = "master" },
    { role = "coder", engine = "codex", worktree = "coder" },
    { role = "refactorer", engine = "codex", worktree = "refactorer" },
    { role = "architect", engine = "codex", worktree = "architect" },
  }
end

TestSwarmLaunchSteps = {}

function TestSwarmLaunchSteps:test_parses_window_invisible_rows_and_ignores_comments_and_other_directives()
  local world = { project_root = "." }
  _with_read_file(_CONF, function()
    local handlers = _handlers()
    local ok = handlers["解析 swarm 启动配置"](world)
    lu.assertTrue(ok)
  end)
  lu.assertIs(#world.swarm_conf_rows, 4)
  lu.assertIs(world.swarm_conf_rows[2].role, "coder")
  lu.assertIs(world.swarm_conf_rows[2].engine, "codex")
  lu.assertIs(world.swarm_conf_rows[2].worktree, "coder")
  lu.assertIs(world.swarm_conf_rows[4].role, "architect")
end

function TestSwarmLaunchSteps:test_parses_plain_window_rows_as_well()
  _with_read_file("window-invisible coder codex coder\nwindow refactorer codex refactorer\n", function()
    local world = { project_root = "." }
    local ok = _handlers()["解析 swarm 启动配置"](world)
    lu.assertTrue(ok)
    lu.assertIs(#world.swarm_conf_rows, 2)
    lu.assertIs(world.swarm_conf_rows[2].engine, "codex")
  end)
end

function TestSwarmLaunchSteps:test_declaration_step_returns_the_matching_role_row()
  local handlers = _handlers()
  local ok, err = handlers["swarm 配置声明角色<角色名>"](_world_with_rows(_declared_rows()), { ["角色名"] = "coder" })
  lu.assertTrue(ok, err or "")
  lu.assertIs(err, nil)
  lu.assertIs(handlers["swarm 配置声明角色<角色名>"](_world_with_rows(_declared_rows()), { ["角色名"] = "boss" }), nil)
end

function TestSwarmLaunchSteps:test_declaration_step_reports_undeclared_roles()
  local handlers = _handlers()
  local ok, err = handlers["swarm 配置声明角色<角色名>"](_world_with_rows(_declared_rows()), { ["角色名"] = "boss" })
  lu.assertNil(ok)
  lu.assertEvalToTrue(err:find("swarm 配置未声明角色 boss", 1, true), err)
end

function TestSwarmLaunchSteps:test_supported_engine_accepts_codex_and_rejects_unknown_engines()
  local handlers = _handlers()
  local ok = handlers["角色<角色名>使用受支持的引擎"]({ swarm_role = { role = "coder", engine = "codex" } }, { ["角色名"] = "coder" })
  lu.assertTrue(ok)

  local rejected, err = handlers["角色<角色名>使用受支持的引擎"](
    _world_with_rows({ { role = "coder", engine = "bogus" } }),
    { ["角色名"] = "coder" }
  )
  lu.assertNil(rejected)
  lu.assertEvalToTrue(err:find("角色 coder 的引擎不受支持: bogus", 1, true), err)
end

function TestSwarmLaunchSteps:test_unique_session_name_accepts_each_role_once()
  local handlers = _handlers()
  local ok = handlers["角色<角色名>分配唯一会话名"](_world_with_rows(_declared_rows()), { ["角色名"] = "architect" })
  lu.assertTrue(ok)
end

function TestSwarmLaunchSteps:test_unique_session_name_rejects_duplicate_role_rows()
  local handlers = _handlers()
  local rows = _declared_rows()
  rows[#rows + 1] = { role = "coder", engine = "codex", worktree = "coder" }
  local ok, err = handlers["角色<角色名>分配唯一会话名"](_world_with_rows(rows), { ["角色名"] = "coder" })
  lu.assertNil(ok)
  lu.assertEvalToTrue(err:find("角色 coder 在配置中出现 2 次", 1, true), err)
end

function TestSwarmLaunchSteps:test_engine_available_when_command_exists_on_path()
  _with_stubbed(proc_lib, "command_exists", function(name)
    return name == "codex"
  end, function()
    local handlers = _handlers()
    local world = _world_with_rows(_declared_rows())
    local checked = handlers["检查角色<角色名>的引擎是否已安装"](world, { ["角色名"] = "coder" })
    lu.assertTrue(checked)
    lu.assertIs(world.engine_available, true)
    local available = handlers["角色<角色名>的引擎可用"](world)
    lu.assertTrue(available)
  end)
end

function TestSwarmLaunchSteps:test_engine_unavailable_reports_engine_name()
  _with_stubbed(proc_lib, "command_exists", function()
    return false
  end, function()
    local handlers = _handlers()
    local world = _world_with_rows(_declared_rows())
    handlers["检查角色<角色名>的引擎是否已安装"](world, { ["角色名"] = "coder" })
    local available, err = handlers["角色<角色名>的引擎可用"](world)
    lu.assertNil(available)
    lu.assertEvalToTrue(err:find("引擎 codex 不可用", 1, true), err)
  end)
end

-- Property-style coverage for the parser: idempotence, formatting stability
-- (comments / blank lines), and broad input ranges over generated inputs.
-- Deterministic; follows the repo's fuzz-probe convention (#190).
TestSwarmLaunchStepsProperties = {}

local _ROLE_NAMES = { "specifier", "coder", "refactorer", "architect" }
local _ENGINE_NAMES = { "codex", "claude", "copilot", "grok" }

local function _declared_line(role, engine, worktree)
  return "window-invisible " .. role .. " " .. engine .. " " .. worktree
end

local function _rows_equal(left, right)
  if #left ~= #right then
    return false
  end
  for index = 1, #left do
    local a, b = left[index], right[index]
    if a.role ~= b.role or a.engine ~= b.engine or a.worktree ~= b.worktree then
      return false
    end
  end
  return true
end

-- Build a conf body with the given row lines plus comment/blank noise rows
-- inserted before, between, and after them.
local function _noisy_conf(row_lines)
  local lines = { "# leading comment", "" }
  for index, line in ipairs(row_lines) do
    lines[#lines + 1] = line
    lines[#lines + 1] = index % 2 == 0 and ("# trailing comment " .. index) or ""
  end
  lines[#lines + 1] = "launcher boss bogus other"
  lines[#lines + 1] = ""
  return table.concat(lines, "\n")
end

local function _parsed_rows(content)
  local world = { project_root = "." }
  _with_read_file(content, function()
    local ok = _handlers()["解析 swarm 启动配置"](world)
    lu.assertTrue(ok)
  end)
  return world.swarm_conf_rows
end

function TestSwarmLaunchStepsProperties:test_parse_conf_is_idempotent_and_caches_rows()
  local content = _noisy_conf({ _declared_line("coder", "codex", "coder") })
  local world = { project_root = "." }
  local first, second
  _with_read_file(content, function()
    local handlers = _handlers()
    lu.assertTrue(handlers["解析 swarm 启动配置"](world))
    first = world.swarm_conf_rows
    lu.assertTrue(handlers["解析 swarm 启动配置"](world))
    second = world.swarm_conf_rows
  end)
  lu.assertIs(first, second)
  lu.assertTrue(_rows_equal(first, _parsed_rows(content)))
end

function TestSwarmLaunchStepsProperties:test_comments_and_blank_lines_do_not_change_parsed_rows()
  for _, role in ipairs(_ROLE_NAMES) do
    for _, engine in ipairs(_ENGINE_NAMES) do
      local row_lines = { _declared_line(role, engine, role) }
      local canonical = table.concat(row_lines, "\n")
      lu.assertTrue(_rows_equal(_parsed_rows(canonical), _parsed_rows(_noisy_conf(row_lines))),
        role .. "/" .. engine)
    end
  end
end

function TestSwarmLaunchStepsProperties:test_parses_large_generated_config_without_loss()
  local row_lines = {}
  for index = 1, 100 do
    row_lines[#row_lines + 1] = _declared_line(
      "role" .. index,
      _ENGINE_NAMES[(index - 1) % #_ENGINE_NAMES + 1],
      "w" .. index
    )
  end
  local parsed = _parsed_rows(table.concat(row_lines, "\n"))
  lu.assertIs(#parsed, 100)
  for index = 1, 100 do
    lu.assertIs(parsed[index].role, "role" .. index)
    lu.assertIs(parsed[index].engine, _ENGINE_NAMES[(index - 1) % #_ENGINE_NAMES + 1])
    lu.assertIs(parsed[index].worktree, "w" .. index)
  end
end


return TestSwarmLaunchSteps
