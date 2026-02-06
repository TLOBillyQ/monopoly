local runner = {}

local scenario_files = {
  "scenarios/turn_movement.lua",
  "scenarios/land_rent.lua",
  "scenarios/items.lua",
  "scenarios/chance_market_match.lua",
  "scenarios/reconnect_snapshot.lua",
  "scenarios/presentation_architecture.lua",
}

local function _load_cases(path)
  local ok, cases = pcall(dofile, path)
  if not ok then
    error("加载场景失败: " .. tostring(path) .. "\n" .. tostring(cases))
  end
  if type(cases) ~= "table" then
    error("场景文件必须返回 table: " .. tostring(path))
  end
  return cases
end

local function _collect_cases()
  local out = {}
  for _, rel in ipairs(scenario_files) do
    local path = ".agents/tests/v2/" .. rel
    local list = _load_cases(path)
    for _, case in ipairs(list) do
      out[#out + 1] = case
    end
  end
  return out
end

function runner.run(label)
  local cases = _collect_cases()
  if #cases < 36 then
    error("V2 回归场景不足 36，当前: " .. tostring(#cases))
  end

  for _, case in ipairs(cases) do
    local ok, err = xpcall(case.run, debug.traceback)
    if not ok then
      io.stdout:write("\n[FAIL] " .. tostring(case.name) .. "\n")
      io.stdout:write(tostring(err) .. "\n")
      error("V2 回归失败: " .. tostring(case.name))
    end
    io.stdout:write(".")
  end
  io.stdout:write("\n")
  print((label or "V2 regression") .. " passed (" .. tostring(#cases) .. ")")
  return #cases
end

return runner
