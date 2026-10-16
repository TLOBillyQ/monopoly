-- platform_boundary.lua —— 平台保证边界的唯一真源(#96 / 母规格 #69 / ADR 0066)。
--
-- 背景:ADR 0066 把开发平台收窄为原生 Windows,但 acceptance-mutate(中文验收变异)
-- 这件保留能力当前仍按 POSIX 专用能力声明(dry 已于 #122 移植,撤出本表)。
-- 收窄之后它们的失败形态从「红」变成「假绿」——上游链路在 cmd.exe 上扫不到候选、
-- 读不到 job,却照旧退 0 报「没有重复」/退 1 报一条不相干的探针误诊。把它留给
-- 各 CLI 自己判断「平台行不行」,就会分叉出四份口径(两个包 × CLI 形态/脚本形态),
-- 于是本模块是这份声明的唯一出处。
--
-- 三态必须互相可辨(工单验收):不可用 / 显式跳过 / 真实失败。
--   * 不可用:本平台不在能力的保证面内 → stderr 诊断 + 退出码 3,不安装、不 spawn、
--     不报通过;
--   * 显式跳过:调用方加 --skip-if-unavailable 确认边界 → stdout 诊断 + 退出码 0,
--     状态词 status=skipped,同样不冒充跑过;
--   * 真实失败:平台在保证面内 → 本模块不下判定(evaluate 返回只有 args 的表),
--     由真实工具自己的输出与退出码说话(1 业务失败 / 2 用法错误)。
--
-- 边界是「声明」而不是运行时探测:探测「这台机器上有没有 POSIX shell」会把
-- Git Bash 之类非受支持前提重新变成隐式依赖(ADR 0066 明文否掉),声明则让
-- 「在原生 Windows 上不可用」成为可断言的显式事实。
--
-- 纯演算砖:不落盘、不起进程。evaluate 只分类,写终端由 emit 一处收口
-- (四个调用点各自挑 stdout/stderr 会分叉出四份流选择规则)。

local boundary = {}

boundary.WINDOWS = "windows"
boundary.POSIX = "posix"

-- 状态词会出现在诊断文本里(可机读)与测试断言里,不要改字面量。
boundary.UNAVAILABLE = "unavailable"
boundary.SKIPPED = "skipped"

-- 显式跳过开关。由本模块消费:漏给上游会被当成未知选项退 2,把平台边界
-- 伪装成用法错误。
boundary.SKIP_FLAG = "--skip-if-unavailable"

-- 退出码约定扩展(#300 Q2 → #96):0 成功 / 1 业务失败 / 2 用法错误 / 3 不可用。
-- 必须是新码,否则调用方分不清「工具没跑」与「工具跑了但失败」。
boundary.UNAVAILABLE_EXIT_CODE = 3
boundary.SKIPPED_EXIT_CODE = 0

-- 声明的 POSIX 专用能力表。reason 是取证过的机制,不是泛泛的「不支持」。
local _DECLARED = {
  ["acceptance-mutate"] = {
    id = "acceptance-mutate",
    title = "中文验收变异(acceptance4lua mutator)",
    reason = table.concat({
      "车道健康探针链(parser → generator → runner_worker)在原生 Windows 上,",
      "自举期的子进程会把进程 stdin 抽干,runner_worker 的 io.lines() 读不到任何 job,",
      "车道只会回报一条「探针读不到 job」的假诊断 —— 把基础设施故障说成变异结论。",
    }),
  },
}

-- 宿主平台。package.config 首字符是路径分隔符(Windows "\\" / POSIX "/"),
-- 只用 Lua 标准库判定,不依赖 sh / uname / 环境变量。
function boundary.host_platform()
  if package.config:sub(1, 1) == "/" then
    return boundary.POSIX
  end
  return boundary.WINDOWS
end

-- 已声明能力 id 清单(排序,供未登记 id 的报错文案与文档对账)。
function boundary.declared_ids()
  local ids = {}
  for id in pairs(_DECLARED) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  return ids
end

local function _strip_skip_flag(args)
  local argv, skip = {}, false
  for _, value in ipairs(args or {}) do
    if value == boundary.SKIP_FLAG then
      skip = true
    else
      argv[#argv + 1] = value
    end
  end
  return argv, skip
end

-- 不可用诊断的唯一渲染:首行 `[tag] status=unavailable<fields>`,其余每行带同一前缀。
-- 平台声明与工具自举(#112)共用,两处不再各写一份格式。
local function _unavailable_text(tag, fields, lines)
  local prefix = "[" .. tostring(tag) .. "] "
  local out = { prefix .. "status=" .. boundary.UNAVAILABLE .. (fields or "") }
  for _, line in ipairs(lines) do
    out[#out + 1] = prefix .. line
  end
  out[#out + 1] = ""
  return table.concat(out, "\n")
end

-- 不可用判定(stderr + 退 3),交 emit 写出。fields 是首行状态词后的可机读字段
-- (如 " tool=luacheck step=install"),lines 是不带前缀的诊断正文。
function boundary.unavailable_verdict(tag, fields, lines)
  return {
    status = boundary.UNAVAILABLE,
    exit_code = boundary.UNAVAILABLE_EXIT_CODE,
    stream = "stderr",
    message = _unavailable_text(tag, fields, lines),
  }
end

local function _declared_unavailable_lines(entry)
  return {
    "「" .. entry.title .. "」当前按 POSIX 专用能力声明,原生 Windows 不在保证面内(#96 / ADR 0066)。",
    "原因: " .. entry.reason,
    "本次未安装工具、未运行、未报通过;这个退出码不是检测结论。",
    "确认边界后要显式跳过,加 " .. boundary.SKIP_FLAG
      .. "(退出码 " .. boundary.SKIPPED_EXIT_CODE .. ",状态 status=" .. boundary.SKIPPED .. ")。",
  }
end

local function _skipped_text(entry)
  local tag = "[" .. entry.id .. "] "
  return table.concat({
    tag .. "status=" .. boundary.SKIPPED,
    tag .. "调用方以 " .. boundary.SKIP_FLAG .. " 显式确认了「" .. entry.title
      .. "」的 POSIX 专用边界:未安装、未运行。",
    tag .. "跳过不等于通过 —— 该能力在当前平台上仍然没有结果。",
    "",
  }, "\n")
end

-- 分类一次请求。返回表:
--   平台在保证面内 → { args = <剥掉跳过开关后的 argv> }(status/exit_code 为 nil,
--                     调用方继续走真实工具路径);
--   不可用         → { status, exit_code, stream, message, entry };
--   显式跳过       → { status, exit_code, stream, message, entry }。
-- platform 显式注入只为单测(纯函数可喂合成平台);生产调用不传,取 host_platform()。
function boundary.evaluate(id, args, platform)
  local entry = _DECLARED[id]
  assert(entry ~= nil,
    "platform_boundary: 未登记的能力 id " .. tostring(id)
      .. "(已登记: " .. table.concat(boundary.declared_ids(), ", ") .. ")")

  local argv, skip = _strip_skip_flag(args)
  local host = platform or boundary.host_platform()
  if host ~= boundary.WINDOWS then
    return { args = argv }
  end

  if skip then
    return {
      args = argv,
      entry = entry,
      status = boundary.SKIPPED,
      exit_code = boundary.SKIPPED_EXIT_CODE,
      stream = "stdout",
      message = _skipped_text(entry),
    }
  end

  local verdict = boundary.unavailable_verdict(entry.id, nil, _declared_unavailable_lines(entry))
  verdict.args = argv
  verdict.entry = entry
  return verdict
end

-- Retained actual engine regressions are explicit capability tests, not native gates.
boundary.test_capabilities = {
  ["tools/packages/acceptance_mutate/test/test_mutator_level.lua"] = "acceptance-mutate",
  ["tools/packages/acceptance_mutate/test/test_mutator_status.lua"] = "acceptance-mutate",
}

function boundary.test_verdict(path)
  local normalized = tostring(path):gsub("\\", "/")
  for identity, capability in pairs(boundary.test_capabilities) do
    if normalized == identity or normalized:sub(-#identity - 1) == "/" .. identity then
      local verdict = boundary.evaluate(capability, {})
      if verdict.status then
        verdict.identity = identity
        verdict.cases = identity:match("test_mutator_level%.lua$") and 12 or 2
        return verdict
      end
    end
  end
end

-- 写诊断。stream 由 evaluate 给定,调用点不再各自挑输出流。
function boundary.emit(verdict)
  local stream = verdict.stream == "stderr" and io.stderr or io.stdout
  stream:write(verdict.message)
  stream:flush()
  return verdict.exit_code
end

return boundary
