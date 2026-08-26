local lu = require("luaunit")
local cue_refs = require("src.ui.render.board_feedback.cue_refs")
local logger = require("src.foundation.log")

-- cue_refs warns through logger.warn; capture the calls so the resolution
-- branches (precedence, missing-ref dedup, allow_missing) are observable.
local function _capture_warns(fn)
  local saved = logger.warn
  local calls = {}
  logger.warn = function(...)
    calls[#calls + 1] = { ... }
  end
  local ok, err = pcall(fn, calls)
  logger.warn = saved
  assert(ok, err)
  return calls
end

local function _has_arg(call, needle)
  for _, value in ipairs(call) do
    if value == needle then
      return true
    end
  end
  return false
end

-- Join all warn call args into a single string for content matching.
local function _warn_text(call)
  local parts = {}
  for _, v in ipairs(call) do
    parts[#parts + 1] = tostring(v)
  end
  return table.concat(parts, " ")
end

TestBoardFeedbackCueRefs = {}

function TestBoardFeedbackCueRefs:test_prefers_the_explicit_payload_id_over_cue_config_and_lookup_keys()
  local id = cue_refs.resolve_cue_ref_id(
    "sparkle",
    { effect_id = 7, effect_lookup_key = "spark" },
    { effect_id = 99 },
    "effect"
  )
  lu.assertEvalToTrue(id == 99, "explicit payload id must win, got " .. tostring(id))
end

function TestBoardFeedbackCueRefs:test_falls_back_to_the_cue_id_when_the_payload_omits_it()
  local id = cue_refs.resolve_cue_ref_id("sparkle", { effect_id = 42 }, nil, "effect")
  lu.assertEvalToTrue(id == 42, "cue id should resolve when payload absent, got " .. tostring(id))
end

function TestBoardFeedbackCueRefs:test_resolves_the_lookup_key_from_the_payload_ref_ahead_of_the_cue_lookup_key()
  local calls = _capture_warns(function()
    local id = cue_refs.resolve_cue_ref_id(
      "sparkle",
      { effect_lookup_key = "cue_ref" },
      { effect_id_ref = "payload_ref" },
      "effect"
    )
    lu.assertEvalToTrue(id == nil, "an unconfigured lookup ref resolves to nil")
  end)
  lu.assertEvalToTrue(#calls == 1, "the missing payload-provided ref should warn once")
  lu.assertEvalToTrue(_has_arg(calls[1], "effect_id_ref=payload_ref"),
    "the warned ref should be the payload ref, not the cue lookup key")
end

function TestBoardFeedbackCueRefs:test_warns_exactly_once_for_a_repeated_identical_missing_ref()
  local calls = _capture_warns(function()
    cue_refs.resolve_cue_ref_id("sparkle", { sound_lookup_key = "echo_once" }, nil, "sound")
    cue_refs.resolve_cue_ref_id("sparkle", { sound_lookup_key = "echo_once" }, nil, "sound")
  end)
  lu.assertEvalToTrue(#calls == 1, "an identical missing ref must warn only once, got " .. tostring(#calls))
end

function TestBoardFeedbackCueRefs:test_skips_an_empty_lookup_key_warning_unless_allow_missing_is_set()
  local warned = _capture_warns(function()
    local id = cue_refs.resolve_cue_ref_id("quiet", { effect_lookup_key = "" }, nil, "effect")
    lu.assertEvalToTrue(id == nil, "an empty lookup key resolves to nil")
  end)
  lu.assertEvalToTrue(#warned == 1, "a missing lookup key without allow_missing should warn")

  local silent = _capture_warns(function()
    local id = cue_refs.resolve_cue_ref_id(
      "quiet",
      { effect_lookup_key = "", allow_missing = true },
      nil,
      "effect"
    )
    lu.assertEvalToTrue(id == nil, "an empty lookup key still resolves to nil with allow_missing")
  end)
  lu.assertEvalToTrue(#silent == 0, "allow_missing should suppress the missing-lookup warning")
end

function TestBoardFeedbackCueRefs:test_uses_effect_prefix_play_sfx_by_key_for_effect_kind()
  -- Regression for --mutate ==→~= and string→nil at L30:
  -- the ternary `kind == "effect" and "skip play_sfx_by_key:" or "skip play_3d_sound:"`
  -- must produce the effect prefix when kind is "effect".
  local calls = _capture_warns(function()
    cue_refs.warn_missing_ref_once("effect", "fx_cue", "ref_9", "test_reason")
  end)
  lu.assertEvalToTrue(#calls == 1, "should emit one warn")
  local text = _warn_text(calls[1])
  lu.assertEvalToTrue(string.find(text, "play_sfx_by_key", 1, true) ~= nil,
    "effect kind must use sfx prefix")
  lu.assertEvalToTrue(string.find(text, "play_3d_sound", 1, true) == nil,
    "effect kind must NOT use 3d sound prefix")
  lu.assertEvalToTrue(string.find(text, "effect_id_ref=ref_9", 1, true) ~= nil,
    "effect kind must use effect_id_ref label")
end

function TestBoardFeedbackCueRefs:test_uses_sound_prefix_play_3d_sound_for_sound_kind()
  -- Regression for --mutate ==→~= and string→nil at L30:
  -- the ternary must produce the sound prefix when kind is "sound".
  local calls = _capture_warns(function()
    cue_refs.warn_missing_ref_once("sound", "snd_cue", "ref_7", "test_reason")
  end)
  lu.assertEvalToTrue(#calls == 1, "should emit one warn")
  local text = _warn_text(calls[1])
  lu.assertEvalToTrue(string.find(text, "play_3d_sound", 1, true) ~= nil,
    "sound kind must use 3d sound prefix")
  lu.assertEvalToTrue(string.find(text, "play_sfx_by_key", 1, true) == nil,
    "sound kind must NOT use sfx prefix")
  lu.assertEvalToTrue(string.find(text, "sound_id_ref=ref_7", 1, true) ~= nil,
    "sound kind must use sound_id_ref label")
end

function TestBoardFeedbackCueRefs:test_uses_lookback_warning_for_nil_lookup_key_not_skip_cue()
  -- Regression for --mutate or→and at L78:
  -- `type(lookup_key) ~= "string" or lookup_key == ""` → `and`
  -- makes nil lookup_key skip the guard and fall to warn_missing_ref_once
  -- instead of warn("skip cue ..."). Verify the expected warn pathway.
  -- Note: the mutation produces the same observable outcome (a warn),
  -- but by testing with a non-empty non-string value we force divergence.
  local calls = _capture_warns(function()
    local id = cue_refs.resolve_cue_ref_id("nil_test", { effect_lookup_key = 42 }, nil, "effect")
    lu.assertEvalToTrue(id == nil, "non-string lookup key resolves to nil")
  end)
  lu.assertEvalToTrue(#calls == 1, "should warn once for non-string lookup key")
  local text = _warn_text(calls[1])
  lu.assertEvalToTrue(string.find(text, "skip cue effect", 1, true) ~= nil,
    "non-string lookup key must produce skip-cue warning")
end

function TestBoardFeedbackCueRefs:test_pins_the_exact_skip_cue_warn_payload_for_an_empty_lookup_key()
  -- kills L78 ""->nil 与 L80 tostring(cue_name)->nil:空 lookup key 必须走
  -- skip-cue 警告且带着 cue_name;变异体会改走 warn_missing_ref_once 或丢名。
  local calls = _capture_warns(function()
    local id = cue_refs.resolve_cue_ref_id("quiet", { effect_lookup_key = "" }, nil, "effect")
    lu.assertEvalToTrue(id == nil, "an empty lookup key resolves to nil")
  end)
  lu.assertEvalToTrue(#calls == 1, "an empty lookup key without allow_missing should warn once")
  lu.assertEvalToTrue(calls[1][1] == "board_feedback", "warn should carry the board_feedback prefix")
  lu.assertEvalToTrue(calls[1][2] == "skip cue effect with missing effect_id_ref:",
    "empty lookup key must take the skip-cue warn path")
  lu.assertEvalToTrue(calls[1][3] == "quiet", "the skip-cue warn must carry the cue name")
  lu.assertEvalToTrue(#calls[1] == 3, "the skip-cue warn must have exactly three args")
end

function TestBoardFeedbackCueRefs:test_pins_the_exact_missing_ref_warn_payload_including_the_reason()
  -- kills L84 "missing_or_unconfigured"->nil:reason 是载荷的一部分。
  local calls = _capture_warns(function()
    cue_refs.resolve_cue_ref_id(
      "reason_cue",
      { effect_lookup_key = "cue_ref" },
      { effect_id_ref = "payload_ref_reason" },
      "effect"
    )
  end)
  lu.assertEvalToTrue(#calls == 1, "the missing payload-provided ref should warn once")
  lu.assertEvalToTrue(calls[1][1] == "board_feedback", "warn should carry the board_feedback prefix")
  lu.assertEvalToTrue(calls[1][2] == "skip play_sfx_by_key:", "effect kind must use the sfx prefix")
  lu.assertEvalToTrue(calls[1][3] == "cue_name=reason_cue", "warn must carry the cue name label")
  lu.assertEvalToTrue(calls[1][4] == "effect_id_ref=payload_ref_reason", "warn must carry the ref label")
  lu.assertEvalToTrue(calls[1][5] == "reason=missing_or_unconfigured", "warn must carry the reason")
  lu.assertEvalToTrue(#calls[1] == 5, "the missing-ref warn must have exactly five args")
end

function TestBoardFeedbackCueRefs:test_pins_the_exact_invalid_scale_warn_payload()
  -- kills L39 "invalid cue field:"->nil 与 L52 "scale"->nil。
  local calls = _capture_warns(function()
    cue_refs.resolve_sfx_scale("sparkle", "nope", nil)
  end)
  lu.assertEvalToTrue(#calls == 1, "an invalid scale should warn once")
  lu.assertEvalToTrue(calls[1][1] == "board_feedback", "warn should carry the board_feedback prefix")
  lu.assertEvalToTrue(calls[1][2] == "invalid cue field:", "warn must carry the invalid-field label")
  lu.assertEvalToTrue(calls[1][3] == "cue_name=sparkle", "warn must carry the cue name label")
  lu.assertEvalToTrue(calls[1][4] == "field=scale", "warn must name the scale field")
  lu.assertEvalToTrue(calls[1][5] == "value=nope", "warn must carry the offending value")
  lu.assertEvalToTrue(calls[1][6] == "fallback=1.0", "warn must carry the default fallback")
  lu.assertEvalToTrue(#calls[1] == 6, "the invalid-field warn must have exactly six args")
end

function TestBoardFeedbackCueRefs:test_returns_the_resolved_numeric_scale_when_valid()
  lu.assertEvalToTrue(cue_refs.resolve_sfx_scale("sparkle", 2.5, 1.0) == 2.5)
end

function TestBoardFeedbackCueRefs:test_falls_back_to_the_default_scale_of_1_0_and_warns_on_a_non_numeric_value()
  local calls = _capture_warns(function()
    local scale = cue_refs.resolve_sfx_scale("sparkle", "nope", nil)
    lu.assertEvalToTrue(scale == 1.0, "an invalid scale should fall back to 1.0, got " .. tostring(scale))
  end)
  lu.assertEvalToTrue(#calls == 1, "an invalid scale should warn once")
end

function TestBoardFeedbackCueRefs:test_passes_numeric_values_through_and_uses_the_fallback_otherwise()
  lu.assertEvalToTrue(cue_refs.resolve_numeric(3.0, 9.0) == 3.0)
  lu.assertEvalToTrue(cue_refs.resolve_numeric(nil, 9.0) == 9.0)
end


return TestBoardFeedbackCueRefs
