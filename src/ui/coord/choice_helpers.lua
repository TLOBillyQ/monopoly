local choice_support = require("src.ui.view.choice_support")
local runtime = require("src.ui.render.runtime_ui")
local canvas = require("src.ui.coord.canvas_coordinator")
local runtime_state = require("src.ui.state.runtime")
local role_context = require("src.ui.view.role_context")
local ui_controls = require("src.ui.render.support.ui_controls")

local M = {}

function M.resolve_canvas_for_screen(screen_key)
  return require("src.ui.screens.registry").canvas_for(screen_key) or canvas.CANVAS_BASE
end

function M.hide_choice_screens(ui)
  for _, screen in pairs(ui.choice_screens or {}) do
    ui_controls.reset_choice_screen(ui, screen)
  end
  ui.choice_active = false
  ui.active_choice_screen_key = nil
end

M.resolve_option_id = choice_support.resolve_option_id
M.resolve_option_label = choice_support.resolve_option_label
M.resolve_option_by_id = choice_support.resolve_option_by_id
M.resolve_option_label_by_id = choice_support.resolve_option_label_by_id

function M.set_option_node(ui, node_name, option)
  local option_id = M.resolve_option_id(option)
  ui_controls.set_control_state(ui, node_name, {
    visible = option ~= nil,
    touch_enabled = option ~= nil,
  })
  if option ~= nil then
    ui:set_button(node_name, M.resolve_option_label(option))
  end
  return option_id
end

M.resolve_secondary_confirm_title = choice_support.resolve_secondary_confirm_title
M.resolve_secondary_confirm_body = choice_support.resolve_secondary_confirm_body
M.build_secondary_confirm_body = choice_support.build_secondary_confirm_body
M.uses_item_slots = choice_support.uses_item_slots
M.requires_item_slot_pre_confirm = choice_support.requires_item_slot_pre_confirm

function M.switch_modal_canvas(state, target_canvas)
  local ui = state.ui
  runtime.for_each_role_or_global(function(role)
    local current_model = runtime_state.get_ui_model(state)
    local ctx = role_context.resolve(role, current_model, { runtime = runtime })
    local canvas_target = ctx.can_operate == true and target_canvas or canvas.CANVAS_BASE
    if role then
      canvas.switch_for_role(ui, canvas_target, role)
    else
      canvas.switch(ui, canvas_target)
    end
  end)
  runtime.set_client_role(nil)
end

M.resolve_screen_key = choice_support.resolve_screen_key

return M

--[[ mutate4lua-manifest
version=2
projectHash=27449ba62c4fee28
scope.0.id=chunk:src/ui/coord/choice_helpers.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=63
scope.0.semanticHash=07f12e833df8bb1e
scope.1.id=function:M.resolve_canvas_for_screen:10
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=12
scope.1.semanticHash=2c8c3b09c72c6be2
scope.2.id=function:M.set_option_node:27
scope.2.kind=function
scope.2.startLine=27
scope.2.endLine=37
scope.2.semanticHash=0c0fdbccba12fe64
scope.3.id=function:anonymous@47:47
scope.3.kind=function
scope.3.startLine=47
scope.3.endLine=56
scope.3.semanticHash=b45a68c95c96af80
scope.4.id=function:M.switch_modal_canvas:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=58
scope.4.semanticHash=3c3db8a7f7f2285c
]]
