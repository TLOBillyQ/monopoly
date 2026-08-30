-- packages/acceptance/aps_forwarders.lua —— APS PATH 三件转发器的「正文」真源(工单 #606)
--
-- 本模块只管一件事:给定解释器名,某个转发器的正文该长什么样。纯演算——不起子进程、
-- 不碰文件系统、不探测平台,因此正文可逐字节重放、可单测。
-- 「落到哪、什么时候写」在 packages.acceptance.provision(IO 壳);
-- 「落到哪个 SwarmForge 根」在 packages.acceptance.swarm_root。
--
-- 为什么单独立模块:这三份 bash→Lua 转发器是「下次启动可用」的载体(launcher 把
-- <swarm-root>/.swarmforge/bin 放 PATH 最前),正文里的每一行都是对外契约——
-- 入口路径、`set -e`、禁走 swarm_tool.sh ensure 的告示、以及 gherkin-mutator 的
-- 差分钳制。契约文本与写盘逻辑同住一个文件时,改落盘策略会顺手晃到契约;分开后
-- 二者各自只有一个变化原因。
local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")

local M = {}

-- 转发器落盘的仓内相对目录(绝对目标由调用方给出 swarm root)。
local _BIN_RELATIVE = ".swarmforge/bin"

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

-- 解释器字面量的「没给」判定:nil、空串、纯空白都算没给——后两者在 Lua 里是真值,
-- 不判就得到一条 `exec  "$root/..."` 或 `exec '   ' "$root/..."` 的坏转发器:可执行名
-- 打不开,但脚本退 0 之前不会有任何解释。正文兜底与 provision 的探测兜底共用这一处判定。
function M.is_blank_launcher(value)
  return tostring(value or ""):match("^%s*$") ~= nil
end

local function _normalize_lua_bin(lua_bin)
  if M.is_blank_launcher(lua_bin) then
    return "lua"
  end
  return tostring(lua_bin)
end

function M.tool(name)
  for _, tool in ipairs(M.TOOLS) do
    if tool.name == name then
      return tool
    end
  end
  return nil
end

-- 仓根由脚本自身位置反推、不烘绝对路径——转发器得随仓搬家;解释器相反,烘探测结果,
-- 因为它决定跑的是不是钉定的那份 Lua。
function M.forwarder_body(name, lua_bin)
  local tool = M.tool(name)
  if tool == nil then
    return nil
  end
  local bin = _normalize_lua_bin(lua_bin)

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
  lines[#lines + 1] = "exec " .. shell_lib.shell_quote(bin) .. exec_line
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

return M
