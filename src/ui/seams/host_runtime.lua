-- presentation deps 的宿主运行时面（deps.host_runtime）：由 foundation 真源
-- （tips 队列、runtime_ports.schedule）与各能力 port 组合而成，零 host 静态依赖。
-- 宿主实现由 app/host_install.lua 装配时 configure 各能力 port 注入（#250）。
-- 所有转发都是调用时查表（而非装载时捕获函数值），保住 spec 对 port 模块
-- 字段替换的可见性——与旧单桥时代单表字段 patch 的语义一致。
local tips = require("src.foundation.tips")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local host_ports = require("src.ui.seams.host_ports")

local host_runtime = {}

local function _forward(source, name)
  host_runtime[name] = function(...)
    return source[name](...)
  end
end

function host_runtime.enqueue_tip(intent)
  return tips.enqueue(intent)
end

function host_runtime.schedule(delay, fn)
  return runtime_ports.schedule(delay or 0, fn)
end

-- 逐名转发面由各 port 的声明名单派生（单一真源 host_ports + slot.declared_names），
-- 不再手写清单——port 加/删函数只改该 port 自己的 host_slot.new(spec) 声明。
for _, port in ipairs(host_ports) do
  for _, name in ipairs(port.declared_names()) do
    _forward(port, name)
  end
end

return host_runtime

--[[ mutate4lua-manifest
version=4
projectHash=1bdb09b713cb87b7
scope.0.id=chunk:src/ui/seams/host_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=cb1ec256b7a45c8c
scope.1.id=function:_forward
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=16
scope.1.semanticHash=76813260a1fdbdd6
scope.2.id=function:host_runtime.name
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=15
scope.2.semanticHash=7aaca51d4b37242b
scope.3.id=function:host_runtime.enqueue_tip
scope.3.kind=function
scope.3.startLine=18
scope.3.endLine=20
scope.3.semanticHash=f1ce1850b7232305
scope.4.id=function:host_runtime.schedule
scope.4.kind=function
scope.4.startLine=22
scope.4.endLine=24
scope.4.semanticHash=76740e20e15eeb17
]]
