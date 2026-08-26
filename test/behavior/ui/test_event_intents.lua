local lu = require("luaunit")
local event_intents = require("src.ui.input.event_intents")

-- warn_label 用 spec_synthetic：负路径 warn 文案带保留前缀，
-- 由 test/support/behavior_warns_data.lua 白名单整体豁免。

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_state(opts)
  opts = opts or {}
  return {
    ui_runtime = {
      ui_model = opts.model,
      pending_choice_selected_option_id = opts.selected_option,
      choice_visible_option_ids = opts.visible_ids,
    },
  }
end

TestEventIntents = {}

function TestEventIntents:test_returns_nil_when_no_choice_in_model()
  local state = _make_state({ model = {} })
  local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
  lu.assertEvalToTrue(result == nil, "should return nil when no choice")
end

function TestEventIntents:test_returns_choice_select_with_pending_option()
  local state = _make_state({
    model = { choice = { id = "c1" } },
    selected_option = "opt_a",
  })
  local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
  lu.assertEvalToTrue(result ~= nil, "should return intent")
  _assert_eq(result.type, "choice_select", "type")
  _assert_eq(result.choice_id, "c1", "choice_id")
  _assert_eq(result.option_id, "opt_a", "option_id")
end

function TestEventIntents:test_falls_back_to_first_visible_option_when_no_pending()
  local state = _make_state({
    model = { choice = { id = "c2" } },
    visible_ids = { "first", "second" },
  })
  local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
  lu.assertEvalToTrue(result ~= nil, "should return intent")
  _assert_eq(result.option_id, "first", "should use first visible option")
end

function TestEventIntents:test_returns_nil_when_no_pending_and_no_visible_options()
  local state = _make_state({
    model = { choice = { id = "c3" } },
  })
  local result = event_intents.choice_confirm_intent(state, "spec_synthetic")
  lu.assertEvalToTrue(result == nil, "should return nil when no option available")
end

function TestEventIntents:test_returns_nil_when_no_choice()
  local state = _make_state({ model = {} })
  lu.assertEvalToTrue(event_intents.choice_cancel_intent(state, "spec_synthetic") == nil,
    "should return nil without choice")
end

function TestEventIntents:test_returns_cancel_intent_when_allowed()
  local state = _make_state({ model = { choice = { id = "c1" } } })
  local result = event_intents.choice_cancel_intent(state, "spec_synthetic")
  lu.assertEvalToTrue(result ~= nil, "should return intent")
  _assert_eq(result.type, "choice_cancel", "type")
  _assert_eq(result.choice_id, "c1", "choice_id")
end

function TestEventIntents:test_returns_nil_when_cancel_disallowed()
  local state = _make_state({ model = { choice = { id = "c1", allow_cancel = false } } })
  lu.assertEvalToTrue(event_intents.choice_cancel_intent(state, "spec_synthetic") == nil,
    "should return nil when allow_cancel is false")
end

function TestEventIntents:test_returns_the_option_id_carried_directly_on_the_payload()
  local choice = { id = "c1", options = { { id = "o1" } } }
  local result = event_intents.resolve_option_id(choice, { option_id = "opt_a" }, nil)
  _assert_eq(result, "opt_a", "payload option_id wins over index lookup")
end

function TestEventIntents:test_accepts_the_legacy_option_payload_key()
  local choice = { id = "c1", options = { { id = "o1" } } }
  local result = event_intents.resolve_option_id(choice, { option = "opt_b" }, nil)
  _assert_eq(result, "opt_b", "payload option key")
end

function TestEventIntents:test_falls_back_to_the_choice_option_at_the_payload_index()
  local choice = { id = "c1", options = { { id = "o1" }, { id = "o2" } } }
  local result = event_intents.resolve_option_id(choice, { index = 2 }, nil)
  _assert_eq(result, "o2", "option resolved by index")
end

function TestEventIntents:test_returns_nil_when_the_payload_carries_neither_an_option_id_nor_an_index()
  local choice = { id = "c1", options = { { id = "o1" } } }
  lu.assertEvalToTrue(event_intents.resolve_option_id(choice, {}, nil) == nil,
    "should return nil for an empty payload")
end

function TestEventIntents:test_returns_nil_when_no_choice_2()
  local state = _make_state({ model = {} })
  lu.assertEvalToTrue(event_intents.choice_select_intent(state, 1, "spec_synthetic") == nil,
    "should return nil without choice")
end

