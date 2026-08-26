-- packages/clean/cli.lua —— clean / distclean 子命令(吸收原 Makefile clean 面;
-- Makefile/project.mk 退役,清理语义原样搬家,清单与生产者一一对应关系不变)。
--
-- 统一接口形态(#300 决议):本文件 return 纯接口模块:
--   M.main(args, env) -> 退出码(0 成功 / 1 业务失败 / 2 用法错误)
--   M.usage()         -> 完整 usage 文本(包内单一真源,顶层 <cmd> --help 转发)
--
-- 路由约定:clean 与 distclean 两个子命令都路由到本包,经 env.action
-- ("clean" / "distclean")分流(顶层 cli.lua 按 commands 表条目注入)。
--
-- 清单与生产者对应：build/ tmp/ .arch_view/viewer/ 为本地
-- 构建/扫描产物;tools/packages/acceptance/generated/ 由 acceptance regenerate
-- 生成;junit-output.xml 由 spec_lane 生成;luacov.* 由 coverage 车道生成。
-- clean 不清 .toolcache/、不动 .swarmforge/(distclean 才连缓存一起清)。
--
-- 实现:开发环境限 macOS + WSL(#127),直接 sh -c rm,语义与被取代的
-- Makefile 逐字一致(rm -rf 目录、rm -f 文件/glob,sh 下未命中 glob 原样
-- 传给 rm -f 静默忽略)。
local M = {}

local proc = require("foundation.proc")

local _CLEAN_DIRS = { "build/", "tmp/", ".arch_view/viewer/", "tools/packages/acceptance/generated/" }
local _CLEAN_FILES = {
  "junit-output.xml",
  "luacov.*.stats.out",
  "luacov.*.report.out",
  "luacov.stats.out",
  "luacov.report.out",
}
local _DISTCLEAN_DIRS = { ".toolcache/", ".swarmforge/" }

function M.usage()
  return table.concat({
    "用法: lua tools/cli.lua clean | distclean",
    "",
    "clean     清生成物:build/ tmp/ .arch_view/viewer/ acceptance generated/、",
    "          junit-output.xml、luacov 残留。不动 .toolcache/ 与 .swarmforge/。",
    "distclean clean 之上再清 .toolcache/ 与 .swarmforge/(缓存与 swarm 运行时状态)。",
    "",
  }, "\n") .. "\n"
end

local function _run(command, repo_root)
  local result = proc.run_command(command, { cwd = repo_root })
  if not result.ok then
    io.stderr:write("clean 失败(exit " .. tostring(result.code) .. "): " .. command .. "\n")
    if result.output ~= "" then
      io.stderr:write(result.output .. "\n")
    end
    return false
  end
  return true
end

function M.main(args, env)
  local first = (args or {})[1]
  if first == "--help" or first == "-h" then
    io.write(M.usage())
    return 0
  end
  if first ~= nil then
    io.stderr:write("未知参数: " .. tostring(first) .. "\n\n" .. M.usage())
    return 2
  end

  local repo_root = (env and env.repo_root) or "."
  local dirs = { table.unpack(_CLEAN_DIRS) }
  if env and env.action == "distclean" then
    for _, dir in ipairs(_DISTCLEAN_DIRS) do
      dirs[#dirs + 1] = dir
    end
  end

  if not _run("rm -rf " .. table.concat(dirs, " "), repo_root) then
    return 1
  end
  if not _run("rm -f " .. table.concat(_CLEAN_FILES, " "), repo_root) then
    return 1
  end
  return 0
end

return M
