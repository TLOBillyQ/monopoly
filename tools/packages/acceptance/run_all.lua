-- 批量跑验收套件：逐个 spawn tools/packages/acceptance/generated/
-- 下的生成入口。
--
-- acceptance4lua 新架构的生成物是独立 lua 脚本(自带 harness、结尾 os.exit),
-- 不再是能挂进测试运行器的 spec——spec_profiles 的 acceptance profile 已随之
-- 退役,本脚本是 `lua tools/cli.lua acceptance` 的执行半(regenerate 负责生成,这里负责跑)。
local bootstrap = dofile((debug.getinfo(1, "S").source:gsub("^@", "")):match("^(.*)/[^/]+$") .. "/../../foundation/bootstrap.lua")
local env = bootstrap.install(debug.getinfo(1, "S").source)
local acceptance_tool = assert(bootstrap.ensure_tool("acceptance4lua", env))

local path_lib = require("foundation.path")
local shell_lib = require("foundation.shell")
local parallel_lanes = require("foundation.parallel_lanes")
local sharding = require("packages.luaunit_runner.spec_sharding")
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

-- 跑全部注册 feature 的生成入口,返回 { passed = n, failed = { {name, output, error} }, total = n }。
-- options.generated_dir 可覆盖注册表默认(测试用隔离目录)。
function run_all.run(options)
  options = options or {}
  local generated_dir = options.generated_dir or registry.generated_dir
  local base_opts = spawn_env.runner_opts(env, acceptance_tool)
  base_opts.cwd = env.repo_root

  local entries = registry.entries

  -- workers ≤ 1:严格串行回退(不依赖并行调度,行为与原逐个 spawn 等价)。
  if _resolve_workers(#entries) <= 1 then
    local passed = 0
    local failed = {}
    for _, entry in ipairs(entries) do
      local path = path_lib.join_path(generated_dir, entry.generated)
      local result = runner.run_generated(path, base_opts)
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
    return { passed = passed, failed = failed, total = #entries }
  end

  -- 并行路径:每 entry 一条 lane(label 唯一,acceptance_1..N),stream=false
  -- 收集。lane 命令复用 runner.build_command(LUA_PATH 前缀 + lua_bin + 生成
  -- 脚本);cwd 语义与原 run_generated 的 opts.cwd 一致——parallel_lanes 的
  -- launcher 只 cd 到自身 cwd,这里显式 cd 进 repo_root,生成脚本内相对路径
  -- (如 tmp/acceptance_mutator_status_<token>)依赖它。
  local lanes = {}
  for index, entry in ipairs(entries) do
    local path = path_lib.join_path(generated_dir, entry.generated)
    lanes[index] = {
      label = "acceptance_" .. tostring(index),
      cmd = shell_lib.wrap_command_with_cwd(runner.build_command(path, base_opts), base_opts.cwd),
    }
  end

  local _, results = parallel_lanes.run(lanes, { stream = false })

  -- results 按提交顺序(lanes 顺序)对齐,即 registry 顺序,直接按序输出。
  local passed = 0
  local failed = {}
  for index, entry in ipairs(entries) do
    local result = _map_result(results[index])
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
  io.flush()
  return { passed = passed, failed = failed, total = #entries }
end

function run_all.main()
  local summary = run_all.run({})
  for _, failure in ipairs(summary.failed) do
    io.stderr:write("---- ", failure.name, " ----\n")
    local detail = failure.error ~= "" and failure.error or failure.output
    io.stderr:write(tostring(detail), "\n")
  end
  io.write(string.format(
    "acceptance: %d/%d specs passed\n", summary.passed, summary.total
  ))
  if #summary.failed > 0 or summary.passed ~= summary.total then
    return 1
  end
  return 0
end

if arg ~= nil and tostring(arg[0] or ""):match("tools/packages/acceptance/run_all%.lua$") then
  os.exit(run_all.main())
end

return run_all