function TestEventIntents:test_returns_select_intent_by_index_via_visible_ids()
  local state = _make_state({
    model = { choice = { id = "c1", options = {} } },
    visible_ids = { "opt_x", "opt_y" },
  })
  local result = event_intents.choice_select_intent(state, 1, "spec_synthetic")
  lu.assertEvalToTrue(result ~= nil, "should return intent")
  _assert_eq(result.type, "choice_select", "type")
  _assert_eq(result.option_id, "opt_x", "option_id")
end

function TestEventIntents:test_returns_select_intent_by_index_via_choice_options()
  local state = _make_state({
    model = { choice = { id = "c1", options = { { id = "o1" }, { id = "o2" } } } },
  })
  local result = event_intents.choice_select_intent(state, 2, "spec_synthetic")
  lu.assertEvalToTrue(result ~= nil, "should return intent")
  _assert_eq(result.option_id, "o2", "option_id from choice options")
end

function TestEventIntents:test_resolves_option_index_payload_key()
  -- kills _resolve_index_from_payload 第二段 or->and:payload 只带
  -- option_index 时必须经索引命中对应 option(变异体会把链压成 nil)。
  local choice = { id = "c1", options = { { id = "o1" }, { id = "o2" }, { id = "o3" } } }
  local state = _make_state({})
  local option_id = event_intents.resolve_option_id(choice, { option_index = 3 }, state)
  _assert_eq(option_id, "o3", "option_index payload should resolve the option at that index")
end

function TestEventIntents:test_resolves_card_index_and_choice_index_payload_keys()
  -- kills _resolve_index_from_payload 第三段 or->and:card_index /
  -- choice_index 任一存在时都必须参与索引解析。
  local choice = { id = "c1", options = { { id = "o1" }, { id = "o2" }, { id = "o3" } } }
  local state = _make_state({})
  local via_card = event_intents.resolve_option_id(choice, { card_index = 2 }, state)
  _assert_eq(via_card, "o2", "card_index payload should resolve the option at that index")
  local via_choice = event_intents.resolve_option_id(choice, { choice_index = 1 }, state)
  _assert_eq(via_choice, "o1", "choice_index payload should resolve the option at that index")
end

function TestEventIntents:test_resolve_option_id_rejects_missing_choice_and_payload_with_messages()
  -- #293: L44/L45 assert 消息变异(消息串翻 nil)——缺 choice / 缺 payload 必须
  -- 报出标识消息。
  local luax = require("test.support.luax")
  local support = require("test.support.shared_support")
  local logger = require("src.foundation.log")
  local state = _make_state({})
  support.with_patches({
    { target = logger, key = "warn", value = function() end },
  }, function()
    luax.has_error(function()
      event_intents.resolve_option_id(nil, { option_id = "o1" }, state)
    end, "missing choice")
    luax.has_error(function()
      event_intents.resolve_option_id({ id = "c1" }, nil, state)
    end, "missing payload")
  end)
end

function TestEventIntents:test_choice_select_does_not_warn_when_choice_present()
  -- #293: L60 _resolve_choice_or_warn 的 not 变异(choice 存在时也 warn)——有
  -- choice 的路径必须零告警。
  local support = require("test.support.shared_support")
  local logger = require("src.foundation.log")
  local warns = {}
  local choice = { id = "c1", options = { { id = "o1" } } }
  local state = _make_state({ model = { choice = choice } })
  support.with_patches({
    { target = logger, key = "warn", value = function(...) warns[#warns + 1] = table.concat({ ... }, " ") end },
  }, function()
    local result = event_intents.choice_select_intent(state, 1, "spec_synthetic")
    _assert_eq(result and result.option_id, "o1", "select intent should resolve the option")
    _assert_eq(#warns, 0, "a present choice must not warn")
  end)
end

function TestEventIntents:test_choice_select_warns_missing_option_with_index()
  -- #293: L84 的日志字符串与 tostring(index) 变异——索引解析不出 option 时
  -- 告警必须带上索引。
  local support = require("test.support.shared_support")
  local logger = require("src.foundation.log")
  local warns = {}
  local choice = { id = "c1", options = {} }
  local state = _make_state({ model = { choice = choice } })
  support.with_patches({
    { target = logger, key = "warn", value = function(...) warns[#warns + 1] = table.concat({ ... }, " ") end },
  }, function()
    local result = event_intents.choice_select_intent(state, 7, "spec_synthetic")
    _assert_eq(result, nil, "an unresolvable index yields no intent")
    _assert_eq(#warns, 1, "an unresolvable index must warn")
    lu.assertEvalToTrue(warns[1]:find("missing option", 1, true) ~= nil, "warn must identify 'missing option'")
    lu.assertEvalToTrue(warns[1]:find("7", 1, true) ~= nil, "warn must carry the missing index")
  end)
end


return TestEventIntents
