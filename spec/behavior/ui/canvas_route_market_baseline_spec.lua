local P = require("spec.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local market_route = require("src.ui.input.canvas_route.market")
local runtime_state = require("src.ui.state.runtime")
local ui_event_intents = require("src.ui.input.event_intents")

local function _find_spec(specs, name)
  for _, spec in ipairs(specs) do
    if spec.name == name then return spec end
  end
  return nil
end

describe("canvas_route.market build_items L18-L27", function()
  it("build_intent returns nil when _resolve_market returns nil model", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return nil end },
    }, function()
      local specs = market_route.build_items({})
      assert(#specs >= 1, "specs must include item buttons")
      local intent = specs[1].build_intent()
      _assert_eq(intent, nil, "nil model must make build_intent return nil")
    end)
  end)

  it("build_intent returns nil when model exists but resolve_option_id returns nil", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "c1" } } end },
      { target = ui_event_intents, key = "resolve_option_id", value = function() return nil end },
    }, function()
      local specs = market_route.build_items({})
      local intent = specs[1].build_intent()
      _assert_eq(intent, nil, "nil option_id must yield nil intent")
    end)
  end)

  it("build_intent returns market_select intent with option_id when both present", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "c1" } } end },
      { target = ui_event_intents, key = "resolve_option_id", value = function(market, opts) return "opt_" .. tostring(opts.index) end },
    }, function()
      local specs = market_route.build_items({})
      local intent = specs[3].build_intent()  -- index 3
      _assert_eq(intent.type, "market_select", "intent.type must be 'market_select' literal")
      _assert_eq(intent.option_id, "opt_3", "option_id must come from resolve_option_id")
    end)
  end)
end)

describe("canvas_route.market build_controls confirm closure (L49-L59)", function()
  it("nil market → nil intent", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return nil end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local confirm = _find_spec(specs, "黑市_购买按钮")
      assert(confirm ~= nil, "confirm spec must exist")
      _assert_eq(confirm.build_intent(), nil, "confirm must return nil when no market model")
    end)
  end)

  it("no selected option yields nil intent", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "C" } } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return { pending_choice_selected_option_id = nil } end },
    }, function()
      local specs = market_route.build_controls({})
      local confirm = _find_spec(specs, "黑市_购买按钮")
      _assert_eq(confirm.build_intent(), nil, "missing selected option yields nil")
    end)
  end)

  it("full market+option → market_confirm intent with choice_id+option_id", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "CID-9" } } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return { pending_choice_selected_option_id = "OID-7" } end },
    }, function()
      local specs = market_route.build_controls({})
      local confirm = _find_spec(specs, "黑市_购买按钮")
      local intent = confirm.build_intent()
      _assert_eq(intent.type, "market_confirm", "intent.type must be 'market_confirm' literal")
      _assert_eq(intent.choice_id, "CID-9", "choice_id from market")
      _assert_eq(intent.option_id, "OID-7", "option_id from runtime")
    end)
  end)
end)

describe("canvas_route.market build_controls cancel/close closure (L34-L36)", function()
  it("cancel and close both call choice_cancel_intent with 'market_close'", function()
    local cancel_calls = {}
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = {} } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
      { target = ui_event_intents, key = "choice_cancel_intent", value = function(_, reason)
        cancel_calls[#cancel_calls + 1] = reason
        return { type = "choice_cancel", reason = reason }
      end },
    }, function()
      local specs = market_route.build_controls({})
      local cancel_spec = _find_spec(specs, "黑市_取消按钮")
      local close_spec = _find_spec(specs, "黑市_关闭")
      cancel_spec.build_intent()
      close_spec.build_intent()
    end)
    _assert_eq(#cancel_calls, 2, "cancel + close both call choice_cancel_intent")
    _assert_eq(cancel_calls[1], "market_close", "reason 'market_close' literal must surface")
    _assert_eq(cancel_calls[2], "market_close", "reason 'market_close' literal stable across both")
  end)
end)

describe("canvas_route.market _build_choice_intent closure (L38-L44)", function()
  -- Targets architect-listed L40 _resolve_market check + L75 "market_page_next" literal capture.

  it("page_prev intent: nil market → nil", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return nil end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local prev_spec = _find_spec(specs, "黑市-上一页箭头")
      _assert_eq(prev_spec.build_intent(), nil, "L40 _resolve_market nil → nil intent")
    end)
  end)

  it("page_prev intent: full market → type 'market_page_prev', choice_id from market", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "PrevCID" } } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local prev_spec = _find_spec(specs, "黑市-上一页箭头")
      local intent = prev_spec.build_intent()
      _assert_eq(intent.type, "market_page_prev", "type must be 'market_page_prev' literal")
      _assert_eq(intent.choice_id, "PrevCID", "choice_id from market")
    end)
  end)

  it("page_next intent: full market → type 'market_page_next', choice_id from market", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "NextCID" } } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local next_spec = _find_spec(specs, "黑市-下一页箭头")
      local intent = next_spec.build_intent()
      _assert_eq(intent.type, "market_page_next",
        "L75 _build_choice_intent('market_page_next') literal must surface as intent.type")
      _assert_eq(intent.choice_id, "NextCID", "choice_id from market")
    end)
  end)

  it("page_next intent: nil market → nil (L40 short-circuit in shared closure)", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return nil end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local next_spec = _find_spec(specs, "黑市-下一页箭头")
      _assert_eq(next_spec.build_intent(), nil, "L40 nil model in next closure → nil intent")
    end)
  end)
end)

describe("canvas_route.market tab_item closure L79-L83", function()
  it("nil market → nil (L80 _resolve_market)", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return nil end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local tab_spec = _find_spec(specs, "黑市-道具商店按钮")
      _assert_eq(tab_spec.build_intent(), nil, "L80 nil model → nil intent")
    end)
  end)

  it("full market → type 'market_tab_select' (L82) with tab='item' (L82) literal", function()
    _with_patches({
      { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "TabCID" } } end },
      { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
    }, function()
      local specs = market_route.build_controls({})
      local tab_spec = _find_spec(specs, "黑市-道具商店按钮")
      local intent = tab_spec.build_intent()
      _assert_eq(intent.type, "market_tab_select", "L82 literal 'market_tab_select' must surface")
      _assert_eq(intent.tab, "item", "L82 literal 'item' must surface as tab")
      _assert_eq(intent.choice_id, "TabCID", "choice_id from market")
    end)
  end)
end)
