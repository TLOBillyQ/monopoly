local P = require("spec.support.shared_support")
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

describe("action_anim_duration_resolution", function()
  it("_test_explicit_duration_overrides_kind_default", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "missile", duration = 3.0 }, { runtime_bundle = bundle })
    local expected = 3.0 + 0.2
    _assert_eq(d, expected, "explicit duration should override kind default, plus start_delay")
  end)

  it("_test_kind_default_used_when_no_explicit_duration", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "missile" }, { runtime_bundle = bundle })
    local expected = 1.2 + 0.2
    _assert_eq(d, expected, "missile kind should use 1.2s default plus 0.2s start_delay")
  end)

  it("_test_zero_duration_falls_back_to_default", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "item_use", duration = 0 }, { runtime_bundle = bundle })
    _assert_eq(d, timing.action_anim_default_seconds, "zero duration should fall back to default")
  end)

  it("_test_negative_duration_falls_back_to_default", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "item_use", duration = -1.0 }, { runtime_bundle = bundle })
    _assert_eq(d, timing.action_anim_default_seconds, "negative duration should fall back to default")
  end)

  it("_test_unknown_kind_uses_default_duration", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "unknown_kind_xyz" }, { runtime_bundle = bundle })
    _assert_eq(d, timing.action_anim_default_seconds, "unknown kind should use default duration")
  end)

  it("_test_effect_track_scales_duration", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    _with_patches({
      { target = effect_track, key = "scaled_duration", value = function(base) return base * 2 end },
    }, function()
      local d = action_anim.play(state, { kind = "item_use", duration = 1.0 }, { runtime_bundle = bundle })
      _assert_eq(d, 2.0, "effect_track should scale duration by 2x")
    end)
  end)

  it("_test_start_delay_added_for_missile_kind", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "missile" }, { runtime_bundle = bundle })
    local base = 1.2
    local delay = 0.2
    _assert_eq(d, base + delay, "missile should add start_delay to base duration")
  end)

  it("_test_no_start_delay_for_unknown_kind", function()
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    local d = action_anim.play(state, { kind = "item_use", duration = 1.5, player_id = 1 }, { runtime_bundle = bundle })
    _assert_eq(d, 1.5, "item_use should not add start_delay")
  end)
end)

describe("action_anim_tip_policy", function()
  it("_test_roll_kind_never_shows_tip", function()
    local tips = {}
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    bundle.runtime.for_each_role_or_global = function(fn) fn() end
    bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
    action_anim.play(state, { kind = "roll", tip_policy = "user" }, { runtime_bundle = bundle })
    _assert_eq(#tips, 0, "roll kind should never show tip even with user policy")
  end)

  it("_test_user_tip_policy_shows_tip_for_whitelisted_kind", function()
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
  end)

  it("_test_whitelisted_kind_shows_tip_without_user_policy", function()
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
  end)

  it("_test_non_whitelisted_kind_without_user_policy_skips_tip", function()
    local tips = {}
    local state = _make_state()
    local bundle = _make_runtime_bundle()
    bundle.host_runtime.enqueue_tip = function(intent) tips[#tips + 1] = intent end
    action_anim.play(state, { kind = "item_use", player_id = 1 }, { runtime_bundle = bundle })
    _assert_eq(#tips, 0, "item_use without user policy should not show tip")
  end)

  it("_test_empty_tip_text_skips_enqueue", function()
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
  end)

  it("_test_tip_inherits_anim_dedupe_key", function()
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
  end)

  it("_test_tip_source_defaults_to_action_anim_kind", function()
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
  end)
end)
