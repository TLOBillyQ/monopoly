local market_ui = require("src.presentation.shared.MarketLayout")
local panel_presenter = require("src.presentation.ui.UIPanelPresenter")
local role_context = require("src.presentation.state.UIRoleContext")
local ui_nodes = require("src.presentation.shared.UINodes")
local ui_touch_policy = require("src.presentation.interaction.UITouchPolicy")

local input_lock_policy = {}

local function _force_item_slots_visible_for_player(ui, ctx)
  if not ui or not ui.set_visible then
    return
  end
  if not ctx or ctx.is_player_role ~= true then
    return
  end
  local slots = ui.item_slots or {}
  for _, slot_name in ipairs(slots) do
    ui:set_visible(slot_name, true)
  end
end

-- 输入锁期间，弹窗确认是少数允许放行的操作。
local function _can_popup_confirm()
  return true
end

function input_lock_policy.apply(state, deps)
  assert(state ~= nil and state.ui ~= nil, "missing state.ui")
  assert(deps ~= nil and deps.runtime ~= nil, "missing deps.runtime")
  local runtime = deps.runtime
  local ui = state.ui

  if not ui.set_touch_enabled then
    return
  end

  -- 未锁定：仅维护弹窗确认与调试开关触控，不干预其他路径。
  if not ui.input_blocked then
    if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
      ui:set_touch_enabled(ui.popup_screen.confirm, _can_popup_confirm())
    end
    ui_touch_policy.set_debug_toggle_touch(ui, true)
    return
  end

  local model = state.ui_model or {}
  runtime.for_each_role_or_global(function(role)
    local ctx = role_context.resolve(role, model, { runtime = runtime })
    panel_presenter.apply_base_non_player_visibility(ui, false)
    _force_item_slots_visible_for_player(ui, ctx)
    panel_presenter.render_auto_controls_for_role(ui, ctx, model)
  end)
  runtime.set_client_role(nil)

  -- 输入锁开启：先整体锁住回合内操作入口。
  ui:set_touch_enabled(ui_nodes.buttons.action, false)

  ui_touch_policy.set_many_touch_enabled(ui, ui.item_slots or {}, false)

  local screens = ui.choice_screens or {}
  ui_touch_policy.set_choice_screen_locked(ui, screens.player)
  ui_touch_policy.set_choice_screen_locked(ui, screens.target)
  ui_touch_policy.set_choice_screen_locked(ui, screens.remote)
  ui_touch_policy.set_choice_screen_locked(ui, screens.building)

  ui_touch_policy.set_many_touch_enabled(ui, market_ui.item_buttons or {}, false)
  if market_ui.confirm_button then
    ui:set_touch_enabled(market_ui.confirm_button, false)
  end
  if market_ui.cancel_button then
    ui:set_touch_enabled(market_ui.cancel_button, false)
  end

  if ui.popup_active and ui.popup_screen and ui.popup_screen.confirm then
    -- 弹窗超时/确认链路依赖该按钮，锁定时仍需保持可点。
    ui:set_touch_enabled(ui.popup_screen.confirm, true)
  end

  -- 业务例外：托管开关与调试开关在输入锁期间仍允许切换。
  ui_touch_policy.set_auto_controls_touch(ui, true)
  ui_touch_policy.set_debug_toggle_touch(ui, true)
end

return input_lock_policy
