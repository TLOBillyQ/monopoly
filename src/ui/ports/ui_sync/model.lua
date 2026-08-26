local runtime_state = require("src.ui.state.runtime")
local turn_ui_sync_shared = require("src.state.ui_sync_shared")
local landing_visual_hold = require("src.ui.visual_hold")
local modal = require("src.ui.coord.modal")
local main_view = require("src.ui.coord.ui_runtime")
local view_model = require("src.ui.view")
local choice_ui_state = require("src.ui.ports.ui_sync.choice_state")
local player_control_snapshot = require("src.turn.output.player_control_snapshot")
local ui_gate_sync = require("src.ui.ports.ui_sync.gate")
local modal_state = require("src.ui.state.modal")
local role_id_utils = require("src.foundation.identity")

local ui_model_sync = {}
local _close_modal_gate = {}

local function _mark_ui_dirty_from_runtime(state, dirty)
  if runtime_state.is_ui_dirty(state) then
    dirty.ui = true
  end
end

local function _defer_refresh_for_landing_hold(state, dirty)
  if not landing_visual_hold.should_defer(state) then
    return false
  end
  landing_visual_hold.freeze_active_ui(state)
  if dirty.any or dirty.ui then
    landing_visual_hold.defer_dirty(state, dirty)
  end
  return true
end

local function _update_runtime_ui_model(state, game, dirty)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  env.player_control_by_player = player_control_snapshot.install(game)
  local next_model = view_model.update(runtime_state.get_ui_model(state), game, env, dirty)
  runtime_state.set_ui_model(state, next_model)
  return next_model
end

local function _panel_of(next_model)
  return next_model and next_model.panel or nil
end

local function _refresh_turn_label(state, next_model)
  local panel = _panel_of(next_model)
  main_view.refresh_turn_label(
    state,
    panel and panel.turn_label or "",
    panel and panel.countdown_visible
  )
end

local function _is_phase_input_blocked(game)
  local phase = game and game.turn and game.turn.phase or nil
  return choice_ui_state.is_phase_input_blocked(phase)
end

-- 存活弹窗是否占着黑市操作者的屏:排除买家本人的弹窗(黑市购买展示,
-- 2026-08-25 买家免展示口径)不占其屏,重建不该被拦。
local function _popup_covers_market_operator(state, ui)
  local excluded = ui.popup_exclude_role_id
  if excluded == nil then
    return true
  end
  local operator = modal_state.operator_role_id(state)
  return not (operator ~= nil and role_id_utils.equals(excluded, operator))
end

-- market 屏：dirty 里带 market 变更就直接开，否则回退到常规 reconcile 判定。
-- #583:已开黑市的 dirty 重建在弹窗存活期跳过——「卡牌展示屏」收屏时回屏按
-- 关闭时刻 market_active 把买家带回黑市屏,无需补发;黑市未开(market_active=false,
-- 如机会卡传送流)的首开不拦,否则收屏回屏解析不到 market_active、黑市永不补开。
-- 2026-08-25 买家免展示口径:弹窗排除买家本人时它不占买家屏,重建照常放行,
-- 买家即时看到库存刷新。
-- 弹窗存活期跳过判定(CRAP 门禁):三重旗标合取收敛到本谓词,
-- _should_open_market_modal 只留 dirty 分派。
local function _market_rebuild_blocked_by_popup(state)
  local ui = state and state.ui
  return ui ~= nil and ui.popup_active == true and ui.market_active == true
    and _popup_covers_market_operator(state, ui)
end

local function _should_open_market_modal(game, state, next_model, dirty)
  if dirty and dirty.market == true then
    return not _market_rebuild_blocked_by_popup(state)
  end
  return choice_ui_state.should_reconcile(game, state, next_model.choice)
end

local function _has_choice(next_model)
  return next_model and next_model.choice
end

-- 内联路由(base_inline / item_phase_passive)不需要弹模态。
local function _inline_route(route_key)
  return route_key == "base_inline" or route_key == "item_phase_passive"
end

local function _has_market_route(route_key, next_model)
  return route_key == "market" and next_model.market ~= nil
end

local function _should_open_choice_modal(game, state, next_model, dirty)
  if not _has_choice(next_model) then
    return false
  end
  if _is_phase_input_blocked(game) then
    return false
  end
  local route_key = choice_ui_state.resolve_route_key(next_model.choice)
  if _inline_route(route_key) then
    return true
  end
  if _has_market_route(route_key, next_model) then
    return _should_open_market_modal(game, state, next_model, dirty)
  end
  return choice_ui_state.should_reconcile(game, state, next_model.choice)
end

local function _should_close_choice_modal(state, next_model)
  local gate = ui_gate_sync.snapshot(state and state.ui or nil, _close_modal_gate)
  if not gate.choice_active then
    return false
  end
  return not (next_model and next_model.choice)
end

-- #525 时序边界(裁定见 #524):开/收屏先于 main_view.render。阻塞期创建的
-- 窗口在放行帧首开时,若渲染先跑会读到陈旧 choice_active=false,基础「结束」
-- 按钮被点得与弹窗同屏亮;先落门控再渲染,渲染即见开屏后的状态。
-- 界限:仅对置 choice_active 的模态路由生效;inline 路由(base_inline/
-- item_phase_passive)开屏不置门控,基础屏行动/结束按钮即选择出口,照常点亮。
local function _render_ui_model(game, state, next_model, dirty, common)
  if _should_close_choice_modal(state, next_model) then
    modal.close_choice_modal(state)
  elseif _should_open_choice_modal(game, state, next_model, dirty) then
    modal.open_choice_modal(state, next_model.choice, next_model.market)
  end
  main_view.render(state, next_model, common.log_once, common.build_log_prefix)
