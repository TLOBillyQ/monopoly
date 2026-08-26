---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches
local action_anim = require("src.ui.render.anim")
local timing = require("src.config.gameplay.timing")
local effect_track = require("src.ui.render.support.effect_track")

local function _make_state()
  return {
    game = { turn = { current_player_index = 1 }, players = { [1] = { id = 1 } } },
  }
end

local function _make_runtime_bundle()
  return {
    runtime = {
      query_node = function() return {} end,
      set_node_texture_keep_size = function() end,
    },
    ui_events = {
      show = {},
      hide = {},
      send_to_all = function() end,
    },
    host_runtime = {
      enqueue_tip = function() end,
      schedule = function() end,
    },
  }
end

TestActionAnimDurationAndTip = {}

function TestActionAnimDurationAndTip:test_explicit_duration_overrides_kind_default()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "missile", duration = 3.0 }, { runtime_bundle = bundle })
  local expected = 3.0 + 0.2
  _assert_eq(d, expected, "explicit duration should override kind default, plus start_delay")
end

function TestActionAnimDurationAndTip:test_kind_default_used_when_no_explicit_duration()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "missile" }, { runtime_bundle = bundle })
  local expected = 1.2 + 0.2
  _assert_eq(d, expected, "missile kind should use 1.2s default plus 0.2s start_delay")
end

function TestActionAnimDurationAndTip:test_zero_duration_falls_back_to_default()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "item_use", duration = 0 }, { runtime_bundle = bundle })
  _assert_eq(d, timing.action_anim_default_seconds, "zero duration should fall back to default")
end

function TestActionAnimDurationAndTip:test_negative_duration_falls_back_to_default()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "item_use", duration = -1.0 }, { runtime_bundle = bundle })
  _assert_eq(d, timing.action_anim_default_seconds, "negative duration should fall back to default")
end

function TestActionAnimDurationAndTip:test_unknown_kind_uses_default_duration()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "unknown_kind_xyz" }, { runtime_bundle = bundle })
  _assert_eq(d, timing.action_anim_default_seconds, "unknown kind should use default duration")
end

function TestActionAnimDurationAndTip:test_effect_track_scales_duration()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  _with_patches({
    { target = effect_track, key = "scaled_duration", value = function(base) return base * 2 end },
  }, function()
    local d = action_anim.play(state, { kind = "item_use", duration = 1.0 }, { runtime_bundle = bundle })
    _assert_eq(d, 2.0, "effect_track should scale duration by 2x")
  end)
end

function TestActionAnimDurationAndTip:test_start_delay_added_for_missile_kind()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "missile" }, { runtime_bundle = bundle })
  local base = 1.2
  local delay = 0.2
  _assert_eq(d, base + delay, "missile should add start_delay to base duration")
end

function TestActionAnimDurationAndTip:test_no_start_delay_for_unknown_kind()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local d = action_anim.play(state, { kind = "item_use", duration = 1.5, player_id = 1 }, { runtime_bundle = bundle })
  _assert_eq(d, 1.5, "item_use should not add start_delay")
end

