local bootstrap = require("spec.bootstrap")
local catalog = require("tools.quality.shared.test_catalog")
local harness = require("tools.quality.shared.test_harness")
local load_coverage = require("tools.quality.crap.load_coverage")

bootstrap.install_package_paths()

local adapter = {}

-- resolve_suites 加载行为 spec 时执行的 src 行（模块主块、函数定义行）。
-- 上游覆盖 hook 只包住用例执行，这段加载期执行必须在这里记录、
-- 并在 adapter.run 里于 hook 生效后重放（见 crap/load_coverage.lua）。
adapter._pending_load_hits = nil

-- 工具链自身的 require 链会预载 src.foundation.* 纯工具模块（如 number），
-- 这些模块的加载发生在记录 hook 装上之前，spec 加载时的 require 命中缓存、
-- 不再执行，加载期行就永远计不进去。purge 后由 spec 加载在 hook 下重新
-- require。foundation 层按架构契约无状态、无加载副作用，重载安全；
-- 工具侧持有的旧实例引用继续有效。
local function _purge_preloaded_foundation_modules()
  for key in pairs(package.loaded) do
    if type(key) == "string" and key:find("^src%.foundation%.") ~= nil then
      package.loaded[key] = nil
    end
  end
end

function adapter.resolve_suites(lane)
  if lane == "behavior" then
    _purge_preloaded_foundation_modules()
    local suites
    adapter._pending_load_hits = load_coverage.record(function()
      suites = catalog.load_behavior_suites()
    end)
    return suites
  end
  if lane == "contract" then
    return catalog.load_contract_suites()
  end
  error("unsupported lane for CRAP coverage: " .. tostring(lane))
end

function adapter.run(suites, opts)
  local run_opts = opts or {}
  local load_hits = adapter._pending_load_hits
  adapter._pending_load_hits = nil
  if load_hits ~= nil
    and type(run_opts.before_case) == "function"
    and type(run_opts.after_case) == "function" then
    run_opts.before_case()
    local ok, err = xpcall(function()
      load_coverage.replay(load_hits)
    end, debug.traceback)
    run_opts.after_case()
    if not ok then
      error(err, 0)
    end
  end
  return harness.run_all(suites, run_opts)
end

adapter.debug_api = debug

adapter.resolve_lane_suites = adapter.resolve_suites
adapter.run_all = adapter.run

return adapter
