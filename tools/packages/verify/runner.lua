-- verify 车道的执行与输出聚合。
-- _build_output 是纯函数(results -> stdout/exit_code),verify_full_spec 直接拿它断言。
local number_utils = require("src.foundation.number")
local parallel_lanes = require("foundation.parallel_lanes")

local runner = {}

runner.PHASE_TIMEOUT = 600

-- 串行跑一步。输出回收、stdout/stderr 合流、退出码归一都由 foundation.proc 负责
-- (原生 Windows 单平台,ADR 0066:不再手拼 `> file 2>&1` 重定向);
-- 这里只把 ok/code 两路折成 verify 的 success 判据。
function runner.run_step(label, cmd)
  local started = os.time()
  local result = require("foundation.proc").run_command(cmd)
  local ok, code = result.ok, result.code
  local elapsed = math.max(0, os.time() - started)
  local success = ok == true and (code == nil or code == 0)
  if not success and number_utils.is_numeric(code) then
    success = code == 0
  end
  return { label = label, ok = success, elapsed = elapsed, output = result.output or "" }
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
  local all_ok = #results > 0 and #failed == 0

  local buf = {}
  for _, r in ipairs(results) do
    local show_this = verbose or not r.ok
    if not show_this then
      local counts = tostring(r.output or ""):match("# COUNTS: [^\r\n]+")
      if counts then buf[#buf + 1] = "[verify] " .. r.label .. " " .. counts .. "\n" end
    end
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
