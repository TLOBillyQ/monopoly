-- 黑市购买选择构建器与会话管理。
-- 负责构建 market_buy 选择规格、应用导航、在付费回调后刷新待处理选择,
-- 以及提供购买失败/库存已满等反馈事件。购买结果解释在 purchase_settlement。
local monopoly_event = require("src.foundation.events")
local number_utils = require("src.foundation.number")
local tables = require("src.foundation.tables")
local logger = require("src.foundation.log")
local choice_contract = require("src.config.choice.contract")
local dirty_tracker = require("src.state.dirty_tracker")
local market_query = require("src.rules.market.query")

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

-- page_index 缺省回落首页由 clamp 的 nil→min 承担;page_count 在唯一调用方
-- builder.build 处由 number_utils.page_count 保证为 ≥1 整数,两端点的
-- `or 1` 默认值均为死防御(#259 变异清扫删除)。
local function _clamp_page(page_index, page_count)
  return number_utils.clamp(number_utils.to_integer(page_index), 1, page_count)
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

function builder.build(player, game, state)
  state = state or {}
  local active_tab = _normalize_tab(state.active_tab)
  local visible = _build_tab_entries(player, game, active_tab)
  -- foundation 的 page_count 与本地实现逐点等价(含空列表 → 1 页),
  -- 本地化简后删除(#259 变异清扫:双默认值死防御不可达)。
  local page_count = number_utils.page_count(#visible, PAGE_SIZE)
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
  -- 无入口断言:两个调用方(rebuild_pending / _apply_navigation_spec)都在
  -- 进入前挡掉了 nil pending_choice 与 nil spec,守卫不可达(#259 删除)。
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

local function _valid_market_buy(game, pending_choice)
  return game ~= nil and pending_choice ~= nil and pending_choice.kind == "market_buy"
end

function session.rebuild_pending(game, pending_choice, player, state)
  if not _valid_market_buy(game, pending_choice) then
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
    -- 页码用 nil 表达「回默认」:build 端 clamp(nil → 1) 承担,字面量 1 的
    -- 1→0 变异会被 clamp 吸收成等价体(#259 化简)。
    return action.tab, nil, false
  end,
  market_page_prev = function(_, active_tab, page_index)
    local current = number_utils.to_integer(page_index)
    -- nil 页码同样交 clamp 回落首页;`(x or 1) - 1` 的 1→0 变异在 clamp 下
    -- 不可观测,此形态下该变异体会跳过递减直接可杀。
    return active_tab, current and current - 1 or nil, false
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

local function _turn_pending_choice(game)
  return game and game.turn and game.turn.pending_choice or nil
end

local function _market_pending_choice(game)
  local pending_choice = _turn_pending_choice(game)
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

return {
  builder = builder,
  feedback = feedback,
  session = session,
  _M_test = {
    _current_choice_state = _current_choice_state,
  },
}

--[[ mutate4lua-manifest
version=4
projectHash=2a8bd3eccfa3eb98
scope.0.id=chunk:src/rules/market/choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=300
scope.0.semanticHash=3e315794b7de429e
scope.1.id=function:feedback.emit_buy_failed
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=27
scope.1.semanticHash=7335e27c9f1ab9fe
scope.2.id=function:feedback.emit_inventory_full
scope.2.kind=function
scope.2.startLine=29
scope.2.endLine=35
scope.2.semanticHash=d3e984c70577c6cb
scope.3.id=function:_normalize_tab
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=46
scope.3.semanticHash=bab6c88cd4df361f
scope.4.id=function:_clamp_page
scope.4.kind=function
scope.4.startLine=51
scope.4.endLine=53
scope.4.semanticHash=7c1429fa890e31f9
scope.5.id=function:_build_tab_entries
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=69
scope.5.semanticHash=6ddcdbe6c50cd1d9
scope.6.id=function:_build_options_for_page
scope.6.kind=function
scope.6.startLine=71
scope.6.endLine=95
scope.6.semanticHash=7d8faa2ed9a1661c
scope.7.id=function:builder.build
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=125
scope.7.semanticHash=af4b329b7506448c
scope.8.id=function:_mark_choice_dirty
scope.8.kind=function
scope.8.startLine=129
scope.8.endLine=135
scope.8.semanticHash=43fd305d6eb0b514
scope.9.id=function:_current_choice_state
scope.9.kind=function
scope.9.startLine=137
scope.9.endLine=142
scope.9.semanticHash=bf449b859e89fe05
scope.10.id=function:_apply_spec
scope.10.kind=function
scope.10.startLine=146
scope.10.endLine=160
scope.10.semanticHash=b33822c801114f4c
scope.11.id=function:_valid_market_buy
scope.11.kind=function
scope.11.startLine=162
scope.11.endLine=164
scope.11.semanticHash=618de108da5da92a
scope.12.id=function:session.rebuild_pending
scope.12.kind=function
scope.12.startLine=166
scope.12.endLine=179
scope.12.semanticHash=f9ce366e8027cf83
scope.13.id=function:<anonymous>
scope.13.kind=function
scope.13.startLine=182
scope.13.endLine=189
scope.13.semanticHash=1af4fbc54cb60e44
scope.14.id=function:<anonymous>#2
scope.14.kind=function
scope.14.startLine=190
scope.14.endLine=195
scope.14.semanticHash=c888321db4e25bed
scope.15.id=function:<anonymous>#3
scope.15.kind=function
scope.15.startLine=196
scope.15.endLine=198
scope.15.semanticHash=6a55ff06e308ebf4
scope.16.id=function:_apply_navigation_action
scope.16.kind=function
scope.16.startLine=201
scope.16.endLine=207
scope.16.semanticHash=2c3044aa80517fa0
scope.17.id=function:_resolve_navigation_player
scope.17.kind=function
scope.17.startLine=209
scope.17.endLine=218
scope.17.semanticHash=70084e3d1f87af27
scope.18.id=function:_build_navigation_spec
scope.18.kind=function
scope.18.startLine=220
scope.18.endLine=226
scope.18.semanticHash=8ce5576686a52474
scope.19.id=function:_apply_navigation_spec
scope.19.kind=function
scope.19.startLine=228
scope.19.endLine=237
scope.19.semanticHash=236b0ae443f7820b
scope.20.id=function:session.apply_navigation
scope.20.kind=function
scope.20.startLine=239
scope.20.endLine=252
scope.20.semanticHash=3c1d1a7840d76c01
scope.21.id=function:_turn_pending_choice
scope.21.kind=function
scope.21.startLine=254
scope.21.endLine=256
scope.21.semanticHash=c250138038aa193a
scope.22.id=function:_market_pending_choice
scope.22.kind=function
scope.22.startLine=258
scope.22.endLine=264
scope.22.semanticHash=a49e9e3de6138682
scope.23.id=function:_is_pending_choice_owner
scope.23.kind=function
scope.23.startLine=266
scope.23.endLine=269
scope.23.semanticHash=124717119cec650d
scope.24.id=function:_warn_refresh_skipped
scope.24.kind=function
scope.24.startLine=271
scope.24.endLine=277
scope.24.semanticHash=a1ce0379dd20f7f8
scope.25.id=function:session.refresh_after_paid_callback
scope.25.kind=function
scope.25.startLine=279
scope.25.endLine=290
scope.25.semanticHash=acd826469eae025f
]]
