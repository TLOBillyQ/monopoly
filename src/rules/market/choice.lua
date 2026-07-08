-- 黑市购买选择结果解释者。purchase.execute 历史返回 4 种不兼容形状:
--   false(非法商品) / { ok=false, reason }(校验/余额/在途/通道失败) /
--   { ok=true, fulfilled_now=true, inventory_full_after }(本地即时成交) /
--   { ok=true, deferred_fulfillment=true }(付费下单、异步履约)。
-- resolve_purchase 内经 purchase_result.canonicalize 收敛为 4 个终态 status:
--   fulfilled / deferred / rejected / residual。
-- 本模块是市场购买结果解释的唯一解码点,判定 helpers 只认 canonical status,
-- 不再直接读取 raw 字段(ok/fulfilled_now/deferred_fulfillment)。
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local tables = require("src.foundation.tables")
local logger = require("src.foundation.log")
local choice_contract = require("src.config.choice.contract")
local dirty_tracker = require("src.state.dirty_tracker")
local intent_output_port = require("src.rules.ports.intent_output")
local market_query = require("src.rules.market.query")
local purchase_result = require("src.rules.market.purchase_result")

local query_context = market_query.context
local query_eligibility = market_query.eligibility

local feedback = {}
local _emit_event = monopoly_event.emit

local popup_title = "黑市"

function feedback.emit_buy_failed(player, entry, reason, body)
  _emit_event(monopoly_event.market.buy_failed, {
    player = player,
    entry = entry,
    reason = reason,
    popup = { title = popup_title, body = body },
  })
end

function feedback.emit_inventory_full(player, entry)
  _emit_event(monopoly_event.market.inventory_full, {
    player = player,
    entry = entry,
    body = "卡槽已满，无法继续购买",
  })
end

local builder = {}
local PAGE_SIZE = 10
local TAB_ITEM = "item"

local function _normalize_tab(tab)
  if tables.contains({ TAB_ITEM }, tab) then
    return tab
  end
  return TAB_ITEM
end

local function _clamp_page(page_index, page_count)
  local page = number_utils.to_integer(page_index) or 1
  local count = number_utils.to_integer(page_count) or 1
  return number_utils.clamp(page, 1, count)
end

local function _build_tab_entries(player, game, active_tab)
  local merged = {}
  for _, entry in ipairs(query_eligibility.sorted_entries()) do
    if entry.kind == active_tab
        and query_context.entry_market_enabled(entry) then
      local can_buy = query_eligibility.can_buy_entry(game, player, entry)
      merged[#merged + 1] = {
        entry = entry,
        can_buy = can_buy,
        sold_out = query_eligibility.is_sold_out(game, entry),
      }
    end
  end
  return merged
end

