-- canvas_route.market 各闭包的意图规约:build_items / build_controls 的
-- confirm、cancel/close、翻页、tab 切换,L18-L83 行号锚定的字面量捕获。
--
-- 原生 LuaUnit(busted → LuaUnit 迁移):五个 describe 均无钩子,合并拍平为
-- TestCanvasRouteMarketBaseline 单类;含 → 等非 ASCII 的 it 名按「原名逐字
-- 保留」用 table key 赋值写法,ASCII 名转 snake 方法名;裸 assert(cond, msg)
-- 机械映射为 lu.assertEvalToTrue,用例数与改写前一一对应(3+3+1+4+2 = 13 例)。
local lu = require("luaunit")
local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local _with_patches = P.with_patches

local market_route = require("src.ui.screens.market")
local runtime_state = require("src.ui.state.runtime")
local ui_event_intents = require("src.ui.input.event_intents")

local function _find_spec(specs, name)
  for _, spec in ipairs(specs) do
    if spec.name == name then return spec end
  end
  return nil
end

TestCanvasRouteMarketBaseline = {}

function TestCanvasRouteMarketBaseline:test_build_intent_returns_nil_when_resolve_market_returns_nil_model()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return nil end },
  }, function()
    local specs = market_route.build_items({})
    lu.assertEvalToTrue(#specs >= 1, "specs must include item buttons")
    local intent = specs[1].build_intent()
    _assert_eq(intent, nil, "nil model must make build_intent return nil")
  end)
end

function TestCanvasRouteMarketBaseline:test_build_intent_returns_nil_when_model_exists_but_resolve_option_id_returns_nil()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "c1" } } end },
    { target = ui_event_intents, key = "resolve_option_id", value = function() return nil end },
  }, function()
    local specs = market_route.build_items({})
    local intent = specs[1].build_intent()
    _assert_eq(intent, nil, "nil option_id must yield nil intent")
  end)
end

function TestCanvasRouteMarketBaseline:test_build_intent_returns_market_select_intent_with_option_id_when_both_present()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "c1" } } end },
    { target = ui_event_intents, key = "resolve_option_id", value = function(market, opts) return "opt_" .. tostring(opts.index) end },
  }, function()
    local specs = market_route.build_items({})
    local intent = specs[3].build_intent()  -- index 3
    _assert_eq(intent.type, "market_select", "intent.type must be 'market_select' literal")
    _assert_eq(intent.option_id, "opt_3", "option_id must come from resolve_option_id")
  end)
end

TestCanvasRouteMarketBaseline["test_nil market → nil intent"] = function()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return nil end },
    { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
  }, function()
    local specs = market_route.build_controls({})
    local confirm = _find_spec(specs, "黑市_购买按钮")
    lu.assertEvalToTrue(confirm ~= nil, "confirm spec must exist")
    _assert_eq(confirm.build_intent(), nil, "confirm must return nil when no market model")
  end)
end

function TestCanvasRouteMarketBaseline:test_no_selected_option_yields_nil_intent()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return { market = { choice_id = "C" } } end },
    { target = runtime_state, key = "ensure_ui_runtime", value = function() return { pending_choice_selected_option_id = nil } end },
  }, function()
    local specs = market_route.build_controls({})
    local confirm = _find_spec(specs, "黑市_购买按钮")
    _assert_eq(confirm.build_intent(), nil, "missing selected option yields nil")
  end)
end

TestCanvasRouteMarketBaseline["test_full market+option → market_confirm intent with choice_id+option_id"] = function()
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
end

function TestCanvasRouteMarketBaseline:test_cancel_and_close_both_call_choice_cancel_intent_with_market_close()
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
end

-- Targets architect-listed L40 _resolve_market check + L75 "market_page_next" literal capture.
TestCanvasRouteMarketBaseline["test_page_prev intent: nil market → nil"] = function()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return nil end },
    { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
  }, function()
    local specs = market_route.build_controls({})
    local prev_spec = _find_spec(specs, "黑市-上一页箭头")
    _assert_eq(prev_spec.build_intent(), nil, "L40 _resolve_market nil → nil intent")
  end)
end

TestCanvasRouteMarketBaseline["test_page_prev intent: full market → type 'market_page_prev', choice_id from market"] = function()
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
end

TestCanvasRouteMarketBaseline["test_page_next intent: full market → type 'market_page_next', choice_id from market"] = function()
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
end

TestCanvasRouteMarketBaseline["test_page_next intent: nil market → nil (L40 short-circuit in shared closure)"] = function()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return nil end },
    { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
  }, function()
    local specs = market_route.build_controls({})
    local next_spec = _find_spec(specs, "黑市-下一页箭头")
    _assert_eq(next_spec.build_intent(), nil, "L40 nil model in next closure → nil intent")
  end)
end

TestCanvasRouteMarketBaseline["test_nil market → nil (L80 _resolve_market)"] = function()
  _with_patches({
    { target = runtime_state, key = "get_ui_model", value = function() return nil end },
    { target = runtime_state, key = "ensure_ui_runtime", value = function() return {} end },
  }, function()
    local specs = market_route.build_controls({})
    local tab_spec = _find_spec(specs, "黑市-道具商店按钮")
    _assert_eq(tab_spec.build_intent(), nil, "L80 nil model → nil intent")
  end)
end

TestCanvasRouteMarketBaseline["test_full market → type 'market_tab_select' (L82) with tab='item' (L82) literal"] = function()
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
end


return TestCanvasRouteMarketBaseline