function TestActionAnimDurationAndTip:test_roll_kind_never_shows_tip()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.runtime.for_each_role_or_global = function(fn) fn() end
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  action_anim.play(state, { kind = "roll", tip_policy = "user" }, { runtime_bundle = bundle })
  _assert_eq(#tips, 0, "roll kind should never show tip even with user policy")
end

function TestActionAnimDurationAndTip:test_user_tip_policy_shows_tip_for_whitelisted_kind()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test tip" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(#tips, 1, "user tip_policy should show tip for monster kind")
end

function TestActionAnimDurationAndTip:test_whitelisted_kind_shows_tip_without_user_policy()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test tip" end },
  }, function()
    action_anim.play(state, { kind = "item_use", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(#tips, 1, "item_use with user policy should show tip")
end

function TestActionAnimDurationAndTip:test_non_whitelisted_kind_without_user_policy_skips_tip()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  action_anim.play(state, { kind = "item_use", player_id = 1 }, { runtime_bundle = bundle })
  _assert_eq(#tips, 0, "item_use without user policy should not show tip")
end

function TestActionAnimDurationAndTip:test_empty_tip_text_skips_enqueue()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(#tips, 0, "empty tip text should skip enqueue")
end

function TestActionAnimDurationAndTip:test_tip_inherits_anim_dedupe_key()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", dedupe_key = "my_key", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(tips[1].dedupe_key, "my_key", "tip should inherit anim dedupe_key")
end

function TestActionAnimDurationAndTip:test_tip_carries_chain_key_and_inter_turn_block()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test" end },
  }, function()
    action_anim.play(state, {
      kind = "monster",
      tip_policy = "user",
      player_id = 1,
      chain_key = "chain_1",
      blocks_inter_turn = true,
      tip_source = "custom.source",
    }, { runtime_bundle = bundle })
  end)
  _assert_eq(tips[1].chain_key, "chain_1", "tip should inherit anim chain_key")
  _assert_eq(tips[1].blocks_inter_turn, true, "tip should inherit the inter-turn block flag")
  _assert_eq(tips[1].source, "custom.source", "an explicit tip_source should override the default")
end

function TestActionAnimDurationAndTip:test_tip_defaults_blocks_inter_turn_to_false()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(tips[1].blocks_inter_turn, false, "an anim without the flag should not block the inter-turn gap")
  _assert_eq(tips[1].chain_key, nil, "an anim without a chain key should not invent one")
end

function TestActionAnimDurationAndTip:test_tip_is_dropped_when_the_host_runtime_is_absent()
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime = nil
  local duration = nil
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test tip" end },
  }, function()
    duration = action_anim.play(state, {
      kind = "unknown_kind_xyz",
      tip_policy = "user",
      player_id = 1,
      duration = 1.0,
    }, { runtime_bundle = bundle })
  end)
  _assert_eq(duration, 1.0, "a missing host runtime should not stop the anim from reporting its duration")
end

function TestActionAnimDurationAndTip:test_tip_source_defaults_to_action_anim_kind()
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(tips[1].source, "action_anim.monster", "tip source should default to action_anim.{kind}")
end

function TestActionAnimDurationAndTip:test_tip_source_defaults_to_tip_without_kind()
  -- L134 兜底串 "tip" 换 nil:无 kind 的 anim 的 tip source 必须是 action_anim.tip。
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test" end },
  }, function()
    action_anim.play(state, { tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  _assert_eq(tips[1].source, "action_anim.tip", "tip source without kind should fall back to action_anim.tip")
end

function TestActionAnimDurationAndTip:test_handler_opts_carry_camera_sync_methods_and_hold_seconds()
  -- L170/L174/L178/L184/L186/L187 六连:handler opts 必须携带 camera_sync 的
  -- pan/release 方法与默认 hold_seconds,缺一即被这些变异改没。
  local captured_opts = nil
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  local pan = function() end
  local release = function() end
  bundle.camera_sync = {
    pan_camera_to_position = pan,
    release_target_pan = release,
  }
  _with_patches({
    { target = require("src.ui.render.anim.registry"), key = "resolve", value = function()
      return function(_state, _anim, _duration, opts)
        captured_opts = opts
      end
    end },
  }, function()
    -- item_use 无 start_delay,走同步直跑,handler 立即收到 opts
    action_anim.play(state, { kind = "item_use", player_id = 1 }, { runtime_bundle = bundle })
  end)
  lu.assertIs(captured_opts.pan_camera_to_position, pan)
  lu.assertIs(captured_opts.release_target_pan, release)
  local defaults = require("src.ui.render.anim.defaults")
  lu.assertIs(captured_opts.hold_seconds, defaults.roll_face_hold_seconds())
end

function TestActionAnimDurationAndTip:test_scheduled_dispatch_still_passes_handler_opts()
  -- L196 _build_handler_opts 换 nil:延迟调度的 handler 必须仍收到 opts 而非 nil。
  local scheduled = nil
  local captured_opts = nil
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.schedule = function(delay, fn)
    scheduled = { delay = delay, fn = fn }
  end
  _with_patches({
    { target = require("src.ui.render.anim.registry"), key = "resolve", value = function()
      return function(_state, _anim, _duration, opts)
        captured_opts = opts
        return 42
      end
    end },
  }, function()
    action_anim.play(state, { kind = "missile", player_id = 1 }, { runtime_bundle = bundle })
  end)
  lu.assertIs(type(scheduled), "table")
  scheduled.fn()
  lu.assertIs(type(captured_opts), "table")
end

function TestActionAnimDurationAndTip:test_debug_log_requires_tip_text()
  -- L156 `and`->`or`:debug 开关打开但无 tip 文本时不得打日志。
  local info_calls = 0
  local logger = require("src.foundation.log")
  _with_patches({
    { target = logger, key = "is_anim_debug_enabled", value = function() return true end },
    { target = logger, key = "info_unlimited", value = function() info_calls = info_calls + 1 end },
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return nil end },
  }, function()
    local state = _make_state()
    action_anim.play(state, { kind = "monster", player_id = 1 }, { runtime_bundle = _make_runtime_bundle() })
  end)
  _assert_eq(info_calls, 0, "debug log must not fire without tip text")
end

function TestActionAnimDurationAndTip:test_tip_duration_is_forwarded_to_enqueue()
  -- L211 _resolve_tip_duration 换 nil:入队 tip 必须带解析后的 duration。
  local tips = {}
  local state = _make_state()
  local bundle = _make_runtime_bundle()
  bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
  _with_patches({
    { target = require("src.ui.render.anim.handlers"), key = "build_tip", value = function() return "test tip" end },
  }, function()
    action_anim.play(state, { kind = "monster", tip_policy = "user", player_id = 1 }, { runtime_bundle = bundle })
  end)
  lu.assertIs(type(tips[1].duration), "number")
end


return TestActionAnimDurationAndTip
