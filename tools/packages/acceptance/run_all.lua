-- 批量跑验收套件：逐个 spawn tools/packages/acceptance/generated/
-- 下的生成入口。
--
-- acceptance4lua 新架构的生成物是独立 lua 脚本(自带 harness、结尾 os.exit),
-- 不再是能挂进测试运行器的 spec——spec_profiles 的 acceptance profile 已随之
-- 退役,本脚本是 `lua tools/cli.lua acceptance` 的执行半(regenerate 负责生成,这里负责跑)。
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local acceptance_tool = assert(bootstrap.ensure_tool("acceptance4lua", env))

local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")
local parallel_lanes = require("foundation.parallel_lanes")
local sharding = require("packages.luaunit_runner.spec_sharding")
local source = assert(package.searchpath("acceptance4lua.runner", package.path))
assert(source:gsub("\\", "/"):find(acceptance_tool.root .. "/", 1, true),
  "acceptance4lua must load from project tree: " .. source)
local runner = require("acceptance4lua.runner")
local spawn_env = require("packages.acceptance.spawn_env")
local registry = require("packages.acceptance.acceptance_features")

local run_all = {}

-- 并行 worker 数:ACCEPTANCE_WORKERS 环境变量覆写,默认 4。每个 entry 是独立
-- lua 子进程(纯本地内存仿真,无端口/日志/真机/共享文件状态;唯一写文件 step
-- 落 tmp/acceptance_mutator_status_<唯一token>/ 天然隔离),串行瓶颈几乎全在
-- 解释器冷启,并行后 wall 由最慢 entry 决定而非逐个累加。注意一次全提交全部
-- lanes:按 worker 数分批反而慢(本机实测 34 entry 串行 ~6.5s -> 分批 ~6.4s,
-- 批间串行 + parallel_lanes 轮询粒度吃光并行收益;全提交 ~3.4s,墙 6.5s ->
-- 3.4s)。workers ≤ 1 退回逐个 spawn 的严格串行路径(与原实现逐字节等价)。
local _DEFAULT_ACCEPTANCE_WORKERS = 4

local function _resolve_workers(entry_count)
  return sharding.resolve_workers("ACCEPTANCE_WORKERS", entry_count, _DEFAULT_ACCEPTANCE_WORKERS)
end

-- 单 entry 结果映射:还原 runner.run_generated 的返回契约(passed 按 exit code,
-- error 仅基础设施错误非空)。parallel_lanes 的结果只有 ok/exit_code/output。
local function _map_result(r)
  local output = tostring(r.output or "")
  local error = ""
  if runner.is_infrastructure_error(r.exit_code, output) then
    error = output ~= "" and output or ("lua launcher failed with exit code " .. tostring(r.exit_code))
  end
  return { passed = r.ok == true, output = output, error = error }
end

-- 原生的生成入口 spawn:上游 runner.build_command 产出 POSIX `LUA_PATH=.. lua` 前缀,
-- 在 cmd.exe 下不是合法命令,故这里以同一 cwd/LUA_PATH/退出码契约自行表达,再经
-- _map_result 映射回 run_generated 的结果面(错误映射只有 _map_result 一份)。
local function _run_generated_native(path, base_opts)
  local command = 'set "LUA_PATH=' .. base_opts.lua_path .. '" && '
    .. shell_lib.build_command({ base_opts.lua_bin, path })
  local native = require("foundation.proc").run_command(command, { cwd = base_opts.cwd })
  return _map_result({ ok = native.ok, exit_code = native.code, output = native.output })
end

