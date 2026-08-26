local bootstrap = require("test.bootstrap")

bootstrap.install_package_paths()

local function _assert(condition, message)
  if not condition then
    error(message or "assertion failed", 2)
  end
end

-- #361 P6:handler 测试已挪 behavior 车道,behavior 车道每跑必加载
-- test/log_warns_handler.lua,语法错误立即暴露,此处 loadfile 检查冗余。

-- #321 剥 busted facade:两个契约文件必须直接 require runner 自有模块,
-- 不得回落到 require("busted") / require("busted.outputHandlers.TAP") 命名
-- (作为 run 时代码解析,而非注释里的历史叙述)。
local function _test_contract_files_require_native_events_modules()
  local helper_file = assert(io.open("test/helper.lua", "rb"))
  local helper_text = helper_file:read("*a")
  helper_file:close()
  local handler_file = assert(io.open("test/log_warns_handler.lua", "rb"))
  local handler_text = handler_file:read("*a")
  handler_file:close()

  _assert(not helper_text:find('require("busted"', 1, true),
    "helper must not require the busted facade")
  _assert(not handler_text:find('require("busted"', 1, true),
    "output handler must not require the busted facade")
  _assert(not handler_text:find("busted%.subscribe", 1, true),
    "output handler must subscribe via the events module")
  _assert(handler_text:find('packages.luaunit_runner.events', 1, true) ~= nil,
    "output handler must require the runner events module")
end

local function _test_behavior_warns_data_has_entries()
  local chunk, err = loadfile("test/support/behavior_warns_data.lua")
  _assert(chunk ~= nil, "behavior_warns_data.lua should load: " .. tostring(err))
  local data = chunk()
  _assert(type(data) == "table", "behavior_warns_data should return a table")
  _assert(type(data.whitelist) == "table", "behavior_warns_data.whitelist should be a table")
  local count = 0
  for _ in pairs(data.whitelist) do
    count = count + 1
  end
  _assert(count > 0, "behavior_warns_data.whitelist should have at least one entry")
end

return {
  name = "luaunit_runner_infra_tooling",
  tests = {
    { name = "behavior_warns_data_has_entries", run = _test_behavior_warns_data_has_entries },
    { name = "contract_files_require_native_events_modules", run = _test_contract_files_require_native_events_modules },
  },
}
