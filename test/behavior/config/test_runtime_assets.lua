local lu = require("luaunit")
local runtime_assets = require("src.config.runtime_assets")

local function _assert_eq(actual, expected, message)
  lu.assertEvalToTrue(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function _test_refs()
  return {
    images = {
      ["2007"] = "ITEM_2007",
      ["3001"] = "CHANCE_3001",
      ["5001"] = "SKIN_5001",
      Empty = "EMPTY_IMAGE",
      AI2 = "AI_2",
    },
    skins = {
      ["5001"] = "MODEL_5001",
    },
    default_creature = "DEFAULT_MODEL",
    audio = {
      cash = 10,
      follow = 11,
    },
    effects = {
      spark = 20,
    },
    board_feedback = {
      sparkle = {
        effect_id_ref = "spark",
        sound_id_ref = "cash",
        scale = 2.0,
        duration = 1.5,
        volume = 0.8,
        bind_offset = "above_head",
        followup_sounds = {
          { sound_id_ref = "follow", delay = 0.25, duration = 0.75, volume = 0.5 },
        },
        allow_missing_resource = true,
      },
    },
    synthetic_ai = {
      names = {
        [2] = "黄澄澄",
      },
      unit_keys = {
        [2] = "UNIT_2",
      },
    },
  }
end

local function _configure(opts)
  opts = opts or {}
  runtime_assets.configure_for_tests({
    refs = opts.refs or _test_refs(),
    constants = opts.constants or {
      above_head = { x = 0.0, y = 1.6, z = 0.0 },
    },
    skins = opts.skins or {
      { product_id = 5001, name = "skin one" },
    },
    startup_item_ids = opts.startup_item_ids or { 2007 },
  })
end

local function _has_reason(result, reason)
  for _, error_entry in ipairs(result.errors or {}) do
    if error_entry.reason == reason then
      return true
    end
  end
  return false
end

TestRuntimeAssets = {}

function TestRuntimeAssets:tearDown()
  runtime_assets.reset_for_tests()
end

function TestRuntimeAssets:test_resolves_image_and_skin_model_meanings_with_normalized_ids()
  _configure()

  _assert_eq(runtime_assets.image_for_item(2007).image_key, "ITEM_2007", "item icon should resolve")
  _assert_eq(runtime_assets.image_for_chance_card("3001").image_key, "CHANCE_3001", "chance icon should resolve")
  _assert_eq(runtime_assets.image_for_skin_card(5001).image_key, "SKIN_5001", "skin card should resolve")
  _assert_eq(runtime_assets.image_for_popup_card("item_card", 2007).image_key, "ITEM_2007", "popup item card should resolve")
  _assert_eq(runtime_assets.image_for_market_item(2008, "item one").ok, false, "missing market item should reject")
  _assert_eq(runtime_assets.image_for_market_item(2008, "item one", {
    refs = { images = { ["item one"] = "ITEM_NAME_ICON" } },
  }).image_key, "ITEM_NAME_ICON", "market item should fallback to display-name image")
  _assert_eq(runtime_assets.skin_model_for_product("5001").asset_id, "MODEL_5001", "skin model should resolve")
  _assert_eq(runtime_assets.default_skin_model().asset_id, "DEFAULT_MODEL", "default skin model should resolve")

  local missing = runtime_assets.image_for_skin_card(5002)
  lu.assertEvalToTrue(missing.ok == false, "missing skin image should reject")
  _assert_eq(missing.reason, "missing_skin_card_image", "missing skin image reason should be stable")
end

function TestRuntimeAssets:test_returns_explicit_resolver_context_from_state()
  _configure()

  local explicit = { refs = { images = { item_A = "CTX_ITEM" } } }

  lu.assertEvalToTrue(runtime_assets.asset_context({ runtime_asset_context = explicit }) == explicit,
    "explicit runtime asset context should be returned unchanged")
  _assert_eq(runtime_assets.asset_context(nil), nil, "nil root state should not provide a context")
end

function TestRuntimeAssets:test_resolves_synthetic_ai_profile_with_avatar_fallback()
  _configure()

  local resolved = runtime_assets.synthetic_ai_profile(2)
  lu.assertEvalToTrue(resolved.ok == true, "synthetic profile should resolve")
  -- L34 `results.result("synthetic_ai.profile", ...)` 的首参 -> nil 会丢 meaning,
  -- 结果契约按 kind 分派依赖该标识,钉死。
  _assert_eq(resolved.meaning, "synthetic_ai.profile", "synthetic profile meaning should be stable")
  _assert_eq(resolved.name, "黄澄澄", "synthetic name should resolve")
  _assert_eq(resolved.unit_key, "UNIT_2", "synthetic unit key should resolve")
  _assert_eq(resolved.avatar_image_key, "AI_2", "synthetic avatar should resolve")
  lu.assertEvalToTrue(resolved.fallback_used == false, "configured avatar should not use fallback")

  local fallback = runtime_assets.synthetic_ai_profile(3)
  lu.assertEvalToTrue(fallback.ok == true, "synthetic fallback profile should still resolve")
  _assert_eq(fallback.name, "AI3", "synthetic name should fallback to slot label")
  _assert_eq(fallback.avatar_image_key, "EMPTY_IMAGE", "missing avatar should fallback to empty image")
  lu.assertEvalToTrue(fallback.fallback_used == true, "missing avatar should mark fallback")
  _assert_eq(fallback.reason, "missing_synthetic_ai_avatar", "synthetic avatar fallback reason should be stable")

  -- nil or invalid slot defaults to 1
  local defaulted = runtime_assets.synthetic_ai_profile(nil)
  lu.assertEvalToTrue(defaulted.ok == true, "nil slot should default to slot 1")
  _assert_eq(defaulted.slot_index, 1, "nil slot index defaults to 1")
end

function TestRuntimeAssets:test_resolves_board_feedback_cue_ids_followups_bind_offset_and_payload_overrides()
  _configure()

  local cue = runtime_assets.board_feedback_cue("sparkle", {
    effect_id = 99,
    scale = 3.0,
    followup_sounds = {
      { sound_id = 12, delay = 0.1 },
    },
  })

  lu.assertEvalToTrue(cue.ok == true, "board feedback cue should resolve")
  _assert_eq(cue.effect_id, 99, "explicit payload effect id should win")
  _assert_eq(cue.sound_id, 10, "cue sound ref should resolve to sound id")
  _assert_eq(cue.scale, 3.0, "explicit payload scale should win")
  _assert_eq(cue.duration, 1.5, "default cue duration should remain")
  _assert_eq(cue.bind_offset.y, 1.6, "bind offset should resolve through runtime constants")
  _assert_eq(cue.followup_sounds[1].sound_id, 12, "explicit followup sound id should win")
  _assert_eq(cue.followup_sounds[1].delay, 0.1, "explicit followup delay should win")

  local missing = runtime_assets.board_feedback_cue("missing")
  lu.assertEvalToTrue(missing.ok == false, "missing cue should reject")
  _assert_eq(missing.meaning, "board_feedback.cue", "missing cue meaning should stay stable")
  _assert_eq(missing.reason, "missing_board_feedback_cue", "missing cue reason should be stable")
end

-- 批3 击杀：board_feedback_cue 结果表深字段 pin——meaning 标识、lookup_key/
-- rot/with_sound/volume/sound_duration 取值通道（call 换 nil 与 key 换 nil 两组
-- 变异同案击穿）、allow_missing 布尔严格判定、followup sound_id/duration/volume。
function TestRuntimeAssets:test_board_feedback_cue_pins_remaining_result_fields()
  _configure()

  local cue = runtime_assets.board_feedback_cue("sparkle", {
    rot = { x = 1.0 },
    with_sound = false,
    volume = 0.6,
    sound_duration = 1.2,
  })

  lu.assertEvalToTrue(cue.ok == true, "board feedback cue should resolve")
  _assert_eq(cue.meaning, "board_feedback.cue", "cue meaning should stay stable")
  _assert_eq(cue.effect_lookup_key, "spark", "effect_id_ref lookup key should resolve")
  _assert_eq(cue.sound_lookup_key, "cash", "sound_id_ref lookup key should resolve")
  _assert_eq(cue.rot.x, 1.0, "payload rot should win")
  _assert_eq(cue.with_sound, false, "payload with_sound should win")
  _assert_eq(cue.volume, 0.6, "payload volume should win")
  _assert_eq(cue.sound_duration, 1.2, "payload sound_duration should win")
  _assert_eq(cue.allow_missing, true, "allow_missing_resource true should pin allow_missing")
  _assert_eq(cue.followup_sounds[1].sound_id, 11, "followup sound ref should resolve to sound id")
  _assert_eq(cue.followup_sounds[1].duration, 0.75, "followup duration should resolve")
  _assert_eq(cue.followup_sounds[1].volume, 0.5, "followup volume should resolve")

  -- allow_missing 严格布尔判定：非 true 值（如 1）不得启用。
  local non_bool_refs = _test_refs()
  non_bool_refs.board_feedback.sparkle.allow_missing_resource = 1
  _configure({ refs = non_bool_refs })
  local loose = runtime_assets.board_feedback_cue("sparkle")
  _assert_eq(loose.allow_missing, false, "non-boolean allow_missing_resource must not enable allow_missing")
end

function TestRuntimeAssets:test_validates_catalog_completeness_with_stable_reasons()
  local refs = _test_refs()
  refs.images["2007"] = nil
  refs.images["5001"] = nil
  refs.skins["5001"] = nil
  refs.board_feedback.sparkle.effect_id_ref = "missing_effect"
  refs.board_feedback.sparkle.sound_id_ref = "missing_sound"
  refs.board_feedback.sparkle.followup_sounds[1].sound_id_ref = "missing_followup"

  _configure({ refs = refs })

  local result = runtime_assets.validate_catalog()

  lu.assertEvalToTrue(result.ok == false, "invalid catalog should fail")
  lu.assertEvalToTrue(_has_reason(result, "missing_startup_item_icon"), "validate should report missing startup item icon")
  lu.assertEvalToTrue(_has_reason(result, "missing_skin_card_image"), "validate should report missing skin card image")
  lu.assertEvalToTrue(_has_reason(result, "missing_skin_model"), "validate should report missing skin model")
  lu.assertEvalToTrue(_has_reason(result, "missing_board_feedback_effect"), "validate should report missing board effect")
  lu.assertEvalToTrue(_has_reason(result, "missing_board_feedback_sound"), "validate should report missing board sound")
  lu.assertEvalToTrue(_has_reason(result, "missing_board_feedback_followup_sound"), "validate should report missing followup sound")
end


return TestRuntimeAssets
