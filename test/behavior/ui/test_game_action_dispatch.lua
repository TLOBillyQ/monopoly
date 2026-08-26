-- game_action.lua 直测：分发管线各分支(slot_command 登记、auto 按钮归一化、market
-- key 校验与 payload、pre-confirm source 门控与 handler、basic 转发、回落)。
-- 宿主无关：依赖(pre_confirm_flow / item_phase_ask_flow / pending_confirmation /
-- command_policy)均为纯状态或端口解析,端口经 state 注入。
local lu = require("luaunit")

local game_action = require("src.ui.input.game_action")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local highlight_lifecycle = require("src.ui.state.item_slot_highlight_lifecycle_queue")

TestGameActionDispatch = {}

local function _port(dispatched)
  return {
    dispatch_action = function(_, _, intent)
      dispatched.called = (dispatched.called or 0) + 1
      dispatched.intent = intent
    end,
  }
end

-- dispatch 主入口:nil intent 回落(false),不能索引 nil。
function TestGameActionDispatch:test_dispatch_nil_intent_falls_back()
  local result = game_action.dispatch({}, {}, nil, {}, _port({}))
  lu.assertEvalToTrue(result == false, "nil intent must fall through")
end

-- _register_slot_command:item_slot 点击登记 slot_command 生命周期事件
-- (#595:解冻不再靠清扁平旗标隐式表达)。
function TestGameActionDispatch:test_item_slot_click_queues_slot_command()
  local state = {}
  local result = game_action.dispatch(state, {}, {
    type = "item_slot_click", item_slot = true, game_handler = "basic", choice_id = "c1",
  }, {}, _port({}))

  local queued = highlight_lifecycle.drain(state)
  lu.assertEvalToTrue(queued ~= nil and #queued == 1,
    "an item-slot click queues exactly one lifecycle event")
  lu.assertEvalToTrue(queued[1].kind == "slot_command",
    "the queued event is a slot_command unfreeze")
  lu.assertEvalToTrue(tostring(queued[1].choice_id) == "c1",
    "the slot_command carries the choice it acted on")
  lu.assertEvalToTrue(result == true, "a basic item-slot intent is handled")
end

function TestGameActionDispatch:test_non_item_slot_intent_queues_no_lifecycle_event()
  local state = {}
  game_action.dispatch(state, {}, { type = "ui_button", id = "auto", game_handler = "basic" },
    {}, _port({}), { normalize_auto_intent = function(i) return i end })

  lu.assertEvalToTrue(highlight_lifecycle.drain(state) == nil,
    "non-slot intents queue no lifecycle event")
end

-- auto 按钮:normalize 返回 nil 时吞掉(不 dispatch),返回 action 时转发。
function TestGameActionDispatch:test_auto_button_with_nil_normalization_is_swallowed()
  local dispatched = {}
  local result = game_action.dispatch({}, {},
    { type = "ui_button", id = "auto", game_handler = "basic" }, {},
    _port(dispatched), { normalize_auto_intent = function() return nil end })

  lu.assertEvalToTrue(result == true, "auto button with nil normalization is consumed")
  lu.assertEvalToTrue(dispatched.called == nil, "nothing must reach the action port")
end

function TestGameActionDispatch:test_auto_button_forwards_normalized_action()
  local dispatched = {}
  local action = { type = "auto_moved" }
  local result = game_action.dispatch({}, {},
    { type = "ui_button", id = "auto", game_handler = "basic" }, {},
    _port(dispatched), { normalize_auto_intent = function() return action end })

  lu.assertEvalToTrue(result == true, "auto button with a normalized action is handled")
  lu.assertEvalToTrue(dispatched.intent == action, "the normalized action must be dispatched")
end

-- market key 校验:缺 key warn 并吞掉,不 dispatch。
function TestGameActionDispatch:test_market_page_prev_missing_choice_id_is_swallowed()
  local dispatched = {}
  local result = game_action.dispatch({}, {},
    { type = "market_page_prev", game_handler = "market_page_prev" }, {},
    _port(dispatched))

  lu.assertEvalToTrue(result == true, "a market intent missing its key is consumed")
  lu.assertEvalToTrue(dispatched.called == nil, "no dispatch when a required key is missing")
end

-- market payload:全 key 时按 action_type 构建并透传 actor_role_id + keys。
function TestGameActionDispatch:test_market_tab_select_builds_payload_with_keys()
  local dispatched = {}
  local result = game_action.dispatch({}, {},
    { type = "market_tab_select", game_handler = "market_tab_select",
      choice_id = 3, tab = "equipment", actor_role_id = 2 }, {},
    _port(dispatched))

  lu.assertEvalToTrue(result == true, "a full-key market intent is handled")
  lu.assertEvalToTrue(dispatched.intent.type == "market_tab_select", "payload keeps the action type")
  lu.assertEvalToTrue(dispatched.intent.actor_role_id == 2, "actor_role_id must pass through")
  lu.assertEvalToTrue(dispatched.intent.choice_id == 3 and dispatched.intent.tab == "equipment",
    "required keys must pass through into the payload")
end

-- pre-confirm:source 未激活时 choice_select 回落 basic 转发。
function TestGameActionDispatch:test_choice_select_without_active_source_falls_back()
  local dispatched = {}
  local intent = { type = "choice_select", game_handler = "basic" }
  local result = game_action.dispatch({}, {}, intent, {}, _port(dispatched))

  lu.assertEvalToTrue(result == true, "a choice_select intent without an active source still routes")
  lu.assertEvalToTrue(dispatched.intent == intent, "the basic route must forward the intent")
  lu.assertEvalToTrue(dispatched.called == 1, "the intent must be dispatched exactly once")
end

-- pre-confirm:choice_select + source 激活 → confirm 后 dispatch 恰好一次。
function TestGameActionDispatch:test_choice_select_confirms_and_dispatches_when_source_active()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {})
  local dispatched = {}
  local intent = { type = "choice_select", game_handler = "basic" }
  local result = game_action.dispatch(state, {}, intent, {}, _port(dispatched))

  lu.assertEvalToTrue(result == true, "choice_select with an active source is handled")
  lu.assertEvalToTrue(dispatched.intent == intent, "the intent must be dispatched after confirm")
  lu.assertEvalToTrue(dispatched.called == 1, "the handler must dispatch exactly once")
  lu.assertEvalToTrue(pending_confirmation.is_active(state) == false,
    "confirm must clear the pending confirmation")
