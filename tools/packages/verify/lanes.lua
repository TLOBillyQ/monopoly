-- verify 的车道规划:按 opts(tooling / serial)决定跑哪些车道、跳过哪些、
-- 给出哪些警告。
--
-- 纯函数:环境探测的结果由调用方通过 opts.env 注入(lua54_bin),
-- 这里不自己探测,所以 verify_full_spec 能把任意 env 喂进来断言。
-- luacheck 不再走"PATH 上有没有"的探测——lint 车道按需把它装进项目 tree 后经
-- 钉定 5.4 解释器调用。
-- 车道表本身在 lane_builders,这里只决定走哪张。
local builders = require("packages.verify.lane_builders")

local lanes_mod = {}

function lanes_mod.resolve(opts)
  opts = opts or {}
  local env = opts.env or {}
  local lanes, skipped = builders.default(env, opts.tooling == true, opts.serial == true, opts.evidence_dir)
  return { lanes = lanes, skipped = skipped, warnings = {} }
end

return lanes_mod
