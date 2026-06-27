local tap_summary = {}

function tap_summary.compress(output)
  local passed, failed = 0, 0
  local kept = {}
  for line in (tostring(output or "") .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^ok%s+%d") then
      passed = passed + 1
    elseif line:match("^not ok%s+%d") then
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