end

-- item_phase_ask 只拦 choice_select/choice_cancel:item_phase source 激活时
-- 普通 intent 不被劫持,pre-confirm 门控(CHOICE_SELECT 未激活)回落 basic。
function TestGameActionDispatch:test_item_phase_source_does_not_hijack_plain_intents()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK, {})
  local dispatched = {}
  local intent = { type = "ui_button", id = "auto", game_handler = "basic" }
  local result = game_action.dispatch(state, {}, intent, {}, _port(dispatched),
    { normalize_auto_intent = function(i) return i end })

  lu.assertEvalToTrue(result == true, "an item-phase source must not hijack a plain intent")
  lu.assertEvalToTrue(dispatched.called == 1, "the fallback basic route must dispatch exactly once")
  lu.assertEvalToTrue(pending_confirmation.is_item_phase_confirmed(state) == false,
    "the pre-confirm handler must not run while an item-phase source is active")
end

-- pre-confirm:choice_cancel → cancel 流程(不 dispatch)。
function TestGameActionDispatch:test_choice_cancel_runs_the_cancel_flow()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_CHOICE_SELECT, {})
  local dispatched = {}
  local result = game_action.dispatch(state, {}, { type = "choice_cancel" }, {}, _port(dispatched))

  lu.assertEvalToTrue(result == true, "choice_cancel is handled")
  lu.assertEvalToTrue(dispatched.called == nil, "cancel must not dispatch an action")
  lu.assertEvalToTrue(pending_confirmation.is_active(state) == false,
    "cancel must clear the pending confirmation")
end

