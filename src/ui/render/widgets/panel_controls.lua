local base_nodes = require("src.ui.schema.base")
local role_id_utils = require("src.foundation.identity")
local ui_touch_policy_runtime = require("src.ui.input.touch")
local panel_interrupt = require("src.ui.state.panel_interrupt")
local panel_action_controls = require("src.ui.render.widgets.panel_action_controls")

local panel_controls = {}

panel_controls.apply_countdown = panel_action_controls.apply_countdown
panel_controls.apply_action_hint = panel_action_controls.apply_action_hint
panel_controls.apply_base_action_controls = panel_action_controls.apply_base_action_controls

local function _set_visible_many(ui, names, visible)
  for _, name in ipairs(names or {}) do
    ui:set_visible(name, visible)
  end
end

function panel_controls.apply_base_non_player_visibility(ui, visible)
  assert(ui ~= nil, "missing ui")
  local value = visible == true
  _set_visible_many(ui, ui.base_hidden_nodes, value)
  _set_visible_many(ui, ui.base_hidden_labels, value)
end

local function _resolve_auto_label(panel, display_player_id)
  if panel == nil then
    return nil
  end
  local labels_by_player = panel.auto_label_by_player
  if labels_by_player ~= nil and display_player_id ~= nil then
    local auto_label = labels_by_player[display_player_id]
    if auto_label then
      return auto_label
    end
  end
  return panel.auto_label
end

local function _apply_auto_label(ui, panel, display_player_id)
  local auto_label = _resolve_auto_label(panel, display_player_id)
  if auto_label == nil or not ui.set_label then
    return
  end
  ui:set_label(base_nodes.auto_label, auto_label)
end

local function _show_auto_controls(ui, controls)
  for _, name in ipairs(controls) do
    ui:set_visible(name, true)
  end
end

local function _resolve_auto_controls(ui)
  return ui.auto_control_nodes or { base_nodes.auto_button, base_nodes.auto_label }
end

local function _is_player_role(ctx)
  return ctx.is_player_role == true
end

function panel_controls.render_auto_controls_for_role(ui, ctx, ui_model, ui_touch_policy)
  assert(ui ~= nil, "missing ui")
  local controls = _resolve_auto_controls(ui)
  local panel = ui_model and ui_model.panel or nil
  _apply_auto_label(ui, panel, ctx.display_player_id)
  _show_auto_controls(ui, controls)
  ui_touch_policy.set_auto_controls_touch(ui, _is_player_role(ctx), controls)
end

function panel_controls.is_base_non_player_visible(ui, ctx)
  if ui.input_blocked then
    return false
  end
  if panel_interrupt.settlement_type(ui) ~= nil then
    return false
  end
  return ctx.can_operate == true
end

-- 基础屏取消按钮的窄门(道具 followup 取消口径):followup 的选择屏开屏即置
-- choice_active,base_visible 整门必然落下,而取消按钮是该阶段唯一退出口——
-- 遮挡判定豁免 choice_active,其余(输入锁/弹窗/黑市/移动)与 per-role
-- can_operate 照常拦。
function panel_controls.is_base_cancel_allowed(ui, ctx)
  if ui.input_blocked then
    return false
  end
  if panel_interrupt.settlement_type_excluding_choice(ui) ~= nil then
    return false
  end
  return ctx.can_operate == true
end

