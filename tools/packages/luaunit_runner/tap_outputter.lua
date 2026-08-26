--- 自定义 LuaUnit outputter + TAP handler 工厂（直接消费 runner 事件面，
--- #321 剥 busted facade 命名)。
---
--- 两件东西:
---   1. M.outputter_class —— 赋给 LuaUnit 实例的 outputType(startSuite 时
---      new(runner) 实例化)。只做翻译:startTest/endTest/endSuite →
---      events.publish({"test","start"} / {"test","end"} / {"suite","end"}),
---      本身一个 TAP 字符都不印。时序保证:startTest 在 setUp/钩子前被调,
---      endTest 在 tearDown/钩子后被调(见 luaunit.lua execOneFunction)。
---   2. M.tap_handler_factory —— TAP handler 工厂:订阅事件 facade,返回带
---      successes/failures/errors 数组的 handler,输出行格式与旧自研兼容层
---      core.lua 的 tap_handler_factory 逐字节一致(ok N - full_name /
---      not ok N - full_name / # <src> @ <line> / # Failure message: ... /
---      1..N)。log_warns_handler 据此包装,一字不改。

local events = require("packages.luaunit_runner.events")
local registry = require("packages.luaunit_runner.registry")
local file_isolation = require("packages.luaunit_runner.file_isolation")

local M = {}

-- ------------------------------------------------------- LuaUnit outputter

local Outputter = {}
Outputter.__index = Outputter

function Outputter.new(runner)
  return setmetatable({ runner = runner }, Outputter)
end

function Outputter:startSuite()
end

function Outputter:startClass(class_name)
  -- 执行期文件级 _G 装回:旧 core 每个文件的用例跑在该文件加载后的 _G 状态
  -- 上;本 runner 统一后置执行,需在类边界保存/装回 _G(LuaUnit 按类分组连续
  -- 执行,startClass/endClass 成对)。加载期经 spec_env 落进 _G 的全局
  -- (fixture 安装的 fake 等)要让该文件的用例可见,故装回该类登记时的
  -- 环境快照(registry.env_for)。#428 后 package.loaded 不再按类装回:
  -- 逐类装回的是各文件加载时刻的错落快照,会把后加载文件的模块逐出缓存,
  -- 造成跨类模块实例身份分叉(choice 屏注册表假红);模块实例改为全进程共享
  -- 的标准 require 语义,跨文件可变单例状态的隔离由 spec 显式 save/restore
  -- 承接(如 test_screens_registry 的 tearDown)。
  local snap = registry.env_for(class_name)
  if snap ~= nil then
    self._saved_env = file_isolation.snapshot_globals()
    file_isolation.apply_globals(snap)
  end
end

function Outputter:startTest(test_name)
  local element = registry.element_for(test_name)
  events.publish({ "test", "start" }, element, nil)
end

function Outputter:updateStatus(_) -- luacheck: ignore
  -- 旧 core 的 TAP 只在 test/end 出一次行;失败/错误信息随 endTest 的 node 带来,
  -- 这里不需要提前做任何事。
end

function Outputter:endTest(node)
  local element, meta = registry.element_for(node.testName)

  local status, message
  if node:isSuccess() then
    status = "success"
  elseif node:isSkipped() then
    -- 旧 core 无 skip 概念;LuaUnit 原生 spec 若用 lu.skip 这里按 success 记账,
    -- 保持 successes/failures/errors 三桶语义不变。
    status = "success"
  elseif node:isFailure() then
    status, message = "failure", node.msg
  else
    status, message = "error", node.msg
  end

  -- 原生 spec 的 `# <src> @ <line>`:LuaUnit 错误消息自带 `file:line: ` 前缀
  -- (error() 的位置信息,assert 失败时精确到断言行),比方法 linedefined 更准,
  -- 优先采用。遗留 spec 保持 linedefined 口径 —— 与旧 core 逐字节一致。
  if status ~= "success" and meta ~= nil and meta.kind == "native" and message ~= nil then
    local src, line = tostring(message):match("^(.-):(%d+): ")
    if src ~= nil and src:match("%.lua$") ~= nil then
      element.trace = { source = "@" .. src, currentline = tonumber(line) }
    end
  end

  events.publish({ "test", "end" }, element, nil, status, message)
end

function Outputter:endClass()
  if self._saved_env ~= nil then
    file_isolation.apply_globals(self._saved_env)
    self._saved_env = nil
  end
end

function Outputter:endSuite()
  events.publish({ "suite", "end" })
end

M.outputter_class = Outputter

-- -------------------------------------------- TAP handler 工厂
-- 与旧自研兼容层 core.lua 的 tap_handler_factory 逐行同构,输出契约不变。

function M.tap_handler_factory(options) -- luacheck: ignore options
  local handler = { successes = {}, failures = {}, errors = {} }
  local counter = 0

  events.subscribe({ "test", "end" }, function(element, _, status, message)
    counter = counter + 1
    if status == "success" then
      handler.successes[#handler.successes + 1] = element
      io.write(("ok %d - %s\n"):format(counter, element.full_name or element.name))
    else
      local bucket = status == "error" and handler.errors or handler.failures
      bucket[#bucket + 1] = element
      io.write(("not ok %d - %s\n"):format(counter, element.full_name or element.name))
      local src = tostring(element.trace and element.trace.source or "?"):gsub("^@", "")
      io.write(("# %s @ %d\n"):format(src, element.trace and element.trace.currentline or 0))
      if message ~= nil then
        io.write("# Failure message: " .. tostring(message):gsub("\n", "\n# ") .. "\n")
      end
    end
    return nil, true
  end)

  events.subscribe({ "suite", "end" }, function()
    io.write(("1..%d\n"):format(counter))
    return nil, true
  end)

  return handler
end

return M
