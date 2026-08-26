-- runtime_assets 变异 survivor 闭合(#261):board_feedback 的 warn 前缀/
-- 拒绝理由链/数值归一/resolve_asset_ref 守卫/followup 数值解析,
-- results 的 ok 缺省与 image_key 查找,state 的 skins 加载/refs 守卫/
-- configure 双 or,images 的 popup meaning 链/market 回落/default_skin_model。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local board_feedback = require("src.config.runtime_assets.board_feedback")
local images = require("src.config.runtime_assets.images")
local results = require("src.config.runtime_assets.results")
local state = require("src.config.runtime_assets.state")
local logger = require("src.foundation.log")

local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local function _refs()
  return {
    images = { ["2007"] = "ITEM_2007" },
    effects = { spark = 20 },
    audio = { cash = 10 },
    board_feedback = {
      sparkle = {
        effect_id_ref = "spark",
        sound_id_ref = "cash",
        duration = 2,
        followup_sounds = {
          { sound_id_ref = "cash", delay = 0.25, duration = 0.75, volume = 0.5 },
        },
      },
    },
  }
end

local function _capture_warn(fn)
  local warns = {}
  _with_patches({
    { target = logger, key = "warn", value = function(...) warns[#warns + 1] = { ... } end },
  }, fn)
  return warns
end

TestRuntimeAssetsClosure = {}

function TestRuntimeAssetsClosure:test_a_non_numeric_string_field_warns_with_the_module_prefix_and_non_numeric_reason()
  -- kills _warn_invalid_number's "board_feedback"/"invalid cue config" -> nil
  -- and the reason chain's `or "non_numeric"` mutants.
  local warns = _capture_warn(function()
    board_feedback.board_feedback_cue("sparkle", { scale = "abc" }, { refs = _refs() })
  end)
  _assert_eq(#warns, 1, "exactly one warn for the bad field")
  _assert_eq(warns[1][1], "board_feedback", "warn keeps the module prefix")
  _assert_eq(warns[1][2], "invalid cue config", "warn keeps the caption")
  _assert_eq(warns[1][6], "reason=non_numeric", "a string field is non_numeric")
end

function TestRuntimeAssetsClosure:test_a_table_field_warns_with_the_vector_like_not_allowed_reason()
  -- kills the reason chain's `type(value) == "table"` == -> ~=, and -> or,
  -- "table" -> nil and "vector_like_not_allowed" -> nil.
  local warns = _capture_warn(function()
    board_feedback.board_feedback_cue("sparkle", { scale = { 1, 2 } }, { refs = _refs() })
  end)
  _assert_eq(#warns, 1, "exactly one warn for the table field")
  _assert_eq(warns[1][6], "reason=vector_like_not_allowed", "a table field is vector-like")
end

function TestRuntimeAssetsClosure:test_integer_cue_fields_stay_integers_after_numeric_normalization()
  -- kills _resolve_numeric_field's coercion operator mutants: the result must
  -- preserve the integer type (Eggy Fixed params distinguish int/float).
  local result = board_feedback.board_feedback_cue("sparkle", nil, { refs = _refs() })
  _assert_eq(result.duration, 2, "the cue duration passes through")
  _assert_eq(math.type(result.duration), "integer", "an integer field stays an integer")
end

function TestRuntimeAssetsClosure:test_followup_sound_non_numeric_fields_warn_with_nested_field_labels()
  -- 批3 击杀 followup_sounds.{delay,duration,volume} 字段标签字符串变异
  -- （L83/L84/L85）：非数值嵌套字段的告警必须带各自的 field= 标签。
  local function _bad_field_warn_label(field)
    local payload = { followup_sounds = {} }
    payload.followup_sounds[1] = {}
    payload.followup_sounds[1][field] = "nope"
    local warns = _capture_warn(function()
      board_feedback.board_feedback_cue("sparkle", payload, { refs = _refs() })
    end)
    _assert_eq(#warns, 1, "exactly one warn for the bad followup field " .. field)
    _assert_eq(warns[1][4], "field=followup_sounds." .. field, "warn keeps the nested field label")
  end
  _bad_field_warn_label("delay")
  _bad_field_warn_label("duration")
  _bad_field_warn_label("volume")
end

function TestRuntimeAssetsClosure:test_followup_sound_entries_resolve_duration_and_volume()
  -- kills the followup _resolve_numeric_field call -> nil pair.
  local result = board_feedback.board_feedback_cue("sparkle", nil, { refs = _refs() })
  local followup = result.followup_sounds[1]
  _assert_eq(followup.duration, 0.75, "followup duration resolved")
  _assert_eq(followup.volume, 0.5, "followup volume resolved")
end

function TestRuntimeAssetsClosure:test_resolve_asset_ref_rejects_empty_string_and_non_string_names_even_when_keyed()
  -- kills resolve_asset_ref's `or` -> `and` and `== ""` -> `== nil`: hostile
  -- refs carrying [""] / [42] keys must still be rejected by the guard.
  local hostile = { effects = { [""] = 9, [42] = 7 } }
  _assert_eq(board_feedback.resolve_asset_ref(hostile, "effect", ""), nil,
    "an empty-string ref name is rejected")
  _assert_eq(board_feedback.resolve_asset_ref(hostile, "effect", 42), nil,
    "a non-string ref name is rejected")
  _assert_eq(board_feedback.resolve_asset_ref(hostile, "effect", "spark"), nil,
    "an unmapped string ref resolves to nil integer")
end

function TestRuntimeAssetsClosure:test_key_result_and_missing_tolerate_nil_fields()
  -- 批3 击杀 L6（key nil 判等）、L13/L20（result/missing 无 fields 直调）：
  -- nil 键必须保持 nil 而非字符串 "nil"；无 fields 的 result/missing 必须自建表。
  _assert_eq(results.key(nil), nil, "a nil key stays nil, not the string nil")
  _assert_eq(results.key(7), "7", "a number key stringifies")
  local bare = results.result("bare.meaning")
  _assert_eq(bare.meaning, "bare.meaning", "result without fields builds a table")
  _assert_eq(bare.ok, true, "a bare result defaults to ok")
  local bare_missing = results.missing("bare.missing", "bare_reason")
  _assert_eq(bare_missing.meaning, "bare.missing", "missing without fields builds a table")
  _assert_eq(bare_missing.ok, false, "a bare missing is not ok")
  _assert_eq(bare_missing.reason, "bare_reason", "bare missing reason pinned")
end

function TestRuntimeAssetsClosure:test_m_result_keeps_an_explicit_ok_true()
  -- kills M.result's `out.ok ~= false` false -> true.
  _assert_eq(results.result("m", { ok = true }).ok, true, "explicit ok=true survives")
  _assert_eq(results.result("m", {}).ok, true, "missing ok defaults to true")
  _assert_eq(results.result("m", { ok = false }).ok, false, "explicit ok=false survives")
end

function TestRuntimeAssetsClosure:test_image_result_resolves_the_mapped_asset_id_not_a_boolean()
  -- kills image_result's `raw_key ~= nil and state.images(opts)[k] or nil`
  -- `and` -> `or` (mutant binds image_key to true).
  local result = images.image_for_item(2007, { refs = _refs() })
  _assert_eq(result.ok, true, "a mapped item id resolves")
  _assert_eq(result.image_key, "ITEM_2007", "the image key comes from the map")
  _assert_eq(result.asset_id, "ITEM_2007", "the asset id comes from the map")
end

function TestRuntimeAssetsClosure:test_state_skins_returns_the_default_skins_table_after_reset()
  -- kills state.lua's top-level require("src.config.content.skins") -> nil.
  state.reset_for_tests()
  lu.assertEvalToTrue(type(state.skins()) == "table", "default skins must be a table")
end

function TestRuntimeAssetsClosure:test_state_refs_treats_an_opts_table_carrying_images_as_the_refs_source()
  -- kills the refs guard's type()/\"table\" mutants on the images arm.
  local o = { images = { x = 1 } }
  _assert_eq(state.refs(o), o, "opts with an images table is itself the refs source")
end

function TestRuntimeAssetsClosure:test_configure_for_tests_honors_custom_skins_and_startup_item_ids()
  -- kills configure_for_tests' `opts.skins or default_skins` or -> and and
  -- `opts.startup_item_ids or _default_startup_item_ids()` or -> and / call -> nil.
  local custom_skins = { { product_id = 1 } }
  state.configure_for_tests({ skins = custom_skins, startup_item_ids = { 42 } })
  _assert_eq(state.skins(), custom_skins, "custom skins win over defaults")
  _assert_eq(state.startup_item_ids()[1], 42, "custom startup ids win over defaults")
  state.configure_for_tests({})
  _assert_eq(state.startup_item_ids()[1], 3001,
    "configure without startup ids falls back to the defaults")
  state.reset_for_tests()
  _assert_eq(state.startup_item_ids()[1], 3001, "reset restores the default startup ids")
end

function TestRuntimeAssetsClosure:test_image_for_popup_card_routes_item_and_chance_kinds_to_their_meanings()
  -- kills the meaning chain's == -> ~= / literals -> nil / and <-> or.
  local item = images.image_for_popup_card("item_card", 2007, { refs = _refs() })
  _assert_eq(item.meaning, "popup.item_card_image", "item_card meaning pinned")
  local chance = images.image_for_popup_card("chance_card", 2007, { refs = _refs() })
  _assert_eq(chance.meaning, "popup.chance_card_image", "chance_card meaning pinned")
end

function TestRuntimeAssetsClosure:test_image_for_market_item_skips_the_fallback_for_nil_and_empty_display_names()
  -- kills the guard's `or` -> `and` pair and `== ""` -> `== nil`.
  local missing = images.image_for_market_item(9999, nil, { refs = _refs() })
  _assert_eq(missing.ok, false, "an unmapped product stays missing")
  _assert_eq(missing.primary_lookup_key, nil, "nil display name never falls back")
  local empty = images.image_for_market_item(9999, "", { refs = _refs() })
  _assert_eq(empty.primary_lookup_key, nil, "empty display name never falls back")
  _assert_eq(empty.lookup_key, "9999", "the primary lookup key is the product id")
end

function TestRuntimeAssetsClosure:test_image_for_market_item_marks_a_successful_display_name_fallback()
  -- kills `fallback.ok == true` == -> ~= and true -> false.
  -- also kills L33 market.item_icon -> nil (fallback path meaning).
  local result = images.image_for_market_item(9999, "2007", { refs = _refs() })
  _assert_eq(result.ok, true, "the display-name fallback resolves")
  _assert_eq(result.meaning, "market.item_icon", "fallback meaning still pinned")
  _assert_eq(result.fallback_used, true, "a successful fallback is marked")
  _assert_eq(result.primary_lookup_key, "9999", "the primary lookup key is recorded")
end

function TestRuntimeAssetsClosure:test_image_for_market_item_fallback_missing_path_pins_meaning_and_reason()
  -- kills L33 market.item_icon -> nil and missing_market_item_icon -> nil on the
  -- fallback missing path (both product_id and display_name not in images).
  local result = images.image_for_market_item(9999, "unknown_name", { refs = _refs() })
  _assert_eq(result.ok, false, "fallback missing rejects")
  _assert_eq(result.meaning, "market.item_icon", "fallback missing meaning pinned")
  _assert_eq(result.reason, "missing_market_item_icon", "fallback missing reason pinned")
  _assert_eq(result.lookup_key, "unknown_name", "fallback lookup key is the display name")
  _assert_eq(result.primary_lookup_key, "9999", "primary lookup key is recorded")
end

function TestRuntimeAssetsClosure:test_default_skin_model_reports_missing_instead_of_nil_without_a_default_creature()
  -- kills the `results.missing(...)` call -> nil and skin.default_model -> nil (L68).
  local result = images.default_skin_model({ refs = {} })
  lu.assertEvalToTrue(type(result) == "table", "a missing default model yields a result table")
  _assert_eq(result.ok, false, "missing default model is not ok")
  _assert_eq(result.meaning, "skin.default_model", "missing default model meaning still pinned")
  _assert_eq(result.reason, "missing_default_skin_model", "missing reason pinned")
end

function TestRuntimeAssetsClosure:test_image_wrappers_pin_meaning_on_both_success_and_missing_paths()
  -- kills meaning string -> nil survivors: item.icon / chance.icon / skin.card_image /
  -- empty.image / market.item_icon.
  -- also kills reason string -> nil survivors: missing_item_icon / missing_chance_card_icon /
  -- missing_empty_image / missing_market_item_icon /
  -- missing_popup_card_image.
  local opts = { refs = _refs() }

  -- item / chance / skin card images (success via 2007 in _refs().images)
  _assert_eq(images.image_for_item(2007, opts).meaning, "item.icon", "item meaning pinned")
  _assert_eq(images.image_for_chance_card(2007, opts).meaning, "chance.icon", "chance meaning pinned")
  _assert_eq(images.image_for_skin_card(2007, opts).meaning, "skin.card_image", "skin card meaning pinned")

  -- missing paths for item / chance — reason assertions
  local missing_item = images.image_for_item(9999, opts)
  _assert_eq(missing_item.meaning, "item.icon", "missing item meaning still pinned")
  _assert_eq(missing_item.reason, "missing_item_icon", "missing item reason pinned")
  local missing_chance = images.image_for_chance_card(9999, opts)
  _assert_eq(missing_chance.meaning, "chance.icon", "missing chance meaning still pinned")
  _assert_eq(missing_chance.reason, "missing_chance_card_icon", "missing chance reason pinned")

  -- empty image (Empty not in _refs().images → missing path; meaning + reason both pinned)
  local empty = images.empty_image(opts)
  _assert_eq(empty.meaning, "empty.image", "empty image meaning pinned")
  _assert_eq(empty.reason, "missing_empty_image", "empty image missing reason pinned")

  -- market item success + missing paths
  _assert_eq(images.image_for_market_item(2007, "any", opts).meaning,
    "market.item_icon", "market item meaning pinned")
  local missing_market = images.image_for_market_item(9999, nil, opts)
  _assert_eq(missing_market.meaning, "market.item_icon",
    "missing market item meaning still pinned")
  _assert_eq(missing_market.reason, "missing_market_item_icon",
    "missing market item reason pinned")


  -- popup card missing path (reason "missing_popup_card_image" not covered when image resolves)
  local missing_popup = images.image_for_popup_card("item_card", 9999, opts)
  _assert_eq(missing_popup.reason, "missing_popup_card_image",
    "missing popup card reason pinned")
  _assert_eq(missing_popup.meaning, "popup.item_card_image",
    "missing popup meaning still pinned")
end

function TestRuntimeAssetsClosure:test_startup_item_slot_icon_pins_meaning_and_reason()
  -- kills ui.startup_item_slot_icon -> nil and missing_startup_item_icon -> nil.
  state.configure_for_tests({ startup_item_ids = { 2007 } })
  local result = images.startup_item_slot_icon(1, { refs = _refs() })
  _assert_eq(result.meaning, "ui.startup_item_slot_icon", "startup slot meaning pinned")
  _assert_eq(result.ok, true, "startup slot icon resolves")
  local missing = images.startup_item_slot_icon(99, { refs = _refs() })
  _assert_eq(missing.meaning, "ui.startup_item_slot_icon", "missing slot meaning still pinned")
  _assert_eq(missing.reason, "missing_startup_item_icon", "missing slot reason pinned")
  state.reset_for_tests()
end

function TestRuntimeAssetsClosure:test_skin_model_for_product_pins_meaning_reason_and_fallback_used()
  -- kills skin.model -> nil (L54/L58), missing_skin_model -> nil (L54),
  -- and false -> true (L61 fallback_used).
  local success = images.skin_model_for_product("5001",
    { refs = { skins = { ["5001"] = "MODEL_5001" } } })
  _assert_eq(success.meaning, "skin.model", "skin model meaning pinned")
  _assert_eq(success.fallback_used, false, "skin model fallback_used is false on success")
  _assert_eq(success.ok, true, "skin model resolves")
  local missing = images.skin_model_for_product(9999, { refs = {} })
  _assert_eq(missing.meaning, "skin.model", "missing skin model meaning still pinned")
  _assert_eq(missing.reason, "missing_skin_model", "missing skin model reason pinned")
  _assert_eq(missing.ok, false, "missing skin model rejects")
end

function TestRuntimeAssetsClosure:test_default_skin_model_pins_meaning_and_fallback_used_on_success()
  -- kills skin.default_model -> nil (L68/L70) and false -> true (L72 fallback_used).
  -- The missing path is already covered by test_default_skin_model_reports_missing...
  local result = images.default_skin_model({ refs = { default_creature = "MODEL_X" } })
  _assert_eq(result.meaning, "skin.default_model", "default skin model meaning pinned")
  _assert_eq(result.fallback_used, false, "default skin model fallback_used is false")
  _assert_eq(result.ok, true, "default skin model resolves")
end
function TestRuntimeAssetsClosure:test_asset_context_treats_an_empty_table_as_no_override()
  -- 黑市道具图回归:init_ui_assets 写入的空 runtime_asset_context 不得遮蔽
  -- 默认 refs —— popup/atlas 靠 state.refs 空表落穿到默认不受影响,但 market 的
  -- _asset_opts 会把空表包装成空 images;空表须在 asset_context 归一为 nil。
  _assert_eq(state.asset_context({ runtime_asset_context = {} }), nil,
    "an empty context table is no override")
  local populated = { images = { x = 1 } }
  _assert_eq(state.asset_context({ runtime_asset_context = populated }), populated,
    "a populated context passes through")
  _assert_eq(state.asset_context({}), nil, "a state without the field stays nil")
  _assert_eq(state.asset_context(nil), nil, "a nil root state stays nil")
end


return TestRuntimeAssetsClosure
