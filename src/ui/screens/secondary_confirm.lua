-- secondary_confirm（通用二次确认）选择屏的唯一归宿：schema 引用 + 开屏 +
-- 预确认变体 + 选项切换时 copy 刷新 + 点击意图。
-- 收编自 node_ops.build_choice_screens.secondary_confirm /
-- choice_openers.open_secondary_confirm_screen / choice_openers.open_pre_confirm_screen /
-- modal.lua 的 _refresh_secondary_confirm_copy / _open_item_phase_pre_confirm /
-- route_secondary_confirm.build。确认键是活的，与 target 屏的 inert 确认键相反。
local registry = require("src.ui.screens.registry")
local schema = require("src.ui.schema.secondary_confirm")
local canvas = require("src.ui.coord.canvas_coordinator")
local openers = require("src.ui.coord.choice_openers")
local modal_state = require("src.ui.state.modal")
local choice_common = require("src.ui.coord.choice_helpers")
local runtime_state = require("src.ui.state.runtime")
local pending_confirmation = require("src.ui.state.pending_confirmation")
local ui_event_intents = require("src.ui.input.event_intents")

local M = { key = "secondary_confirm", canvas = canvas.CANVAS_SECONDARY_CONFIRM }

function M.descriptor()
  return {
    key = "secondary_confirm",
    root = schema.canvas,
    title = schema.title,
    body = schema.body,
    confirm = schema.confirm,
    cancel = schema.cancel,
  }
end

-- 常规二次确认开屏。
function M.open(state, choice, choice_id)
  local ui, screen = openers.open_screen(state, "secondary_confirm", choice, choice_id)
  local first_option = choice.options and choice.options[1] or nil
  local selected = choice_common.resolve_option_id(first_option)
  ui:set_label(screen.title, choice_common.resolve_secondary_confirm_title(choice, state.game, "secondary_confirm", selected))
  if screen.body then
    ui:set_label(screen.body, choice_common.build_secondary_confirm_body(choice, state.game, selected))
  end

  openers.set_action_button(ui, screen.confirm, true, selected ~= nil, "")
  local allow_cancel = choice.allow_cancel ~= false
  openers.set_action_button(ui, screen.cancel, allow_cancel, allow_cancel, allow_cancel and "" or nil)
  modal_state.open_choice(state, choice_id, { selected }, selected)
end

-- 预确认变体：先选具体 option 后再弹出的二次确认。
function M.open_pre_confirm(state, choice, option_id, title, body)
  local ui, screen = openers.open_screen(state, "secondary_confirm", choice, choice.id)
  ui:set_label(screen.title, title or "请确认")
  if screen.body then
    ui:set_label(screen.body, body or "")
  end
  openers.set_action_button(ui, screen.confirm, true, option_id ~= nil, "")
  openers.set_action_button(ui, screen.cancel, true, true, "")
  modal_state.open_choice(state, choice.id, { option_id }, option_id)
end

-- 道具阶段询问用预确认（由 modal_presenter 在 base_inline 路径触发）。
function M.open_item_phase_pre_confirm(state, choice)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  state._suppress_item_slot_highlight_until_pick = true
  local title = choice_common.resolve_secondary_confirm_title(choice, state.game, "base_inline", nil)
  local body = choice_common.resolve_secondary_confirm_body(choice, state.game, "base_inline", nil, nil)
  M.open_pre_confirm(state, choice, "__item_phase_ask__", title, body)
end

-- 当已打开的 secondary_confirm 屏所选 option 变化时，刷新标题/正文文案。
function M.refresh_copy(state, option_id)
  local ui = state and state.ui
  if not ui or ui.active_choice_screen_key ~= "secondary_confirm" then
    return
  end
  local screen = ui.choice_screens and ui.choice_screens.secondary_confirm or nil
  local current_model = runtime_state.get_ui_model(state)
  local choice = current_model and current_model.choice or nil
  if not screen or not choice then
    return
  end
  local option_label = choice_common.resolve_option_label_by_id(choice, option_id)
  if screen.title then
    ui:set_label(screen.title, choice_common.resolve_secondary_confirm_title(choice, state.game, "secondary_confirm", option_id))
  end
  if screen.body then
    ui:set_label(screen.body, choice_common.resolve_secondary_confirm_body(
      choice,
      state.game,
      "secondary_confirm",
      option_id,
      option_label
    ))
  end
end

function M.build_route_specs(state)
  return {
    {
      name = schema.confirm,
      build_intent = function()
        return ui_event_intents.choice_confirm_intent(state, "secondary_confirm")
      end,
    },
    {
      name = schema.cancel,
      build_intent = function()
        return ui_event_intents.choice_cancel_intent(state, "secondary_cancel")
      end,
    },
  }
end

registry.register(M)
return M