-- 道具槽 touch 门的 allow_interact(#162 四次复验):语义是「无真弹层遮挡」。
-- input_blocked 与 move_active 是阶段位(他人回合墙钟几乎全程如此),不关此门;
-- 只有弹窗/黑市/机会覆盖弹层才关。base 其它控件维持 can_operate 口径。
function panel_controls.is_slot_touch_allowed(ui)
  return not panel_interrupt.is_overlay_visible(ui)
end

local function _auto_effect_role_id(ctx)
  if ctx.is_player_role ~= true then
    return nil
  end
  return ctx.role_id
end

local function _resolve_auto_effect_visible(ui_model, ctx)
  local role_id = _auto_effect_role_id(ctx)
  if role_id == nil then return false end
  local delegated_by_player = ui_model.delegated_by_player or {}
  return role_id_utils.read(delegated_by_player, role_id) == true
end

function panel_controls.apply_auto_effect(ui, ui_model, ctx)
  ui:set_visible(base_nodes.auto_effect, _resolve_auto_effect_visible(ui_model, ctx))
  ui:set_touch_enabled(base_nodes.auto_effect, false)
end

function panel_controls.resolve_skin_entry_visible(ui_model, ctx)
  local current_player_id = role_id_utils.normalize(ui_model.current_player_id)
  if current_player_id == nil then
    return false
  end
  return ctx.can_operate ~= true
end

function panel_controls.apply_skin_entry_visibility(ui, visible)
  local value = visible == true
  ui:set_visible(base_nodes.skin_button, value)
  ui:set_visible(base_nodes.skin_label, value)
  ui:set_touch_enabled(base_nodes.skin_button, value)
  ui:set_touch_enabled(base_nodes.skin_label, false)
  ui_touch_policy_runtime.set_many_touch_enabled(ui, base_nodes.skin_effect_nodes, false)
end

return panel_controls

--[[ mutate4lua-manifest
version=4
projectHash=f57cde73d49781bb
scope.0.id=chunk:src/ui/render/widgets/panel_controls.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=139
scope.0.semanticHash=db621925d99fc9e4
scope.1.id=function:_set_visible_many
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=17
scope.1.semanticHash=3c2d101cb46ddf99
scope.2.id=function:panel_controls.apply_base_non_player_visibility
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=24
scope.2.semanticHash=f2c651017543a051
scope.3.id=function:_resolve_auto_label
scope.3.kind=function
scope.3.startLine=26
scope.3.endLine=38
scope.3.semanticHash=e5d9dda5346dce2f
scope.4.id=function:_apply_auto_label
scope.4.kind=function
scope.4.startLine=40
scope.4.endLine=46
scope.4.semanticHash=b22b9989da0cd6b9
scope.5.id=function:_show_auto_controls
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=52
scope.5.semanticHash=580ab51c17061833
scope.6.id=function:_resolve_auto_controls
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=56
scope.6.semanticHash=cee7a6d557515fd5
scope.7.id=function:_is_player_role
scope.7.kind=function
scope.7.startLine=58
scope.7.endLine=60
scope.7.semanticHash=04dff2c832cce8d0
scope.8.id=function:panel_controls.render_auto_controls_for_role
scope.8.kind=function
scope.8.startLine=62
scope.8.endLine=69
scope.8.semanticHash=1ec73860386d9444
scope.9.id=function:panel_controls.is_base_non_player_visible
scope.9.kind=function
scope.9.startLine=71
scope.9.endLine=79
scope.9.semanticHash=46bbc0963149bb42
scope.10.id=function:panel_controls.is_base_cancel_allowed
scope.10.kind=function
scope.10.startLine=85
scope.10.endLine=93
scope.10.semanticHash=46bbc0963149bb42
scope.11.id=function:panel_controls.is_slot_touch_allowed
scope.11.kind=function
scope.11.startLine=98
scope.11.endLine=100
scope.11.semanticHash=80dffec319f96311
scope.12.id=function:_auto_effect_role_id
scope.12.kind=function
scope.12.startLine=102
scope.12.endLine=107
scope.12.semanticHash=064ea50b78ad1183
scope.13.id=function:_resolve_auto_effect_visible
scope.13.kind=function
scope.13.startLine=109
scope.13.endLine=114
scope.13.semanticHash=5b0f35a7faad1b76
scope.14.id=function:panel_controls.apply_auto_effect
scope.14.kind=function
scope.14.startLine=116
scope.14.endLine=119
scope.14.semanticHash=ca4bb529c68e47be
scope.15.id=function:panel_controls.resolve_skin_entry_visible
scope.15.kind=function
scope.15.startLine=121
scope.15.endLine=127
scope.15.semanticHash=fd40b2203d2ff9e4
scope.16.id=function:panel_controls.apply_skin_entry_visibility
scope.16.kind=function
scope.16.startLine=129
scope.16.endLine=136
scope.16.semanticHash=fc0cb2b7a77f598c
]]
