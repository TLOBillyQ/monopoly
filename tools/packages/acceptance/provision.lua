-- packages/acceptance/provision.lua —— APS PATH 三件的幂等 provision 入口(工单 #606)
--
-- 背景:任务卡「配置蛋仔lua swarm-forge环境」把 APS 三件(gherkin-parser /
-- ir-dry-checker / gherkin-mutator)从 Babashka 版 Acceptance-Pipeline-Specification
-- 迁到本仓 `tools/tools.lock` 钉定的 Lua rock `acceptance4lua`(bb 版读不了本仓
-- `# language: zh-CN` 的 feature,直接 `missing feature declaration`)。供给形态是
-- `<swarm-root>/.swarmforge/bin/` 里三个 bash→Lua 转发器(launcher 把该目录放 PATH 最前)。
--
-- 缺口正是 `.swarmforge/` 属 gitignored 运行时状态、`distclean` 连它一起删:转发器丢了
-- 没有版本化的重建入口,只能照 constitution 里的配方手抄 bash。本文件就是那份配方的
-- 版本化真源——正文由 M.forwarder_body 纯演算,落盘由 M.provision 幂等执行。
--
-- 三条口径与既有车道一致:
--   1. 目标 bin 目录跟着 launcher 的 PATH 走 = SwarmForge 项目根(持 `.swarmforge/roles.tsv`
--      的目录;worktree 场景下即 `git --git-common-dir` 的父目录),与
--      `swarm_tool.sh require` 的解析口径同构——否则 provision 与 probe 各说各话;
--   2. 解释器探测式复用 packages.luaunit_runner.lua54(探不到 lua5.4 退回 PATH 上的
--      "lua"),并烘进正文:PATH 上的 `lua` 可能是 5.5,不是本仓钉定的 5.4;
--   3. rock 装载复用 foundation.bootstrap.ensure_tool,落 `<swarm-root>/.toolcache/luarocks`
--      ——与转发器实际 exec 的那份入口同一个根,不然装完入口仍找不到 rock。
local _self = debug.getinfo(1, "S").source or "@tools/packages/acceptance/provision.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local _, bootstrap = _sb.install("tools/packages/acceptance", _self)

local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")
local shell_lib = require("foundation.shell")
local lua54 = require("packages.luaunit_runner.lua54")

local M = {}

local _APS_ROCK = "acceptance4lua"
local _BIN_RELATIVE = ".swarmforge/bin"
local _ROLES_MARKER = ".swarmforge/roles.tsv"

-- 转发器登记表:一名一入口一契约;顺序即落盘与报告顺序。
M.TOOLS = {
  {
    name = "gherkin-parser",
    entrypoint = "tools/packages/acceptance/cli/parser.lua",
    contract = "gherkin-parser <feature> <json-ir>   (exit 2 usage / 1 failure)",
  },
  {
    name = "ir-dry-checker",
    entrypoint = "tools/packages/acceptance/cli/ir_dry.lua",
    contract = "ir-dry-checker <json-ir> <report-json> [--include-exact]",
  },
  {
    name = "gherkin-mutator",
    entrypoint = "tools/packages/acceptance_mutate/mutator.lua",
    contract = "gherkin-mutator --feature <path> --runner-worker <cmd> [options]",
  },
}

-- 差分突变钳制(章程:Gherkin 变异对 feature 清单差分,--level full 不作选项给;worker
-- 上限 4)。每个分支自己收完该吃的 token:不留 `[ ... ] && shift` 这类假条件——它在
-- `set -e` 下失败即让转发器带非零码退场。`--level` 后面没值时只透传旗标,缺值交入口判用量错。
local _MUTATOR_CLAMP = {
  "args=()",
  "while [ $# -gt 0 ]; do",
  '  case "$1" in',
  "    --level)",
  '      if [ "${2:-}" = "full" ]; then',
  "        args+=(--level hard)",
  "        shift",
  "        if [ $# -gt 0 ]; then shift; fi",
  "      else",
  '        args+=("$1")',
  "        shift",
  "      fi ;;",
  "    --workers)",
  "      shift",
  "      if [ $# -gt 0 ]; then shift; fi ;;",
  '    *) args+=("$1"); shift ;;',
  "  esac",
  "done",
  "args+=(--workers 4)",
}

function M.tool(name)
  for _, tool in ipairs(M.TOOLS) do
    if tool.name == name then
      return tool
    end
  end
  return nil
end

-- 转发器正文(纯演算,不起进程不碰盘)。仓根由脚本自身位置反推、不烘绝对路径——转发器
-- 得随仓搬家;解释器相反,烘探测结果,因为它决定跑的是不是钉定的那份 Lua。
function M.forwarder_body(name, lua_bin)
  local tool = M.tool(name)
  if tool == nil then
    return nil
  end

  local lines = {
    "#!/usr/bin/env bash",
    "# SwarmForge APS tool - Lua backend (zh-CN Gherkin capable).",
    "# Contract: " .. tool.contract,
    "# Provisioned idempotently by: lua tools/packages/acceptance/provision.lua",
    '# Do NOT run "swarm_tool.sh ensure ' .. tool.name .. '" - it swaps in the Babashka',
    "# APS build, which fails on this repo's zh-CN features, and refetches its upstream",
    "# sources. Probe availability with: swarm_tool.sh require " .. tool.name,
    "# See swarmforge/constitution/articles/local-engineering.prompt.",
    "set -e",
    'root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"',
  }
  local exec_line
  if tool.name == "gherkin-mutator" then
    for _, line in ipairs(_MUTATOR_CLAMP) do
      lines[#lines + 1] = line
    end
    exec_line = ' "$root/' .. tool.entrypoint .. '" ${args[@]+"${args[@]}"}'
  else
    exec_line = ' "$root/' .. tool.entrypoint .. '" "$@"'
  end
  lines[#lines + 1] = "exec " .. shell_lib.shell_quote(lua_bin) .. exec_line
  return table.concat(lines, "\n") .. "\n"
end

function M.desired_bodies(lua_bin)
  local bodies = {}
  for _, tool in ipairs(M.TOOLS) do
    bodies[tool.name] = M.forwarder_body(tool.name, lua_bin)
  end
  return bodies
end

function M.bin_dir(repo_root)
  return path_lib.join_path(repo_root, _BIN_RELATIVE)
end

function M.detect_lua_bin()
  return lua54.lua54_bin()
end

-- 幂等落盘:内容一致不动;缺失或漂移才写并 chmod 755。options.lua_bin 缺省走探测,
-- options.tools 给子集时只碰子集。失败返回 (nil, err),已写部分不回滚——正文可重入。
function M.provision(options)
  options = options or {}
  local bin_dir = options.bin_dir
  if bin_dir == nil or bin_dir == "" then
    return nil, "provision: 缺少 bin_dir"
  end

  local lua_bin = options.lua_bin or M.detect_lua_bin()
  local desired = M.desired_bodies(lua_bin)

  local ok, err = fs_lib.ensure_dir(bin_dir)
  if not ok then
    return nil, err
  end

  local written = {}
  local unchanged = {}
  for _, tool in ipairs(options.tools or M.TOOLS) do
    local body = desired[tool.name]
    if body == nil then
      return nil, "provision: 未登记的 APS 工具 " .. tostring(tool.name)
    end
    local path = path_lib.join_path(bin_dir, tool.name)
    if fs_lib.read_raw(path) == body then
      unchanged[#unchanged + 1] = tool.name
    else
      local wrote, write_err = fs_lib.write_file(path, body)
      if not wrote then
        return nil, write_err
      end
      local chmod = proc_lib.run_command({ "chmod", "755", path })
      if not chmod.ok then
        return nil, "chmod 755 失败: " .. path
      end
      written[#written + 1] = tool.name
    end
  end

  return {
    bin_dir = bin_dir,
    lua_bin = lua_bin,
    written = written,
    unchanged = unchanged,
  }
end

-- 候选根顺序:先 git --git-common-dir 的父目录(worktree 共享的项目根),再本 worktree
-- 顶,再 cwd。相对 common dir 以 cwd 解析。纯演算:cwd 由调用方(IO 壳)给,本函数不起进程。
function M.swarm_root_candidates(probe)
  local source = probe or {}
  local cwd = path_lib.normalize_path(source.cwd or "")
  local candidates = {}

  local common_dir = tostring(source.git_common_dir or "")
  if common_dir ~= "" then
    local absolute = path_lib.resolve_path(cwd, common_dir)
    candidates[#candidates + 1] = path_lib.parent_dir(absolute) or absolute
  end

  local toplevel = tostring(source.toplevel or "")
  if toplevel ~= "" then
    candidates[#candidates + 1] = path_lib.normalize_path(toplevel)
  end
  candidates[#candidates + 1] = cwd
  return candidates
end

function M.has_swarm_roles(repo_root)
  return fs_lib.path_exists(path_lib.join_path(repo_root, _ROLES_MARKER)) == true
end

-- 取第一个真持有 .swarmforge/roles.tsv 的候选;都不是就没有可供给的 SwarmForge 根。
function M.select_swarm_root(candidates, has_roles)
  local probe = has_roles or M.has_swarm_roles
  for _, dir in ipairs(candidates or {}) do
    if dir ~= nil and dir ~= "" and probe(dir) then
      return dir
    end
  end
  return nil
end

local function _first_line(output)
  return tostring(output or ""):gsub("\r", ""):match("^[^\n]*") or ""
end

-- git 两问 + 纯候选演算的 IO 壳。
function M.resolve_swarm_root()
  local common = proc_lib.run_command({ "git", "rev-parse", "--git-common-dir" })
  local toplevel = proc_lib.run_command({ "git", "rev-parse", "--show-toplevel" })
  local candidates = M.swarm_root_candidates({
    git_common_dir = common.ok and _first_line(common.output) or "",
    toplevel = toplevel.ok and _first_line(toplevel.output) or "",
    cwd = env_lib.current_dir(),
  })
  local root = M.select_swarm_root(candidates, M.has_swarm_roles)
  if root == nil then
    return nil, "未找到 SwarmForge 项目根(缺 " .. _ROLES_MARKER .. ")"
  end
  return root
end

function M.usage()
  return table.concat({
    "用法: lua tools/packages/acceptance/provision.lua",
    "",
    "幂等重建 SwarmForge 的 APS PATH 三件——<swarm-root>/.swarmforge/bin/ 里的",
    "gherkin-parser / ir-dry-checker / gherkin-mutator bash→Lua 转发器。入口是本仓",
    "tools/tools.lock 钉定的 acceptance4lua rock 的 Lua 面;launcher 把该 bin 目录放 PATH",
    "最前,所以这三份文件就是「下次启动可用」的载体。",
    "",
    "语义:",
    "  1. 确保 acceptance4lua rock 在 <swarm-root>/.toolcache/luarocks(foundation.bootstrap)。",
    "  2. 内容一致则不写;缺失或漂移才重写并 chmod 755——可反复跑,distclean / 新克隆后跑它。",
    "  3. 解释器探测 packages.luaunit_runner.lua54,探不到 lua5.4 退回 PATH 上的 lua。",
    "",
    "探测用 `swarm_tool.sh require <aps-tool>`;不要 `swarm_tool.sh ensure <aps-tool>`——",
    "ensure 会把转发器换成 Babashka 包装器,并把上游 Clojure 克隆拖回 .swarmforge/tools/。",
    "真源:swarmforge/constitution/articles/local-engineering.prompt、tools/specs/acceptance4lua.prompt。",
    "",
  }, "\n") .. "\n"
end

-- 命令面退出码与 tools/cli.lua 同一约定(#300 Q2):0 成功 / 1 业务失败 / 2 用法错误。
function M.main(args)
  local tokens = args or {}
  for _, value in ipairs(tokens) do
    if value == "--help" or value == "-h" then
      io.write(M.usage())
      return 0
    end
  end
  if #tokens > 0 then
    io.write(M.usage())
    io.write("provision 不接受参数: " .. table.concat(tokens, " ") .. "\n")
    return 2
  end

  local root, root_err = M.resolve_swarm_root()
  if root == nil then
    io.write("provision 失败: " .. tostring(root_err) .. "\n")
    return 1
  end

  local rock, rock_err = bootstrap.ensure_tool(_APS_ROCK, { repo_root = root })
  if rock == nil then
    io.write("provision 失败: " .. tostring(rock_err) .. "\n")
    return 1
  end

  local report, err = M.provision({ bin_dir = M.bin_dir(root) })
  if report == nil then
    io.write("provision 失败: " .. tostring(err) .. "\n")
    return 1
  end

  io.write(string.format("APS 转发器根目录: %s\n", report.bin_dir))
  io.write(string.format("解释器: %s\n", report.lua_bin))
  io.write(string.format("rock: %s\n", tostring(rock.url)))
  io.write(string.format("重建 %d 件: %s\n", #report.written, table.concat(report.written, ", ")))
  io.write(string.format("保留 %d 件: %s\n", #report.unchanged, table.concat(report.unchanged, ", ")))
  return 0
end

if ... == "packages.acceptance.provision" then
  return M
end

os.exit(M.main(arg or {}))
