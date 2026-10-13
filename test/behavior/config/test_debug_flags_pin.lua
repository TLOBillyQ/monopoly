require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- debug_flags.lua 数据契约 pin (#293 变异清扫)。
-- debug_auto_all_roles 的「必须为 false 发布」已由 text-based 的
-- debug_flags_guard 兜底(#265),但那是守源文件字形;这里钉返回模块的取值,
-- 让「值变异」位点(如 false→true / 1→0)在 behavior 车道内被杀掉。
local flags = require("src.config.gameplay.debug_flags")

describe("TestDebugFlagsPin", function()

  it("test_pins_debug_flag_values", function()
    luassert.is.equal(1, flags.info_log_per_turn_limit)
    luassert.is.equal(true, flags.role_control_lock_enabled)
    -- #265 联调开关必须是发布的 false：既是 guard 字面兜底，这里也钉取值。
    luassert.is.equal(false, flags.debug_auto_all_roles)
  end)


end)