end

function ui_model_sync.apply_input_lock(state)
  main_view.apply_input_lock(state)
end

function ui_model_sync.build_model(state, game)
  local env = turn_ui_sync_shared.build_ui_env(state, game)
  env.player_control_by_player = player_control_snapshot.install(game)
  return view_model.build(game, env)
end

function ui_model_sync.refresh_from_dirty(game, state, dirty, common)
  landing_visual_hold.sync_state_from_game(state, game)
  _mark_ui_dirty_from_runtime(state, dirty)
  if _defer_refresh_for_landing_hold(state, dirty) then
    return false
  end
  if not (dirty.any or dirty.ui) then
    return false
  end
  local only_countdown = turn_ui_sync_shared.is_only_turn_countdown(dirty)
  local next_model = _update_runtime_ui_model(state, game, dirty)
  if only_countdown then
    _refresh_turn_label(state, next_model)
  else
    _render_ui_model(game, state, next_model, dirty, common)
  end
  runtime_state.set_ui_dirty(state, false)
  return not only_countdown
end

local function _resolve_reconciled_choice_model(game, state, pending)
  local model = runtime_state.get_ui_model(state)
  if model and model.choice and model.choice.id == pending.id then
    return model
  end

  model = ui_model_sync.build_model(state, game)
  runtime_state.set_ui_model(state, model)
  return model
end

function ui_model_sync.reopen_choice_modal_if_needed(game, state, pending)
  player_control_snapshot.install(game)
  if not choice_ui_state.should_reconcile(game, state, pending) then
    return false
  end
  local model = _resolve_reconciled_choice_model(game, state, pending)
  if not (model and model.choice) then
    return false
  end
  modal.open_choice_modal(state, model.choice, model.market)
  return true
end

return ui_model_sync

--[[ mutate4lua-manifest
version=4
projectHash=ec3d1ad852a756e1
scope.0.id=chunk:src/ui/ports/ui_sync/model.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=198
scope.0.semanticHash=6f886182dd76ca95
scope.1.id=function:_mark_ui_dirty_from_runtime
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=20
scope.1.semanticHash=6adcfba0e2cb0d7a
scope.2.id=function:_defer_refresh_for_landing_hold
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=31
scope.2.semanticHash=5c3b00b30a249742
scope.3.id=function:_update_runtime_ui_model
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=89f3c045697140cf
scope.4.id=function:_panel_of
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=616a2ca60599c94f
scope.5.id=function:_refresh_turn_label
scope.5.kind=function
scope.5.startLine=45
scope.5.endLine=52
scope.5.semanticHash=4519a01afdd95883
scope.6.id=function:_is_phase_input_blocked
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=57
scope.6.semanticHash=e8af86822fc69918
scope.7.id=function:_popup_covers_market_operator
scope.7.kind=function
scope.7.startLine=61
scope.7.endLine=68
scope.7.semanticHash=cf5e7737113e2a09
scope.8.id=function:_market_rebuild_blocked_by_popup
scope.8.kind=function
scope.8.startLine=78
scope.8.endLine=82
scope.8.semanticHash=56289fa7021bc1f9
scope.9.id=function:_should_open_market_modal
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=89
scope.9.semanticHash=b1dc9ad787133479
scope.10.id=function:_has_choice
scope.10.kind=function
scope.10.startLine=91
scope.10.endLine=93
scope.10.semanticHash=ac1dbf12b688483f
scope.11.id=function:_inline_route
scope.11.kind=function
scope.11.startLine=96
scope.11.endLine=98
scope.11.semanticHash=4660cf802f43a770
scope.12.id=function:_has_market_route
scope.12.kind=function
scope.12.startLine=100
scope.12.endLine=102
scope.12.semanticHash=7385398015d632c1
scope.13.id=function:_should_open_choice_modal
scope.13.kind=function
scope.13.startLine=104
scope.13.endLine=119
scope.13.semanticHash=803115998fc1bc48
scope.14.id=function:_should_close_choice_modal
scope.14.kind=function
scope.14.startLine=121
scope.14.endLine=127
scope.14.semanticHash=98af457f29124de5
scope.15.id=function:_render_ui_model
scope.15.kind=function
scope.15.startLine=134
scope.15.endLine=141
scope.15.semanticHash=808eb6aedf804ac3
scope.16.id=function:ui_model_sync.apply_input_lock
scope.16.kind=function
scope.16.startLine=143
scope.16.endLine=145
scope.16.semanticHash=c772a22f8680e278
scope.17.id=function:ui_model_sync.build_model
scope.17.kind=function
scope.17.startLine=147
scope.17.endLine=151
scope.17.semanticHash=c4c98047006f4fe6
scope.18.id=function:ui_model_sync.refresh_from_dirty
scope.18.kind=function
scope.18.startLine=153
scope.18.endLine=171
scope.18.semanticHash=e30a6f3da72f9f4d
scope.19.id=function:_resolve_reconciled_choice_model
scope.19.kind=function
scope.19.startLine=173
scope.19.endLine=182
scope.19.semanticHash=ef89f5ecd07a110b
scope.20.id=function:ui_model_sync.reopen_choice_modal_if_needed
scope.20.kind=function
scope.20.startLine=184
scope.20.endLine=195
scope.20.semanticHash=91fab883653acfb6
]]
