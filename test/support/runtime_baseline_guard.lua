-- 共享运行时端口基线守卫(#217)。
--
-- 共享测试基线(shared_support / env_runtime 加载时建立)把 runtime ports / 付费网关 /
-- 分享面板 port / tips runtime 配置成进程级默认实现。任何 spec 的 teardown 把它们 reset_for_tests()
-- (或清掉 tips presenter)拆到未配置态后不装回,同进程后续 suite 就撞空端口
-- (「missing market paid gateway」之类)——全量车道靠 suite 顺序把它掩盖成偶发,
-- mutate 车道的窄 suite 子集当场翻车,把整个文件的变异车道堵死。
--
-- 本模块给两条车道同一个判定入口:spec-lane 车道由 test/helper.lua 在 test end 时调用,
-- mutate 车道随 spec 经同一 helper 入口核对(原 driver.lua 的 after_case 调用已随
-- driver 契约删除,#274-①)。spec 侧手动装回基线请用
-- shared_support.restore_runtime_services(),不要直接调本模块。

require("test.bootstrap")

local runtime_ports = require("src.foundation.ports.runtime_ports")
local paid_purchase_port = require("src.rules.ports.paid_purchase")
local share_panel_port = require("src.foundation.ports.share_panel")
local tip_queue = require("src.foundation.tips")

local M = {}

-- 守卫范围:基线五处(runtime ports / 付费网关 / 成就端口 / 分享面板 port / tips
-- runtime)里的四个 configure 态。成就端口基线本就是 reset(nil)态,「已配置」判定
-- 对它不适用,排除在外。分享面板 port 未配置时静默降级 false、泄漏无报错(#463),
-- 必须纳入守卫。
function M.missing_ports()
  local missing = {}
  if not runtime_ports.is_configured() then
    missing[#missing + 1] = "runtime_ports"
  end
  if not paid_purchase_port.is_configured() then
    missing[#missing + 1] = "paid_purchase_port"
  end
  if not share_panel_port.is_configured() then
    missing[#missing + 1] = "share_panel_port"
  end
  if type(tip_queue.runtime) ~= "table" or type(tip_queue.runtime.presenter) ~= "function" then
    missing[#missing + 1] = "tips_presenter"
  end
  return missing
end

-- 装回共享测试基线。延迟 require env_runtime:模块加载本身必须无副作用,
-- 供 helper / mutate driver 在任意加载序下安全引用。
function M.restore()
  require("test.env_runtime").refresh_runtime_services()
end

-- 车道守卫入口:发现泄漏先装回基线(泄漏止于当前用例边界,不扩散给同进程后续
-- suite),再返回缺失端口名列表;调用方据非空列表把当前用例判硬失败。
function M.check_and_restore()
  local missing = M.missing_ports()
  if #missing > 0 then
    M.restore()
  end
  return missing
end

-- mutate 车道 after_case 用:有泄漏则装回基线并 error,由 harness 把泄漏用例判失败。
function M.assert_baseline()
  local missing = M.check_and_restore()
  if #missing > 0 then
    error(
      "spec teardown 拆了共享运行时端口基线(" .. table.concat(missing, ", ")
        .. ")未装回——在 teardown 调 shared_support.restore_runtime_services() 装回(#217)",
      0
    )
  end
end

return M
