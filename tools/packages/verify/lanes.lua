-- verify 的车道规划:按 opts(tooling / coverage / crap / full)
-- 决定跑哪些车道、跳过哪些、给出哪些警告。
--
-- 纯函数:环境探测的结果由调用方通过 opts.env 注入(lua54_bin / coverage_available),
-- 这里不自己探测,所以 verify_full_spec 能把任意 env 喂进来断言。
-- luacheck 不再走"PATH 上有没有"的探测——lint 车道按需把它装进项目 tree 后经
-- 钉定 5.4 解释器调用。
-- 车道表本身在 lane_builders,这里只决定走哪张、以及据 skipped 补哪些警告。
local builders = require("packages.verify.lane_builders")

local lanes_mod = {}

local function _has(set, label)
  for _, v in ipairs(set or {}) do
    if v == label then return true end
  end
  return false
end

function lanes_mod.resolve(opts)
  opts = opts or {}
  local env = opts.env or {}
  local warnings = {}
  local include_coverage = opts.coverage == true
  local include_crap = opts.crap == true
  if opts.full == true then
    include_coverage = true
    include_crap = true
  end
  local lanes, skipped = builders.default(env, opts.tooling == true, include_coverage, include_crap, opts.serial == true)
  if include_coverage and _has(skipped, "coverage") then
    warnings[#warnings + 1] = "--coverage requested but coverage toolchain is unavailable"
  end
  return { lanes = lanes, skipped = skipped, warnings = warnings }
end

function lanes_mod.have(lanes, label)
  for _, lane in ipairs(lanes) do
    if lane.label == label then return true end
  end
  return false
end

return lanes_mod
