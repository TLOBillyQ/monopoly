local runtime_assets = require("src.config.runtime_assets")

local function _assert_eq(actual, expected, message)
  assert(actual == expected, (message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
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

describe("runtime_assets resolver", function()
  after_each(function()
    runtime_assets.reset_for_tests()
  end)

  it("resolves image and skin model meanings with normalized ids", function()
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
    assert(missing.ok == false, "missing skin image should reject")
    _assert_eq(missing.reason, "missing_skin_card_image", "missing skin image reason should be stable")
  end)

  it("builds resolver context from state without exposing raw ui refs to adapters", function()
    _configure()

    local explicit = { refs = { images = { item_A = "CTX_ITEM" } } }
    local legacy_state = { ui_refs = { images = { item_A = "LEGACY_ITEM" } } }

    assert(runtime_assets.asset_context({ runtime_asset_context = explicit }) == explicit,
      "explicit runtime asset context should be returned unchanged")
    _assert_eq(runtime_assets.image_for_item("item_A", runtime_assets.asset_context(legacy_state)).image_key,
      "LEGACY_ITEM", "legacy ui refs should remain available through resolver context")
    _assert_eq(runtime_assets.asset_context(nil), nil, "nil root state should not provide a context")
  end)

  it("resolves synthetic ai profile with avatar fallback", function()
    _configure()

    local resolved = runtime_assets.synthetic_ai_profile(2)
    assert(resolved.ok == true, "synthetic profile should resolve")
    _assert_eq(resolved.name, "黄澄澄", "synthetic name should resolve")
    _assert_eq(resolved.unit_key, "UNIT_2", "synthetic unit key should resolve")
    _assert_eq(resolved.avatar_image_key, "AI_2", "synthetic avatar should resolve")
    assert(resolved.fallback_used == false, "configured avatar should not use fallback")

    local fallback = runtime_assets.synthetic_ai_profile(3)
    assert(fallback.ok == true, "synthetic fallback profile should still resolve")
    _assert_eq(fallback.name, "AI3", "synthetic name should fallback to slot label")
    _assert_eq(fallback.avatar_image_key, "EMPTY_IMAGE", "missing avatar should fallback to empty image")
    assert(fallback.fallback_used == true, "missing avatar should mark fallback")
    _assert_eq(fallback.reason, "missing_synthetic_ai_avatar", "synthetic avatar fallback reason should be stable")
  end)

  it("resolves board feedback cue ids, followups, bind offset, and payload overrides", function()
    _configure()

    local cue = runtime_assets.board_feedback_cue("sparkle", {
      effect_id = 99,
      scale = 3.0,
      followup_sounds = {
        { sound_id = 12, delay = 0.1 },
      },
    })

    assert(cue.ok == true, "board feedback cue should resolve")
    _assert_eq(cue.effect_id, 99, "explicit payload effect id should win")
    _assert_eq(cue.sound_id, 10, "cue sound ref should resolve to sound id")
    _assert_eq(cue.scale, 3.0, "explicit payload scale should win")
    _assert_eq(cue.duration, 1.5, "default cue duration should remain")
    _assert_eq(cue.bind_offset.y, 1.6, "bind offset should resolve through runtime constants")
    _assert_eq(cue.followup_sounds[1].sound_id, 12, "explicit followup sound id should win")
    _assert_eq(cue.followup_sounds[1].delay, 0.1, "explicit followup delay should win")

    local missing = runtime_assets.board_feedback_cue("missing")
    assert(missing.ok == false, "missing cue should reject")
    _assert_eq(missing.reason, "missing_board_feedback_cue", "missing cue reason should be stable")
  end)

  it("validates catalog completeness with stable reasons", function()
    local refs = _test_refs()
    refs.images["2007"] = nil
    refs.images["5001"] = nil
    refs.skins["5001"] = nil
    refs.board_feedback.sparkle.effect_id_ref = "missing_effect"
    refs.board_feedback.sparkle.followup_sounds[1].sound_id_ref = "missing_followup"

    _configure({ refs = refs })

    local result = runtime_assets.validate_catalog()

    assert(result.ok == false, "invalid catalog should fail")
    assert(_has_reason(result, "missing_startup_item_icon"), "validate should report missing startup item icon")
    assert(_has_reason(result, "missing_skin_card_image"), "validate should report missing skin card image")
    assert(_has_reason(result, "missing_skin_model"), "validate should report missing skin model")
    assert(_has_reason(result, "missing_board_feedback_effect"), "validate should report missing board effect")
    assert(_has_reason(result, "missing_board_feedback_followup_sound"), "validate should report missing followup sound")
  end)
end)