-- market_page_prev 全 key:action_type 字面量进 payload。
function TestGameActionDispatch:test_market_page_prev_full_keys_keeps_action_type()
  local dispatched = {}
  local result = game_action.dispatch({}, {},
    { type = "market_page_prev", game_handler = "market_page_prev", choice_id = 5 }, {},
    _port(dispatched))

  lu.assertEvalToTrue(result == true, "a full-key page intent is handled")
  lu.assertEvalToTrue(dispatched.intent.type == "market_page_prev", "page_prev action type must survive")
  lu.assertEvalToTrue(dispatched.intent.choice_id == 5, "choice_id must pass through")
end

-- market_page_next 全 key:另一条字面量分支。
function TestGameActionDispatch:test_market_page_next_full_keys_keeps_action_type()
  local dispatched = {}
  local result = game_action.dispatch({}, {},
    { type = "market_page_next", game_handler = "market_page_next", choice_id = 6 }, {},
    _port(dispatched))

  lu.assertEvalToTrue(result == true, "a full-key page intent is handled")
  lu.assertEvalToTrue(dispatched.intent.type == "market_page_next", "page_next action type must survive")
end

-- ui_button 但 id 非 auto:不走 normalize,原样转发。
function TestGameActionDispatch:test_ui_button_other_than_auto_skips_normalization()
  local dispatched = {}
  local intent = { type = "ui_button", id = "confirm", game_handler = "basic" }
  local result = game_action.dispatch({}, {}, intent, {}, _port(dispatched),
    { normalize_auto_intent = function()
      error("normalize must not run for non-auto buttons")
    end })

  lu.assertEvalToTrue(result == true, "a non-auto ui_button is handled")
  lu.assertEvalToTrue(dispatched.intent == intent, "the raw intent must be forwarded")
end

-- item_phase_ask 拦截:ITEM_PHASE_ASK source 激活 + choice_select → 由
-- item_phase_ask 处理(confirm + 关屏),basic 路由不得再 dispatch。
function TestGameActionDispatch:test_item_phase_ask_hijacks_choice_select_when_source_active()
  local state = {}
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK, {})
  local dispatched = {}
  local result = game_action.dispatch(state, {}, { type = "choice_select", game_handler = "basic" },
    {}, _port(dispatched))

  lu.assertEvalToTrue(result == true, "an item-phase choice_select is handled by the item-phase flow")
  lu.assertEvalToTrue(pending_confirmation.is_item_phase_confirmed(state) == true,
    "the item-phase confirm must be recorded")
  lu.assertEvalToTrue(dispatched.called == nil, "the basic route must not dispatch after the item-phase flow")
end

-- pre-confirm enter 全路径:非豁免屏 + choice_select → 开二次确认屏,不直接 dispatch。
-- owner 门控只读 intent 载荷的 actor_role_id(#443),本地缓存不参与授权。
function TestGameActionDispatch:test_pre_confirm_enter_path_opens_the_screen()
  local modal_opened = false
  local state = {
    ui = { active_choice_screen_key = "item_target_player" },
    ui_runtime = {
      ui_model = {
        choice = {
          id = 9,
          owner_role_id = 1,
          pre_confirm_on_select = true,
          options = { { id = 7, label = "确认", confirm_title = "确认选择", confirm_body = "是否确认?" } },
        },
      },
    },
    gameplay_loop_ports = {
      modal = {
        open_pre_confirm_screen = function()
          modal_opened = true
        end,
      },
    },
  }
  local dispatched = {}
  local result = game_action.dispatch(state, {},
    { type = "choice_select", option_id = 7, actor_role_id = 1, game_handler = "basic" }, {}, _port(dispatched))

  lu.assertEvalToTrue(result == true, "the pre-confirm enter path is handled")
  lu.assertEvalToTrue(modal_opened == true, "the pre-confirm screen must open")
  lu.assertEvalToTrue(dispatched.called == nil, "the pre-confirm screen replaces direct dispatch")
  lu.assertEvalToTrue(pending_confirmation.is_active(state) == true,
    "a pending confirmation session must exist after enter")
end

-- 未知 game_handler:回落 false。
function TestGameActionDispatch:test_unknown_handler_falls_back()
  local result = game_action.dispatch({}, {}, { type = "unknown_kind" }, {}, _port({}))
  lu.assertEvalToTrue(result == false, "an intent without a handler must fall through")
end

return TestGameActionDispatch
