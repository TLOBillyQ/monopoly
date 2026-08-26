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

function tap_summary.compress(output)
  local passed, failed = 0, 0
  local kept = {}
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^ok%s+%d") then
      passed = passed + 1
    elseif _is_not_ok(line) then
      failed = failed + 1
      kept[#kept + 1] = line
    elseif not line:match("^%d+%.%.%d+%s*$") then
      kept[#kept + 1] = line
    end
  end
  if failed == 0 then
    return string.format("%d passed\n", passed), passed, failed
  end
  kept[#kept + 1] = string.format("%d passed, %d failed", passed, failed)
  return table.concat(kept, "\n") .. "\n", passed, failed
end

return tap_summary