local function _build_options_for_page(visible, page_index, page_size)
  local start_index = (page_index - 1) * page_size + 1
  local last_index = start_index + page_size - 1
  local options = {}
  local body_lines = {}
  for index = start_index, last_index do
    local slot = visible[index]
    if not slot then
      break
    end
    local entry = slot.entry
    local name = query_context.entry_name(entry)
    local price = query_context.entry_price(entry)
    local currency = query_context.entry_currency(entry)
    local label = name .. " - " .. number_utils.format_integer_part(price) .. " " .. currency
    body_lines[#body_lines + 1] = label
    options[#options + 1] = {
      id = entry.product_id,
      label = label,
      can_buy = slot.can_buy,
      sold_out = slot.sold_out,
    }
  end
  return body_lines, options
end

local function _resolve_page_count(total_count, page_size)
  local total = number_utils.to_integer(total_count) or 0
  local size = number_utils.to_integer(page_size) or 1
  if total <= 0 then
    return 1
  end
  return math.floor((total + size - 1) / size)
end

function builder.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible = _build_tab_entries(player, game, active_tab)
  local page_count = _resolve_page_count(#visible, PAGE_SIZE)
  local page_index = _clamp_page(state.page_index, page_count)
  local body_lines, options = _build_options_for_page(visible, page_index, PAGE_SIZE)
  return {
    kind = "market_buy",
    route_key = "market",
    owner_role_id = player.id,
    title = "黑市",
    body_lines = body_lines,
    options = options,
    allow_cancel = true,
    cancel_label = "不买",
    active_tab = active_tab,
    page_index = page_index,
    page_count = page_count,
    meta = {
      player_id = player.id,
      active_tab = active_tab,
      page_index = page_index,
      page_count = page_count,
    },
  }
end

local session = {}

local function _mark_choice_dirty(game)
  if not game or not game.dirty then
    return
  end
  dirty_tracker.mark(game.dirty, "turn")
  dirty_tracker.mark(game.dirty, "market")
end

local function _current_choice_state(pending_choice)
  return {
    active_tab = pending_choice and pending_choice.active_tab or nil,
    page_index = pending_choice and pending_choice.page_index or nil,
  }
end

local _resolve_owner_role_id = choice_contract.resolve_owner_role_id

local function _apply_spec(game, pending_choice, spec)
  assert(pending_choice ~= nil, "missing pending_choice")
  assert(spec ~= nil, "missing spec")
  pending_choice.title = spec.title
  pending_choice.body_lines = spec.body_lines
  pending_choice.options = spec.options
  pending_choice.allow_cancel = spec.allow_cancel
  pending_choice.cancel_label = spec.cancel_label
  pending_choice.active_tab = spec.active_tab
  pending_choice.page_index = spec.page_index
  pending_choice.page_count = spec.page_count
  pending_choice.owner_role_id = spec.owner_role_id
  pending_choice.meta = spec.meta
  _mark_choice_dirty(game)
end

function session.rebuild_pending(game, pending_choice, player, state)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    return false
  end
  if not player then
    return false
  end
  local spec = builder.build(player, game, state or _current_choice_state(pending_choice))
  if not spec then
    return false
  end
  _apply_spec(game, pending_choice, spec)
  return true
end

local NAVIGATION_ACTIONS = {
  market_tab_select = function(action, active_tab, page_index)
    if active_tab == action.tab then
      return active_tab, page_index, true
    end
    return action.tab, 1, false
  end,
  market_page_prev = function(_, active_tab, page_index)
    return active_tab, (number_utils.to_integer(page_index) or 1) - 1, false
  end,
  market_page_next = function(_, active_tab, page_index)
    return active_tab, (number_utils.to_integer(page_index) or 1) + 1, false
  end,
}

local function _apply_navigation_action(action, active_tab, page_index)
  local handler = NAVIGATION_ACTIONS[action.type]
  if handler then
    return handler(action, active_tab, page_index)
  end
  return active_tab, page_index, false
end

local function _resolve_navigation_player(game, pending_choice)
  if not game or not pending_choice or pending_choice.kind ~= "market_buy" then
    return nil
  end
  local player_id = _resolve_owner_role_id(pending_choice)
  if not player_id then
    return nil
  end
  return game:find_player_by_id(player_id)
end

local function _build_navigation_spec(player, game, pending_choice, active_tab, page_index)
  return builder.build(player, game, {
    active_tab = active_tab,
    page_index = page_index,
    page_count = pending_choice.page_count,
  })
end

local function _apply_navigation_spec(game, pending_choice, player, spec)
  if spec == nil then
    return false
  end
  if #spec.options == 0 then
    feedback.emit_buy_failed(player, nil, "empty_tab", "当前页签暂无可购买项")
  end
  _apply_spec(game, pending_choice, spec)
  return true
end

function session.apply_navigation(game, pending_choice, action)
  local player = _resolve_navigation_player(game, pending_choice)
  if not player then
    return false
  end
  local active_tab, page_index, unchanged = _apply_navigation_action(
    action, pending_choice.active_tab, pending_choice.page_index
  )
  if unchanged then
    return true
  end
  local spec = _build_navigation_spec(player, game, pending_choice, active_tab, page_index)
  return _apply_navigation_spec(game, pending_choice, player, spec)
end

local function _market_pending_choice(game)
  local pending_choice = game and game.turn and game.turn.pending_choice or nil
  if not pending_choice or pending_choice.kind ~= "market_buy" then
    return nil
  end
  return pending_choice
end

local function _is_pending_choice_owner(pending_choice, player)
  local owner_id = _resolve_owner_role_id(pending_choice)
  return owner_id == (player and player.id or nil)
end

local function _warn_refresh_skipped(player, entry)
  logger.warn(
    "market paid callback refresh skipped:",
    "player_id=" .. tostring(player and player.id or nil),
    "product_id=" .. tostring(entry and entry.product_id)
  )
end

function session.refresh_after_paid_callback(game, player, entry)
  local pending_choice = _market_pending_choice(game)
  if not pending_choice or not _is_pending_choice_owner(pending_choice, player) then
    return false
  end
  local rebuilt = session.rebuild_pending(game, pending_choice, player)
  if rebuilt then
    return true
  end
  _warn_refresh_skipped(player, entry)
  return false
end

local outcome = {}

local _INTENT_HANDLERS = {
  need_choice = function(game, intent)
    if intent.choice_spec == nil then return false end
    return intent_output_port.open_choice(game, intent.choice_spec, intent.opts) ~= nil
  end,
  push_popup = function(game, intent)
    if intent.payload == nil then return false end
    return intent_output_port.push_popup(game, intent.payload, intent.popup_opts or intent.opts) == true
  end,
}

local function _dispatch_intent(game, intent)
  if type(intent) ~= "table" then return false end
  local handler = _INTENT_HANDLERS[intent.kind]
  if not handler then return false end
  return handler(game, intent)
end

local function _is_purchase_failure(canonical)
  return canonical.status == "rejected"
end

local function _should_keep_market_open(entry, canonical)
  if canonical.status == "deferred" then
    return true
  end
  return entry and entry.kind == "item" and canonical.status == "fulfilled"
end

local function _handle_keep_open(game, choice, player, entry, canonical, finish_choice)
  local rebuilt = session.rebuild_pending(game, choice, player)
  if not rebuilt then return finish_choice(game, false) end
  local full_buy = entry and entry.kind == "item" and canonical.status == "fulfilled" and canonical.inventory_full_after == true
  if full_buy then feedback.emit_inventory_full(player, entry) end
  return { stay = true }
end

local function _try_failure_stay(game, choice, player, result)
  if not _is_purchase_failure(result) then return false end
  return not not session.rebuild_pending(game, choice, player)
end

local function _dispatch_and_finish(game, result, finish_choice)
  if type(result) == "table" then
    local intent = result.intent or {}
    _dispatch_intent(game, intent)
    if intent.kind == "need_choice" then return { stay = true } end
  end
  return finish_choice(game, false)
end

function outcome.resolve_purchase(game, choice, player, entry, result, finish_choice)
  assert(type(finish_choice) == "function", "missing finish_choice")
  local canonical = purchase_result.canonicalize(result)
  if _should_keep_market_open(entry, canonical) then
    return _handle_keep_open(game, choice, player, entry, canonical, finish_choice)
  end
  if _try_failure_stay(game, choice, player, canonical) then return { stay = true } end
  return _dispatch_and_finish(game, result, finish_choice)
end

return {
  builder = builder,
  feedback = feedback,
  session = session,
  outcome = outcome,
}

--[[ mutate4lua-manifest
version=2
projectHash=39de3deff6bcd54f
scope.0.id=chunk:src/rules/market/choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=361
scope.0.semanticHash=85c226d00c025257
scope.1.id=function:feedback.emit_buy_failed:27
scope.1.kind=function
scope.1.startLine=27
scope.1.endLine=34
scope.1.semanticHash=e71effe8d04fe328
scope.2.id=function:feedback.emit_inventory_full:36
scope.2.kind=function
scope.2.startLine=36
scope.2.endLine=42
scope.2.semanticHash=a54de9b8d122a75f
scope.3.id=function:_normalize_tab:48
scope.3.kind=function
scope.3.startLine=48
scope.3.endLine=53
scope.3.semanticHash=7557bdf041850658
scope.4.id=function:_clamp_page:55
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=59
scope.4.semanticHash=c86b80b14c198bfb
scope.5.id=function:_resolve_page_count:103
scope.5.kind=function
scope.5.startLine=103
scope.5.endLine=110
scope.5.semanticHash=fa5c01dacf8252db
scope.6.id=function:builder.build:112
scope.6.kind=function
scope.6.startLine=112
scope.6.endLine=138
scope.6.semanticHash=b2306239453e1425
scope.7.id=function:_mark_choice_dirty:142
scope.7.kind=function
scope.7.startLine=142
scope.7.endLine=148
scope.7.semanticHash=e3719833b7956ff5
scope.8.id=function:_current_choice_state:150
scope.8.kind=function
scope.8.startLine=150
scope.8.endLine=155
scope.8.semanticHash=43e56198b0ee9e82
scope.9.id=function:_apply_spec:159
scope.9.kind=function
scope.9.startLine=159
scope.9.endLine=173
scope.9.semanticHash=18c378346e7f93ea
scope.10.id=function:session.rebuild_pending:175
scope.10.kind=function
scope.10.startLine=175
scope.10.endLine=188
scope.10.semanticHash=6b2af66f701b1077
scope.11.id=function:anonymous@191:191
scope.11.kind=function
scope.11.startLine=191
scope.11.endLine=196
scope.11.semanticHash=41f845f5fc748cac
scope.12.id=function:anonymous@197:197
scope.12.kind=function
scope.12.startLine=197
scope.12.endLine=199
scope.12.semanticHash=70d7278f67f6a338
scope.13.id=function:anonymous@200:200
scope.13.kind=function
scope.13.startLine=200
scope.13.endLine=202
scope.13.semanticHash=ed1b46d08fa23b4a
scope.14.id=function:_apply_navigation_action:205
scope.14.kind=function
scope.14.startLine=205
scope.14.endLine=211
scope.14.semanticHash=38a11610d3762ea9
scope.15.id=function:_resolve_navigation_player:213
scope.15.kind=function
scope.15.startLine=213
scope.15.endLine=222
scope.15.semanticHash=c05baa8367d8efea
scope.16.id=function:_build_navigation_spec:224
scope.16.kind=function
scope.16.startLine=224
scope.16.endLine=230
scope.16.semanticHash=6f3d0c22b3f0a240
scope.17.id=function:_apply_navigation_spec:232
scope.17.kind=function
scope.17.startLine=232
scope.17.endLine=241
scope.17.semanticHash=e3c27021d02cf4f8
scope.18.id=function:session.apply_navigation:243
scope.18.kind=function
scope.18.startLine=243
scope.18.endLine=256
scope.18.semanticHash=7c2b1b60ab17ab3b
scope.19.id=function:_market_pending_choice:258
scope.19.kind=function
scope.19.startLine=258
scope.19.endLine=264
scope.19.semanticHash=7e0d0da1c4530cb5
scope.20.id=function:_is_pending_choice_owner:266
scope.20.kind=function
scope.20.startLine=266
scope.20.endLine=269
scope.20.semanticHash=e762cd3954e51dcf
scope.21.id=function:_warn_refresh_skipped:271
scope.21.kind=function
scope.21.startLine=271
scope.21.endLine=277
scope.21.semanticHash=772b6013a62ccd3d
scope.22.id=function:session.refresh_after_paid_callback:279
scope.22.kind=function
scope.22.startLine=279
scope.22.endLine=290
scope.22.semanticHash=0bc3dc1d485d02d6
scope.23.id=function:anonymous@295:295
scope.23.kind=function
scope.23.startLine=295
scope.23.endLine=298
scope.23.semanticHash=27f38fdab7a8f471
scope.24.id=function:anonymous@299:299
scope.24.kind=function
scope.24.startLine=299
scope.24.endLine=302
scope.24.semanticHash=7a968adc59580688
scope.25.id=function:_dispatch_intent:305
scope.25.kind=function
scope.25.startLine=305
scope.25.endLine=310
scope.25.semanticHash=23ff74f8961f90bc
scope.26.id=function:_is_purchase_failure:312
scope.26.kind=function
scope.26.startLine=312
scope.26.endLine=314
scope.26.semanticHash=09b0616cae00e9bb
scope.27.id=function:_should_keep_market_open:316
scope.27.kind=function
scope.27.startLine=316
scope.27.endLine=321
scope.27.semanticHash=b5e3a62687d00dd1
scope.28.id=function:_handle_keep_open:323
scope.28.kind=function
scope.28.startLine=323
scope.28.endLine=329
scope.28.semanticHash=4042e520b5ee8071
scope.29.id=function:_try_failure_stay:331
scope.29.kind=function
scope.29.startLine=331
scope.29.endLine=334
scope.29.semanticHash=4ea90e8fe6817a58
scope.30.id=function:_dispatch_and_finish:336
scope.30.kind=function
scope.30.startLine=336
scope.30.endLine=343
scope.30.semanticHash=6e51764679270d02
scope.31.id=function:outcome.resolve_purchase:345
scope.31.kind=function
scope.31.startLine=345
scope.31.endLine=353
scope.31.semanticHash=66a7b380874b512b
]]
