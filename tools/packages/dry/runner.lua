local _self = debug.getinfo(1, "S").source or "@tools/packages/dry/runner.lua"
local _sb = dofile(_self:gsub("\\", "/"):gsub("^@", ""):match("^(.*)/[^/]+$")
  .. "/../../foundation/script_bootstrap.lua")
local bootstrap_env, bootstrap = _sb.install("tools/packages/dry", _self)

local is_module = ... == "packages.dry.runner"

-- #122:上游 dry4lua 的文件发现已改为纯 Lua,dry 在原生 Windows 上真实扫描,
-- 不再经平台边界。三种结局互相可辨:
--   * 有效结果:候选文件数 > 0,上游扫描并报告(退 0);
--   * 不可用:自举的网络/下载类失败(#112 口径),stderr status=unavailable 退 3;
--   * 真实失败:自举的其余失败、路径不存在、目标下零个 .lua 候选文件(退 1)。
-- 候选文件数写 stderr(candidate_files=N),不污染 --json 的 stdout;零候选不许
-- 退 0 —— 那正是旧形态的「空扫描假绿」。

local function _ensure_dry4lua()
  local ok, err, unavailable = bootstrap.ensure_tool("dry4lua", bootstrap_env)
  if unavailable ~= nil then
    local availability = require("foundation.tool_availability")
    return require("foundation.platform_boundary").emit(availability.verdict(unavailable, "dry"))
  end
  if not ok then
    io.stderr:write("[dry] " .. tostring(err) .. "\n")
    return 1
  end
  return nil
end

local function run(args)
  -- #122:兼容开关在本仓消费,漏给上游会被当成未知选项退 2。
  args = require("foundation.platform_boundary").strip_skip_flag(args)
  local failed = _ensure_dry4lua()
  if failed ~= nil then
    return failed
  end
  local cli = require("dry4lua.cli")
  local analysis = require("dry4lua.analysis")

  local options = cli.parse_args(args)
  if not options.help then
    local files, err = analysis.collect_files(options.paths)
    if files == nil then
      io.stderr:write("[dry] " .. tostring(err) .. "\n")
      return 1
    end
    io.stderr:write("[dry] candidate_files=" .. #files .. "\n")
    io.stderr:flush()
    if #files == 0 then
      io.stderr:write("[dry] 目标下没有 .lua 候选文件,本次未扫描任何函数;这不是「没有重复」。\n")
      return 1
    end
  end
  return cli.run(args)
end

-- 模块形态(#322):供 packages.dry.cli 经 foundation.tool_cli 进程内直调;
-- dry4lua.cli.run(args) 返回数字退出码,无 env 契约,env 形参接收后忽略。
if is_module then
  return { run = function(args) return run(args or {}) end }
end

for _, value in ipairs(arg or {}) do
  if value == "--help" or value == "-h" then
    io.write(require("packages.dry.cli").usage())
    os.exit(0)
  end
end
os.exit(run(arg or {}))