-- 跑全部注册 feature 的生成入口,返回 { passed = n, failed = { {name, output, error} }, total = n }。
-- options.generated_dir 可覆盖注册表默认(测试用隔离目录)。
function run_all.run(options)
  options = options or {}
  local generated_dir = options.generated_dir or registry.generated_dir
  local base_opts = spawn_env.runner_opts(env, acceptance_tool)
  base_opts.cwd = env.repo_root

  local entries = registry.entries

  -- workers ≤ 1:严格串行回退(不依赖并行调度,行为与原逐个 spawn 等价)。
  if options.serial or _resolve_workers(#entries) <= 1 then
    local passed = 0
    local failed = {}
    local cases, case_passed, case_failed = 0, 0, 0
    for _, entry in ipairs(entries) do
      local path = path_lib.join_path(generated_dir, entry.generated)
      local result = _run_generated_native(path, base_opts)
      local good, bad = result.output:match("(%d+) passed, (%d+) failed")
      good = tonumber(good) or tonumber(result.output:match("(%d+) passed")) or 0
      bad = tonumber(bad) or 0
      cases, case_passed, case_failed = cases + good + bad, case_passed + good, case_failed + bad
      io.write(string.format("[acceptance] counts %s cases=%d passed=%d failed=%d\n",
        entry.generated, good + bad, good, bad))
      -- 零用例不是通过;但基础设施错误的诊断(runner 契约:error 非空)优先,
      -- 否则 127/launcher 静默退出会被 "no acceptance cases executed" 掩盖。
      if good + bad == 0 then
        result.passed = false
        if result.error == "" then result.error = "no acceptance cases executed" end
      end
      if result.passed == true and result.error == "" then
        passed = passed + 1
        io.write("[acceptance] ok ", entry.generated, "\n")
      else
        failed[#failed + 1] = {
          name = entry.generated,
          output = result.output or "",
          error = result.error or "",
        }
        io.write("[acceptance] FAILED ", entry.generated, "\n")
      end
      io.flush()
    end
    io.write(string.format("[acceptance] COUNTS: files=%d cases=%d passed=%d failed=%d\n",
      #entries, cases, case_passed, case_failed))
    return { passed = passed, failed = failed, total = #entries }
  end

  -- 原生并行命令与串行共享 cwd/LUA_PATH,按注册顺序汇总。
  local lanes = {}
  for index, entry in ipairs(entries) do
    local path = path_lib.join_path(generated_dir, entry.generated)
    lanes[index] = {
      label = "acceptance_" .. tostring(index),
      cmd = shell_lib.wrap_command_with_cwd('set "LUA_PATH=' .. base_opts.lua_path .. '" && '
        .. shell_lib.build_command({ base_opts.lua_bin, path }), base_opts.cwd),
    }
  end

  local _, results = parallel_lanes.run(lanes, { stream = false })

  -- results 按提交顺序(lanes 顺序)对齐,即 registry 顺序,直接按序输出。
  local passed = 0
  local failed = {}
  local cases, case_passed, case_failed = 0, 0, 0
  for index, entry in ipairs(entries) do
    local result = _map_result(results[index])
    local good, bad = result.output:match("(%d+) passed, (%d+) failed")
    good = tonumber(good) or tonumber(result.output:match("(%d+) passed")) or 0
    bad = tonumber(bad) or 0
    cases, case_passed, case_failed = cases + good + bad, case_passed + good, case_failed + bad
    io.write(string.format("[acceptance] counts %s cases=%d passed=%d failed=%d\n", entry.generated, good + bad, good, bad))
    if good + bad == 0 then
      result.passed = false
      if result.error == "" then result.error = results[index].message or "no acceptance cases executed" end
    end
    if result.passed == true and result.error == "" then
      passed = passed + 1
      io.write("[acceptance] ok ", entry.generated, "\n")
    else
      failed[#failed + 1] = {
        name = entry.generated,
        output = result.output,
        error = result.error,
      }
      io.write("[acceptance] FAILED ", entry.generated, "\n")
    end
  end
  io.write(string.format("[acceptance] COUNTS: files=%d cases=%d passed=%d failed=%d\n", #entries, cases, case_passed, case_failed))
  io.flush()
  return { passed = passed, failed = failed, total = #entries }
end

function run_all.main()
  local options = { serial = true }
  for _, token in ipairs(arg or {}) do
    if token == "--serial" then options.serial = true
    elseif token == "--parallel" then options.serial = false
    else io.stderr:write("unknown option: " .. token .. "\n"); return 2 end
  end
  local summary = run_all.run(options)
  for _, failure in ipairs(summary.failed) do
    io.stderr:write("---- ", failure.name, " ----\n")
    local detail = failure.error ~= "" and failure.error or failure.output
    io.stderr:write(tostring(detail), "\n")
  end
  io.write(string.format(
    "acceptance: %d/%d specs passed\n", summary.passed, summary.total
  ))
  if summary.total == 0 or #summary.failed > 0 or summary.passed ~= summary.total then
    return 1
  end
  return 0
end

if arg ~= nil and tostring(arg[0] or ""):match("tools/packages/acceptance/run_all%.lua$") then
  os.exit(run_all.main())
end

return run_all
