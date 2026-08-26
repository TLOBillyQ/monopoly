---@diagnostic disable: undefined-global, undefined-field
require("test.bootstrap").install_package_paths()

local lu = require("luaunit")

-- 本仓自己的 arch 规则表断言(#596)。
--
-- 为什么需要它:arch_view_guard 只在「配置里声明了某条规则」时才会报违例。
-- 规则本身被删掉、改名或缩小 from/to 时,门禁照样全绿——不是因为架构守住了,
-- 而是因为没人再检查。arch_view 的 tooling 契约用合成配置验证机制,这里补上
-- 「本仓确实声明了这些规则」这一侧。
local config_path = "tools/packages/arch_view/config.json"

local function _read_config()
  local handle = assert(io.open(config_path, "r"), "缺失 arch 配置: " .. config_path)
  local raw = handle:read("a")
  handle:close()
  return raw
end

TestArchConfigRules = {}

-- ui.state 拥有展示状态,ui.coord 消费它并驱动视图/宿主副作用;层序把两者都算
-- ui(3),所以这条方向约束不在层门禁覆盖范围内,必须由显式规则承担
-- (docs/architecture.md「ui 内部」一节)。
function TestArchConfigRules:test_ui_state_must_not_depend_on_ui_coord()
  local raw = _read_config()
  lu.assertEvalToTrue(raw:find("ui_state_no_coord", 1, true) ~= nil,
    "arch 配置必须声明 ui_state_no_coord 规则,否则 ui.state 反向依赖 ui.coord 无人拦截")
  -- 配置里存的是 Lua 模式串字面量(单个 %),用 plain find 精确比对。
  lu.assertEvalToTrue(raw:find("^src%.ui%.state%..+", 1, true) ~= nil,
    "ui_state_no_coord 的 from 必须覆盖整个 src.ui.state 子树")
  lu.assertEvalToTrue(raw:find("^src%.ui%.coord%..+", 1, true) ~= nil,
    "ui_state_no_coord 的 to 必须覆盖整个 src.ui.coord 子树")
end

return TestArchConfigRules
