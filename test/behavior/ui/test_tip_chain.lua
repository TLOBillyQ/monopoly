---@diagnostic disable: need-check-nil, undefined-field
-- tip_chain(自 anim/init.lua 拆分)的 tip 链直接 spec:mutation-closure pins。
-- 覆盖:白名单 kind 展示、user 策略展示、roll 排除、debug 日志门、时长定稿
-- (tofixed 设备链 + 原始直通)、nil anim 容忍。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local tip_chain = require("src.ui.render.anim.tip_chain")
local handlers = require("src.ui.render.anim.handlers")
local logger = require("src.foundation.log")

local _with_patches = support.with_patches
local _assert_eq = support.assert_eq

local _TIP = "测试提示"

local function _emit(anim, duration)
  local captured = nil
  local host_runtime = {
    enqueue_tip = function(request)
      captured = request
    end,
  }
  tip_chain.emit({}, anim, host_runtime, duration)
  return captured
end

-- build_tip 钉成恒返回文案:展示判定与时长链才是本文件要钉的对象。
local function _emit_with_tip(anim, duration)
  local captured
  _with_patches({
    {
      target = handlers,
      key = "build_tip",
      value = function()
        return _TIP
      end,
    },
  }, function()
    captured = _emit(anim, duration)
  end)
  return captured
end

TestTipChain = {}

function TestTipChain:test_whitelisted_kinds_emit_tips()
  -- kills user_tip_whitelist 五个条目 true→false:白名单 kind 必须展示 tip。
  for _, kind in ipairs({ "monster", "missile", "item_target_player", "teleport_effect", "clear_obstacles" }) do
    local captured = _emit_with_tip({ kind = kind }, 2.0)
    lu.assertEvalToTrue(captured ~= nil, "whitelisted kind should emit a tip; got nil for " .. tostring(kind))
    _assert_eq(captured.text, _TIP, "whitelisted tip should carry the built text")
  end
end

function TestTipChain:test_non_whitelisted_kind_emits_no_tip()
  local captured = _emit_with_tip({ kind = "unknown_kind" }, 2.0)
  lu.assertEvalToTrue(captured == nil, "a non-whitelisted kind without a policy must not emit a tip")
end

function TestTipChain:test_user_policy_emits_tip_for_any_kind()
  -- kills _should_show_tip 的 user 策略分支 true→false。
  local captured = _emit_with_tip({ kind = "anything", tip_policy = "user" }, 2.0)
  lu.assertEvalToTrue(captured ~= nil, "user policy should emit a tip regardless of kind")
end

function TestTipChain:test_roll_kind_emits_no_tip_and_no_debug_log()
  -- kills roll 排除(should_show_tip/should_debug_log 两处)与 debug 日志门。
  local logged = 0
  local captured
  _with_patches({
    {
      target = handlers,
      key = "build_tip",
      value = function()
        return _TIP
      end,
    },
    {
      target = logger,
      key = "is_anim_debug_enabled",
      value = function()
        return true
      end,
    },
    {
      target = logger,
      key = "info_unlimited",
      value = function()
        logged = logged + 1
      end,
    },
  }, function()
    captured = _emit({ kind = "roll" }, 2.0)
  end)
  lu.assertEvalToTrue(captured == nil, "roll kind must not emit a tip")
  _assert_eq(logged, 0, "roll kind must not leave a debug log")
end

function TestTipChain:test_nil_anim_is_tolerated_without_error()
  -- kills _should_debug_log 首操作数 and→or:anim 缺位时不得索引 nil.kind。
  local ok = true
  _with_patches({
    {
      target = handlers,
      key = "build_tip",
      value = function()
        return _TIP
      end,
    },
  }, function()
    local result = pcall(_emit, nil, 2.0)
    ok = result
  end)
  lu.assertEvalToTrue(ok, "emit with a nil anim should not raise")
end

function TestTipChain:test_duration_passes_through_without_tofixed()
  -- kills _to_fixed_duration 的 ok/as_fixed 守卫:宿主无 math.tofixed 时
  -- 原样直通,不得把 pcall 错误串当时长。
  local captured = _emit_with_tip({ kind = "monster", tip_policy = "user" }, 3.5)
  lu.assertEvalToTrue(captured ~= nil, "tip should enqueue")
  _assert_eq(captured.duration, 3.5, "duration should pass through raw without math.tofixed")
end

function TestTipChain:test_tofixed_formats_numeric_duration_only()
  -- kills pcall(math.tofixed)→nil 与 _resolve_tip_duration 的 is_numeric/and
  -- 守卫:数值时长经宿主 tofixed 定稿,非数值时长不得进入 tofixed 链。
  local captured
  _with_patches({
    {
      target = handlers,
      key = "build_tip",
      value = function()
        return _TIP
      end,
    },
    {
      target = math,
      key = "tofixed",
      value = function(duration)
        return "fixed-" .. tostring(duration)
      end,
    },
  }, function()
    captured = _emit({ kind = "monster", tip_policy = "user" }, 3.0)
    _assert_eq(captured.duration, "fixed-3.0", "numeric duration should be fixed by the host tofixed")
    captured = _emit({ kind = "monster", tip_policy = "user" }, "x")
    _assert_eq(captured.duration, "x", "non-numeric duration must not enter the tofixed chain")
  end)
end

function TestTipChain:test_tofixed_raise_falls_back_to_raw_duration()
  -- kills _to_fixed_duration 的 ok 守卫 and→or:宿主 tofixed 抛异常时不得把
  -- 错误串当时长。
  local captured
  _with_patches({
    {
      target = handlers,
      key = "build_tip",
      value = function()
        return _TIP
      end,
    },
    {
      target = math,
      key = "tofixed",
      value = function()
        error("host tofixed raised")
      end,
    },
  }, function()
    captured = _emit({ kind = "monster", tip_policy = "user" }, 4.0)
  end)
  _assert_eq(captured.duration, 4.0, "a raising host tofixed should fall back to the raw duration")
end

return TestTipChain
