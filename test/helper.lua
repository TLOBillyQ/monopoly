--- Shared test helper loaded via spec_profiles helper entry; sets package.path
--- and installs Eggy fakes.
--- Specs that need per-test runtime refresh opt in explicitly.
---
--- 覆盖率不再由此处初始化 rock luacov。自研运行器
--- 的 `-c` 在 spec 加载前装 quality.coverage_collector 的 hook(runner.lua),口径与
--- 落盘全部自持,helper 无需参与。原先 LUACOV=1 触发 require("luacov.runner") 的分支
--- 随 rock 退场删除。

require("test.bootstrap")

local events = require("packages.luaunit_runner.events")
local env_runtime = require("test.env_runtime")
env_runtime.refresh()

local test_env = require("test.support.env")
local runtime_baseline_guard = require("test.support.runtime_baseline_guard")

-- 套件级 RNG 重播:behavior 套共用单条全局 math.random 序列,各 spec 消耗的抽数不定
-- (掷骰、抽卡、AI 决策……),会让进入后续用例的 RNG 状态取决于「同进程/同 worker 里
-- 此前跑了什么、抽了多少」。任何断言依赖「进入时 RNG 状态」的用例都可能在并行 LPT
-- 分桶重排后假红。本 helper 直接订阅 tools/packages/luaunit_runner 的事件面，不经过 busted facade：
-- 直接 require packages.luaunit_runner.events),每例 test/start 统一重播
-- test_env.DEFAULT_SEED,从源头消除泄漏,取代逐 spec 的 randomseed(1) band-aid
-- (#45/#46)。守卫见 test/behavior/foundation/test_rng_reset_isolation.lua。
--
-- 仅限 behavior 套:contract/guards/property/tooling 不依赖 RNG。按 it() 调用点
-- 的 trace.source 判定 —— 它指向 spec 文件本身(对 `it(case.name, case.run)` 的场景
-- 套件亦然),且未被 short_src 的定长截断吃掉「test/behavior」前缀。
local function _is_behavior_spec(element)
  local trace = element and element.trace
  local source = trace and trace.source
  if type(source) ~= "string" then
    return false
  end
  return source:gsub("\\", "/"):find("test/behavior", 1, true) ~= nil
end

events.subscribe({ "test", "start" }, function(element)
  if _is_behavior_spec(element) then
    test_env.reseed_defaults()
  end
end)

-- 共享运行时端口基线守卫(#217):test end 事件在所有 after_each 之后触发,此刻
-- runtime ports / 付费网关 / 分享面板 port 应仍处于共享基线的已配置态。谁的
-- teardown 拆到未配置态
-- 不装回,当场记为泄漏——先装回基线止住同进程扩散,再落 `# BASELINE LEAK` 行点名
-- (behavior_parallel 按此行聚合失败明细),收尾把计数打进 errors 让车道硬失败,
-- 不再靠 suite 顺序侥幸掩盖(mutate 车道的窄 suite 子集就是这么翻车的)。
local baseline_leak_count = 0
events.subscribe({ "test", "end" }, function(element)
  if not _is_behavior_spec(element) then
    return
  end
  local missing = runtime_baseline_guard.check_and_restore()
  if #missing > 0 then
    baseline_leak_count = baseline_leak_count + 1
    local source = tostring(element.trace and element.trace.source or "?"):gsub("^@", "")
    io.write("# BASELINE LEAK: " .. source .. " :: " .. tostring(element.full_name or element.name)
      .. " 拆了共享端口基线未装回: " .. table.concat(missing, ", ")
      .. "(teardown 调 shared_support.restore_runtime_services() 装回,#217)\n")
  end
end)
events.subscribe({ "suite", "end" }, function()
  if baseline_leak_count > 0 then
    events.results.errors = events.results.errors + baseline_leak_count
  end
end)

return env_runtime
