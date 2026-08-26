-- secondary_confirm（通用二次确认）选择屏的唯一归宿：schema 引用 + 开屏 +
-- 预确认变体 + 选项切换时 copy 刷新 + 点击意图。
-- 确认键是活的，与 target 屏的 inert 确认键相反。
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

local function _first_selected_id(choice)
  local first_option = choice.options and choice.options[1] or nil
  return choice_common.resolve_option_id(first_option)
end

-- 常规二次确认开屏。
function M.open(state, choice, choice_id)
  local ui, screen = openers.open_screen(state, "secondary_confirm", choice, choice_id)
  local selected = _first_selected_id(choice)
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
-- 注:resolve_* 的第三参 _source_screen 按签名约定不被读取,此处 "base_inline"
-- 字面量的变异是等价变异(不可杀),不要为它补钉文案的测试。
function M.open_item_phase_pre_confirm(state, choice)
  pending_confirmation.enter(state, pending_confirmation.SOURCE_ITEM_PHASE_ASK)
  local title = choice_common.resolve_secondary_confirm_title(choice, state.game, "base_inline", nil)
  local body = choice_common.resolve_secondary_confirm_body(choice, state.game, "base_inline", nil, nil)
  M.open_pre_confirm(state, choice, "__item_phase_ask__", title, body)
end

local function _is_secondary_confirm_active(ui)
  return ui ~= nil and ui.active_choice_screen_key == "secondary_confirm"
end

local function _current_choice(state)
  local current_model = runtime_state.get_ui_model(state)
  return current_model and current_model.choice or nil
end

local function _apply_secondary_confirm_copy(state, ui, screen, choice, option_id)
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

-- 当已打开的 secondary_confirm 屏所选 option 变化时，刷新标题/正文文案。
local function _confirm_screen(ui)
  return ui.choice_screens and ui.choice_screens.secondary_confirm or nil
end

local function _refresh_ready(screen, choice)
  return screen ~= nil and choice ~= nil
end

function M.refresh_copy(state, option_id)
  local ui = state and state.ui
  if not _is_secondary_confirm_active(ui) then
    return
  end
  local screen = _confirm_screen(ui)
  local choice = _current_choice(state)
  if not _refresh_ready(screen, choice) then
    return
  end
  _apply_secondary_confirm_copy(state, ui, screen, choice, option_id)
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

return M

--[[ mutate4lua-manifest
version=4
projectHash=59c82b6cc0eb13fa
scope.0.id=chunk:src/ui/screens/secondary_confirm.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=132
scope.0.semanticHash=4b560a38ef7f453a
scope.1.id=function:M.descriptor
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=24
scope.1.semanticHash=cee80d17110e9a0c
scope.2.id=function:_first_selected_id
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=29
scope.2.semanticHash=244c74049fc99ebd
scope.3.id=function:M.open
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=44
scope.3.semanticHash=465396505dc06b41
scope.4.id=function:M.open_pre_confirm
scope.4.kind=function
scope.4.startLine=47
scope.4.endLine=56
scope.4.semanticHash=d29a6a2c6bbf19aa
scope.5.id=function:M.open_item_phase_pre_confirm
scope.5.kind=function
scope.5.startLine=59
scope.5.endLine=65
scope.5.semanticHash=cf6f1283b4bdcf25
scope.6.id=function:_is_secondary_confirm_active
scope.6.kind=function
scope.6.startLine=67
scope.6.endLine=69
scope.6.semanticHash=812996efe26ec454
scope.7.id=function:_current_choice
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=74
scope.7.semanticHash=9225cfe7b87d962b
scope.8.id=function:_apply_secondary_confirm_copy
scope.8.kind=function
scope.8.startLine=76
scope.8.endLine=90
scope.8.semanticHash=120174ab1e9b6f5b
scope.9.id=function:_confirm_screen
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=95
scope.9.semanticHash=13ddff47d34fa2ed
scope.10.id=function:_refresh_ready
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=99
scope.10.semanticHash=a17812a9544dad33
scope.11.id=function:M.refresh_copy
scope.11.kind=function
scope.11.startLine=101
scope.11.endLine=112
scope.11.semanticHash=67b8fdce82b59904
scope.12.id=function:M.build_route_specs
scope.12.kind=function
scope.12.startLine=114
scope.12.endLine=129
scope.12.semanticHash=fc1fec1d153b2325
scope.13.id=function:<anonymous>
scope.13.kind=function
scope.13.startLine=118
scope.13.endLine=120
scope.13.semanticHash=28a7b4c21e049d18
scope.14.id=function:<anonymous>#2
scope.14.kind=function
scope.14.startLine=124
scope.14.endLine=126
scope.14.semanticHash=28a7b4c21e049d18
]]
