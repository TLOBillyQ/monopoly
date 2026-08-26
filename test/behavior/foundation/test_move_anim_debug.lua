-- map #73 收缩后 move_anim_debug 只看运行时开关（logger.is_anim_debug_enabled），
-- 静态 debug_flags flag 已删除；日志出口是 print（无环形缓冲），spec 用 print 捕获。

local lu = require("luaunit")
local move_anim_debug = require("src.foundation.move_anim_debug")
local logger = require("src.foundation.log")
local config_reset = require("test.support.config_reset")

-- 原生 LuaUnit 迁移:两个平级 describe 各带 before_each/after_each(内容相同),
-- 按钩子边界拍平为两个 Test* 类(enabled / log),用例数与改写前一一对应(3 + 2 = 5 例)。

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

TestMoveAnimDebugEnabled = {}

function TestMoveAnimDebugEnabled:setUp()
  config_reset.reset_all()
  logger.set_anim_debug_enabled_provider(nil)
end

function TestMoveAnimDebugEnabled:tearDown()
  logger.set_anim_debug_enabled_provider(nil)
  config_reset.reset_all()
end

function TestMoveAnimDebugEnabled:test_returns_false_when_the_runtime_provider_is_off()
  lu.assertEvalToTrue(move_anim_debug.enabled() == false, "expected false without runtime provider")
end

function TestMoveAnimDebugEnabled:test_returns_true_when_the_runtime_provider_returns_true()
  _set_provider(true)
  lu.assertEvalToTrue(move_anim_debug.enabled() == true, "expected true from runtime provider")
end

function TestMoveAnimDebugEnabled:test_returns_false_when_the_provider_returns_truthy_non_boolean()
  _set_provider("yes")
  lu.assertEvalToTrue(move_anim_debug.enabled() == false,
    "expected false for non-bool truthy because == true is enforced")
end

TestMoveAnimDebugLog = {}

function TestMoveAnimDebugLog:setUp()
  config_reset.reset_all()
  logger.set_anim_debug_enabled_provider(nil)
end

function TestMoveAnimDebugLog:tearDown()
  logger.set_anim_debug_enabled_provider(nil)
  config_reset.reset_all()
end

function TestMoveAnimDebugLog:test_does_not_push_when_disabled()
  local text = _capture_print(function()
    move_anim_debug.log("suppressed_payload")
  end)
  lu.assertEvalToTrue(not text:find("suppressed_payload"), "expected payload not logged when disabled")
  lu.assertEvalToTrue(not text:find("MoveAnim"), "expected MoveAnim tag absent when disabled")
end

function TestMoveAnimDebugLog:test_pushes_with_moveanim_tag_when_enabled_via_provider()
  _set_provider(true)
  local text = _capture_print(function()
    move_anim_debug.log("tagged_payload_one", "tagged_payload_two")
  end)
  lu.assertEvalToTrue(text:find("%[MoveAnim%]"), "expected [MoveAnim] tag in output: " .. tostring(text))
  lu.assertEvalToTrue(text:find("tagged_payload_one"), "expected first payload arg in output")
  lu.assertEvalToTrue(text:find("tagged_payload_two"), "expected second payload arg in output")
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestMoveAnimDebugEnabled,
  TestMoveAnimDebugLog
)
