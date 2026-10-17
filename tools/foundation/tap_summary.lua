local tap_summary = {}

-- TAP 的 `not ok` 行不保证带编号:runner 在 spec 加载失败时发的是无编号的
-- `not ok - failed to load ...`。若只认 `^not ok%s+%d`,这类行会掉进下面的
-- 「保留」分支而 failed 不计数,于是 failed == 0 提前 return,kept 被整个丢弃
-- —— 摘要显示「N passed」,失败行凭空消失(工单 #135)。
-- 用 %f[%s%z] 前沿匹配「not ok」后面必须是空白或行尾,既收编号行也收无编号行,
-- 又不会误吃 `not okay...` 这类前缀。
local function _is_not_ok(line)
  return line:match("^not ok%f[%s%z]") ~= nil
end

-- TAP 行计数的唯一真源(#135/#130):spec_lane 的摘要与证据交叉核对共用这里,
-- 无编号 not ok 的口径不能在两个模块各自复制后漂移。
function tap_summary.tally(output)
  local tally = { passed = 0, failed = 0 }
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^ok%s+%d") then
      tally.passed = tally.passed + 1
    elseif _is_not_ok(line) then
      tally.failed = tally.failed + 1
    end
  end
  return tally
end

-- authoritative(#130):runner 进程内 COUNTS 折算的 { passed=, failed= }。stdout/stderr
-- 合流会把 TAP 行从中间切开,ok 行计数可能少于真实通过数;给了权威值就让摘要数字以它
-- 为准,但失败判定取两侧并集:TAP 有 not ok 或 COUNTS 有失败都不能压成全绿。
function tap_summary.compress(output, authoritative)
  local tally = tap_summary.tally(output)
  local passed, failed = tally.passed, tally.failed
  local kept = {}
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if _is_not_ok(line) then
      kept[#kept + 1] = line
    elseif not line:match("^ok%s+%d") and not line:match("^%d+%.%.%d+%s*$") then
      kept[#kept + 1] = line
    end
  end
  local total_passed = authoritative and authoritative.passed or passed
  local total_failed = authoritative and math.max(authoritative.failed, failed) or failed
  if total_failed == 0 then
    local diagnostics = {}
    for _, line in ipairs(kept) do
      if line:match("^# BASELINE LEAK:") or line:match("^# EXCLUDED:")
          or line:match("^# COUNTS:") and not line:match("errors=0%s*$") then
        diagnostics[#diagnostics + 1] = line
      end
    end
    diagnostics[#diagnostics + 1] = string.format("%d passed", total_passed)
    return table.concat(diagnostics, "\n") .. "\n", passed, failed
  end
  kept[#kept + 1] = string.format("%d passed, %d failed", total_passed, total_failed)
  return table.concat(kept, "\n") .. "\n", passed, failed
end

return tap_summary
