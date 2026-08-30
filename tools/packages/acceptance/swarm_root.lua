-- packages/acceptance/swarm_root.lua —— SwarmForge 项目根的解析(工单 #606)
--
-- 「SwarmForge 项目根」= 持 `.swarmforge/roles.tsv` 的目录:launcher 从那里把
-- `.swarmforge/bin` 放 PATH 最前,`swarm_tool.sh` 也按同一口径解析。APS 转发器与
-- luarocks tree 都必须落在这一个根上,否则 provision 与 probe 各说各话。
--
-- 候选演算(swarm_root_candidates / select_swarm_root)是纯函数:cwd 与 git 两问的
-- 结果由调用方喂进来,不在此起进程;只有 resolve() 是 IO 壳。
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local path_lib = require("foundation.path")
local proc_lib = require("foundation.proc")

local M = {}

local _ROLES_MARKER = ".swarmforge/roles.tsv"

-- 候选根顺序:先 git --git-common-dir 的父目录(worktree 共享的项目根),再本 worktree
-- 顶,再 cwd。相对 common dir 以 cwd 解析。
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
function M.resolve()
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

return M
