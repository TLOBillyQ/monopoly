require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
-- map #73 收缩后 move_anim_debug 只看运行时开关（logger.is_anim_debug_enabled），
-- 静态 debug_flags flag 已删除；日志出口是 print（无环形缓冲），spec 用 print 捕获。

local move_anim_debug = require("src.foundation.move_anim_debug")
local logger = require("src.foundation.log")
local config_reset = require("test.support.config_reset")


local function _set_provider(value)
  logger.set_anim_debug_enabled_provider(function() return value end)
end

local function _capture_print(fn)
  local captured = {}
  local original_print = _G.print
  rawset(_G, "print", function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[#parts + 1] = tostring(select(i, ...))
    end
    captured[#captured + 1] = table.concat(parts, " ")
  end)
  local ok, err = pcall(fn)
  rawset(_G, "print", original_print)
  if not ok then
    error(err)
  end
  return table.concat(captured, "\n")
end

describe("TestMoveAnimDebugEnabled", function()

  before_each(function()
    config_reset.reset_all()
    logger.set_anim_debug_enabled_provider(nil)
  end)

  after_each(function()
    logger.set_anim_debug_enabled_provider(nil)
    config_reset.reset_all()
  end)

  it("test_returns_false_when_the_runtime_provider_is_off", function()
    luassert.truthy(move_anim_debug.enabled() == false, "expected false without runtime provider")
  end)

  it("test_returns_true_when_the_runtime_provider_returns_true", function()
    _set_provider(true)
    luassert.truthy(move_anim_debug.enabled() == true, "expected true from runtime provider")
  end)

  it("test_returns_false_when_the_provider_returns_truthy_non_boolean", function()
    _set_provider("yes")
    luassert.truthy(move_anim_debug.enabled() == false, "expected false for non-bool truthy because == true is enforced")
  end)

end)
describe("TestMoveAnimDebugLog", function()

  before_each(function()
    config_reset.reset_all()
    logger.set_anim_debug_enabled_provider(nil)
  end)

  after_each(function()
    logger.set_anim_debug_enabled_provider(nil)
    config_reset.reset_all()
  end)

  it("test_does_not_push_when_disabled", function()
    local text = _capture_print(function()
      move_anim_debug.log("suppressed_payload")
    end)
    luassert.truthy(not text:find("suppressed_payload"), "expected payload not logged when disabled")
    luassert.truthy(not text:find("MoveAnim"), "expected MoveAnim tag absent when disabled")
  end)

  it("test_pushes_with_moveanim_tag_when_enabled_via_provider", function()
    _set_provider(true)
    local text = _capture_print(function()
      move_anim_debug.log("tagged_payload_one", "tagged_payload_two")
    end)
    luassert.truthy(text:find("%[MoveAnim%]"), "expected [MoveAnim] tag in output: " .. tostring(text))
    luassert.truthy(text:find("tagged_payload_one"), "expected first payload arg in output")
    luassert.truthy(text:find("tagged_payload_two"), "expected second payload arg in output")
  end)


end)
