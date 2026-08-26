--- runner 事件 facade（#321
--- 剥 busted facade 命名)。对齐旧自研兼容层 core.lua 的 subscribe/publish/
--- results 表面,供两类消费者复用:
---   - test/helper.lua:events.subscribe({"test","start"}/{ "test","end"} /
---     {"suite","end"}),并在 suite/end 时往 events.results.errors 加基线泄漏计数。
---   - test/log_warns_handler.lua:require("packages.luaunit_runner.events") 订阅事件。
--- 事件时序契约(与旧 core 一致):
---   - {"test","start"} 在测试体(含 before_each 钩子链)之前触发;
---   - {"test","end"} 在所有 after_each / tearDown 之后触发,带
---     (element, nil, status, message),status ∈ success/failure/error;
---   - {"suite","end"} 在整个 suite 跑完后触发一次。
--- results 计数在 publish 时先于回调更新(对齐旧 core 在 _run_test 里先计数再
--- publish 的语义),helper 的泄漏计数在 suite/end 回调里追加进 errors。

local M = {}

local _subscriptions = {}

M.results = { successes = 0, failures = 0, errors = 0 }

function M.subscribe(event, cb)
  local key = table.concat(event, "/")
  local list = _subscriptions[key]
  if list == nil then
    list = {}
    _subscriptions[key] = list
  end
  list[#list + 1] = cb
end

function M.publish(event, ...)
  if event[1] == "test" and event[2] == "end" then
    local status = select(3, ...) -- (element, block, status, message)
    if status == "success" then
      M.results.successes = M.results.successes + 1
    elseif status == "failure" then
      M.results.failures = M.results.failures + 1
    else
      M.results.errors = M.results.errors + 1
    end
  end
  local list = _subscriptions[table.concat(event, "/")]
  if list == nil then
    return
  end
  for _, cb in ipairs(list) do
    cb(...)
  end
end

return M
