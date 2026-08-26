-- verify 车道的执行与输出聚合。
-- _build_output 是纯函数(results -> stdout/exit_code),verify_full_spec 直接拿它断言。
local env_lib = require("foundation.env")
local fs_lib = require("foundation.fs")
local shell_lib = require("foundation.shell")
local number_utils = require("src.foundation.number")
local parallel_lanes = require("foundation.parallel_lanes")

local runner = {}

runner.PHASE_TIMEOUT = 600

-- 串行跑一步,输出重定向到临时文件后回收。os.execute 在不同 Lua/平台上对退出码的
-- 表达不一致,所以 ok 与 code 两路都判。
function runner.run_step(label, cmd)
  local paths = {
    output = env_lib.make_temp_path("vf_step_" .. label .. "_out", ".txt"),
  }
  local redirected = cmd .. " > " .. shell_lib.shell_quote(paths.output) .. " 2>&1"
  local started = os.time()
  local ok, _, code = os.execute(redirected)
  local elapsed = math.max(0, os.time() - started)
  local success = ok == true and (code == nil or code == 0)
  if not success and number_utils.is_numeric(code) then
    success = code == 0
  end
  local output = fs_lib.read_file(paths.output) or ""
  fs_lib.remove_path(paths.output)
  return { label = label, ok = success, elapsed = elapsed, output = output }
end

-- 启动 + 调度 + 输出聚合委托给 foundation.parallel_lanes（曾经在这里复制粘贴一份）。
-- stream=false 维持 architect 的"收集后选择性 emit"模型：success 路径压缩、
-- failure/verbose 路径全量打印，由下游 build_output 处理。
function runner.run_parallel(lanes)
  local started = os.time()
  local all_ok, lane_results = parallel_lanes.run(lanes, {
    stream = false,
    timeout = runner.PHASE_TIMEOUT,
  })
  local elapsed = math.max(0, os.time() - started)

  local results = {}
  for index, lane in ipairs(lane_results) do
    results[index] = {
      label = lane.label,
      ok = lane.ok,
      elapsed = nil,
      output = lane.output or "",
    }
  end
  return all_ok, results, elapsed
end

-- 成功车道默认压缩成一行;失败或 verbose 才把车道输出全量摊开。
function runner.build_output(input)
  input = input or {}
  local results = input.results or {}
  local skipped = input.skipped or {}
  local total_elapsed = input.total_elapsed or 0
  local verbose = input.verbose == true

  local passed, failed = {}, {}
  for _, r in ipairs(results) do
    if r.ok then
      passed[#passed + 1] = r.label
    else
      failed[#failed + 1] = r.label
    end
  end
  local all_ok = #failed == 0

  local buf = {}
  for _, r in ipairs(results) do
    local show_this = verbose or not r.ok
    if show_this then
      buf[#buf + 1] = string.format(
        "[verify] %s %s  %ds\n",
        r.ok and "PASS" or "FAIL", r.label, r.elapsed or 0
      )
      if r.output and r.output ~= "" then
        buf[#buf + 1] = r.output
        if r.output:sub(-1) ~= "\n" then
          buf[#buf + 1] = "\n"
        end
      end
    end
  end

  buf[#buf + 1] = string.format(
    "\n[verify] %s  passed=%d failed=%d skipped=%d  %ds\n",
    all_ok and "PASS" or "FAIL",
    #passed, #failed, #skipped, total_elapsed
  )
  if #skipped > 0 then
    buf[#buf + 1] = "[verify] skipped: " .. table.concat(skipped, ", ") .. "\n"
  end

  return {
    stdout = table.concat(buf),
    exit_code = all_ok and 0 or 1,
    passed = passed,
    failed = failed,
    skipped = skipped,
  }
end

return runner
