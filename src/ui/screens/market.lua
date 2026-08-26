-- market（商店）屏:点击意图 + 开/关/选面板,单一归宿(工单 #118 Phase C)。
--
-- 这是 canvas 面,不是选择屏:没有 descriptor / open / canvas 三契约(详见
-- screens_registry 的说明)。market 走自己的开屏路径 —— choice_openers.open_choice_modal
-- 对它直接 return false,不经选择屏的 open_screen,由 coord/modal 直呼本模块的
-- open/close。
--
-- items 与 controls 此前是 canvas_builders 里相邻的两个 builder,合并进一份
-- build_route_specs 时必须保持「先 items 后 controls」—— 发射序即点击回调的注册序。
local nodes = require("src.ui.schema.market")
local ui_event_intents = require("src.ui.input.event_intents")
local route_model = require("src.ui.input.route_model")
local runtime_state = require("src.ui.state.runtime")
local market_view = require("src.ui.render.market")
local canvas = require("src.ui.coord.canvas_coordinator")
local with_client_role = require("src.ui.render.support.with_client_role")
local runtime = require("src.ui.render.support.runtime_ui")
local role_context = require("src.ui.view.role_context")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local item_slice = require("src.ui.view.item_slice")
local role_id_utils = require("src.foundation.identity")
local tip_queue = require("src.foundation.tips")

local M = { key = "market" }

local MARKET_SLOTS_FULL_TIP = "道具槽已满，无法购买"
local MARKET_SLOTS_FULL_TIP_SECONDS = 3.0

-- 槽满点击拦截(UI 本地闸):购买按钮在 build_intent 处打回 —— tip 告知 + 不生出
-- market_confirm intent,引擎往返整段跳过。槽位按 choice owner 取(视角玩家可能
-- 只是观战);模型缺槽位数据时放行,由引擎侧 purchase_fulfillment 的
-- inventory_full 校验兜底(覆盖 AI/auto 与刷新延迟穿透)。
local function _buyer_slots(state)
  local model = runtime_state.get_ui_model(state)
  if model == nil then
    return nil
  end
  local owner_id = model.item_choice_owner_id
  if owner_id ~= nil and type(model.item_slots_by_player) == "table" then
    local owner_slots = role_id_utils.read(model.item_slots_by_player, owner_id)
    if owner_slots ~= nil then
      return owner_slots
    end
  end
  return model.item_slots
end

local function _buyer_inventory_full(state)
  local slots = _buyer_slots(state)
  if type(slots) ~= "table" then
    return false
  end
  local slot_count = item_slice.resolve_slot_count(state.ui)
  if slot_count <= 0 then
    return false
  end
  for i = 1, slot_count do
    if slots[i] == nil then
      return false
    end
  end
  return true
end

local function _reject_buy_slots_full()
  tip_queue.enqueue({
    text = MARKET_SLOTS_FULL_TIP,
    duration = MARKET_SLOTS_FULL_TIP_SECONDS,
    dedupe_key = "market_buy_block_slots_full",
    blocks_inter_turn = false,
    source = "ui.market_slots_full",
  })
end

-- items 与 controls 保持两个具名 builder,而不是合成一坨:这个二分是真实的(items 由
-- nodes.item_buttons 数据驱动,controls 是固定集),且 canvas_route_market_baseline_spec
-- 正是分别钉住两者的产物。build_route_specs 只负责按序合成。
function M.build_items(state)
  local specs = {}
  for index, name in ipairs(nodes.item_buttons or {}) do
    specs[#specs + 1] = {
      name = name,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        local option_id = ui_event_intents.resolve_option_id(market, { index = index }, state)
        if not option_id then
          return nil
        end
        return { type = "market_select", option_id = option_id }
      end,
    }
  end
  return specs
end

function M.build_controls(state)
  local function _build_cancel_intent()
    return ui_event_intents.choice_cancel_intent(state, "market_close")
  end

  local function _build_choice_intent(intent_type)
    return function()
      local market = route_model.market(state)
      if not market then return nil end
      return { type = intent_type, choice_id = market.choice_id }
    end
  end

  return {
    {
      name = nodes.confirm,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        local ui_runtime = runtime_state.ensure_ui_runtime(state)
        local option_id = ui_runtime.pending_choice_selected_option_id
        if not option_id then
          return nil
        end
        if _buyer_inventory_full(state) then
          _reject_buy_slots_full()
          return nil
        end
        return { type = "market_confirm", choice_id = market.choice_id, option_id = option_id }
      end,
    },
    {
      name = nodes.cancel,
      build_intent = _build_cancel_intent,
    },
    {
      name = nodes.close,
      build_intent = _build_cancel_intent,
    },
    {
      name = nodes.page_prev,
      build_intent = _build_choice_intent("market_page_prev"),
    },
    {
      name = nodes.page_next,
      build_intent = _build_choice_intent("market_page_next"),
    },
    {
      name = nodes.tab_item,
      build_intent = function()
        local market = route_model.market(state)
        if not market then return nil end
        return { type = "market_tab_select", choice_id = market.choice_id, tab = "item" }
      end,
    },
  }
end

function M.build_route_specs(state)
  local specs = M.build_items(state)
  for _, spec in ipairs(M.build_controls(state)) do
    specs[#specs + 1] = spec
  end
  return specs
end

-- ===== 面板面(开/关/选) =====

local function _view_deps()
  return {
    runtime = runtime,
    modal_state = require("src.ui.state.modal"),
  }
end

local function _interrupt_panels_before_market_open(state)
  local ui = state and state.ui or nil
  if ui == nil then
    return
  end
  local was_market_active = ui.market_active
  ui.market_active = true
  panel_interrupt.interrupt(state)
  ui.market_active = was_market_active
end

-- 黑市开屏的 per-role 目标(#583):操作者进黑市;旁观者留在自己开着的面板
-- canvas(图鉴/皮肤),都没开才回基础屏——不再无条件把旁观者拽到基础屏。
local function _resolve_market_open_canvas(ui, ctx, role)
  if ctx.can_operate == true then
    return canvas.CANVAS_MARKET
  end
  local role_id = runtime.resolve_role_id(role)
  return canvas.resolve_role_panel_canvas(ui, role_id) or canvas.CANVAS_BASE
end

function M.open_market_panel(state, choice, choice_id, market)
  local ui = state.ui
  local market_payload = market or {
    choice_id = choice_id,
    options = choice.options,
    allow_cancel = choice.allow_cancel,
    cancel_label = choice.cancel_label,
    selected_option_id = runtime_state.ensure_ui_runtime(state).pending_choice_selected_option_id,
    active_tab = choice.active_tab,
    page_index = choice.page_index,
    page_count = choice.page_count,
  }
  local opened = false
  -- #583:弹窗(「卡牌展示屏」等)存活期不抢任何角色的 canvas、也不动面板——
  -- 广播弹窗正盖着黑市 canvas,抢屏会把展示掐成一闪而过;面板早在黑市首开/
  -- 移动打断时已清场,弹窗期重跑 interrupt 只会误伤身份解析异常的旁观者面板。
  -- 数据刷新与 market_active 照常落,收屏回屏按关闭时刻 market_active 把买家
  -- 带回黑市屏。
  local popup_active = ui.popup_active == true

  if not popup_active then
    _interrupt_panels_before_market_open(state)
  end
  runtime.for_each_role_or_global(function(role)
    with_client_role(runtime, role, function()
      local current_model = runtime_state.get_ui_model(state)
      local ctx = role_context.resolve(role, current_model, { runtime = runtime })
      if not popup_active then
        local target = _resolve_market_open_canvas(ui, ctx, role)
        if role then
          canvas.switch_for_role(ui, target, role)
        else
          canvas.switch(ui, target)
        end
      end
      if ctx.can_operate == true then
        opened = market_view.refresh_market(state, market_payload, _view_deps()) == true or opened
      end
    end)
  end)
  runtime.set_client_role(nil)
  ui.market_active = opened
end

M.open = M.open_market_panel

function M.close_market_panel(state)
  market_view.close_market_panel(state, _view_deps())
end

M.close = M.close_market_panel

function M.select_market_option(state, option_id)
  market_view.select_market_option(state, option_id, _view_deps())
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=4838f2901ab1eeaf
scope.0.id=chunk:src/ui/screens/market.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=250
scope.0.semanticHash=a080f061452216ca
scope.1.id=function:_buyer_slots
scope.1.kind=function
scope.1.startLine=33
scope.1.endLine=46
scope.1.semanticHash=2f821e3f95772738
scope.2.id=function:_buyer_inventory_full
scope.2.kind=function
scope.2.startLine=48
scope.2.endLine=63
scope.2.semanticHash=c16f822924d04e58
scope.3.id=function:_reject_buy_slots_full
scope.3.kind=function
scope.3.startLine=65
scope.3.endLine=73
scope.3.semanticHash=02a93b13e1e25dd5
scope.4.id=function:M.build_items
scope.4.kind=function
scope.4.startLine=78
scope.4.endLine=95
scope.4.semanticHash=e9cf3849d838a2b0
scope.5.id=function:<anonymous>
scope.5.kind=function
scope.5.startLine=83
scope.5.endLine=91
scope.5.semanticHash=8e29ea0b25a8675f
scope.6.id=function:M.build_controls
scope.6.kind=function
scope.6.startLine=97
scope.6.endLine=153
scope.6.semanticHash=2f026651953fa01e
scope.7.id=function:_build_cancel_intent
scope.7.kind=function
scope.7.startLine=98
scope.7.endLine=100
scope.7.semanticHash=28a7b4c21e049d18
scope.8.id=function:_build_choice_intent
scope.8.kind=function
scope.8.startLine=102
scope.8.endLine=108
scope.8.semanticHash=34fa5fe69730fa6b
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=103
scope.9.endLine=107
scope.9.semanticHash=e5b790e6bdafef22
scope.10.id=function:<anonymous>#3
scope.10.kind=function
scope.10.startLine=113
scope.10.endLine=126
scope.10.semanticHash=26005095c6660880
scope.11.id=function:<anonymous>#4
scope.11.kind=function
scope.11.startLine=146
scope.11.endLine=150
scope.11.semanticHash=003d0770bf8ccc4c
scope.12.id=function:M.build_route_specs
scope.12.kind=function
scope.12.startLine=155
scope.12.endLine=161
scope.12.semanticHash=ef50eb76fbe2e46d
scope.13.id=function:_view_deps
scope.13.kind=function
scope.13.startLine=165
scope.13.endLine=170
scope.13.semanticHash=eae7f15e1d6e92e9
scope.14.id=function:_interrupt_panels_before_market_open
scope.14.kind=function
scope.14.startLine=172
scope.14.endLine=181
scope.14.semanticHash=fb019a8d101cd4bf
scope.15.id=function:_resolve_market_open_canvas
scope.15.kind=function
scope.15.startLine=185
scope.15.endLine=191
scope.15.semanticHash=2e756d8b414a6d3a
scope.16.id=function:M.open_market_panel
scope.16.kind=function
scope.16.startLine=193
scope.16.endLine=235
scope.16.semanticHash=f114f97f59d95f42
scope.17.id=function:<anonymous>#5
scope.17.kind=function
scope.17.startLine=216
scope.17.endLine=232
scope.17.semanticHash=13cdb35f9275face
scope.18.id=function:<anonymous>#6
scope.18.kind=function
scope.18.startLine=217
scope.18.endLine=231
scope.18.semanticHash=0ece9b83bd914e82
scope.19.id=function:M.close_market_panel
scope.19.kind=function
scope.19.startLine=239
scope.19.endLine=241
scope.19.semanticHash=2f5ef8e70a007734
scope.20.id=function:M.select_market_option
scope.20.kind=function
scope.20.startLine=245
scope.20.endLine=247
scope.20.semanticHash=cbd214c8f19ff852
]]
