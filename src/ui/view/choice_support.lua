local choice_route_policy = require("src.config.choice.route_policy")
local choice_options = require("src.ui.view.choice_options")
local optional_action_choice = require("src.turn.optional_action_choice")

local M = {}

M.resolve_option_id = choice_options.resolve_option_id
M.resolve_option_label = choice_options.resolve_option_label
M.resolve_option_by_id = choice_options.resolve_option_by_id
M.resolve_option_label_by_id = choice_options.resolve_option_label_by_id

local function _fallback_confirm_body(option_label)
  if option_label and option_label ~= "" then
    return "你选的是：" .. tostring(option_label)
  end
  return "请再确认一次"
end

local function _non_empty_string(value)
  return type(value) == "string" and value ~= ""
end

function M.resolve_secondary_confirm_title(choice, _game, _source_screen, option_id)
  local option = M.resolve_option_by_id(choice, option_id)
  if option and _non_empty_string(option.confirm_title) then
    return option.confirm_title
  end
  if choice and _non_empty_string(choice.confirm_title) then
    return choice.confirm_title
  end
  return "请确认"
end

local function _option_confirm_body(choice, option_id)
  local option = M.resolve_option_by_id(choice, option_id)
  if option and _non_empty_string(option.confirm_body) then
    return option.confirm_body
  end
  return nil
end

local function _choice_confirm_body(choice)
  if _non_empty_string(choice.confirm_body) then
    return choice.confirm_body
  end
  return nil
end

local function _resolved_option_label(choice, option_id, option_label)
  return option_label or M.resolve_option_label_by_id(choice, option_id)
end

function M.resolve_secondary_confirm_body(choice, _game, _source_screen, option_id, option_label)
  if not choice then
    return _fallback_confirm_body(option_label)
  end
  local body = _option_confirm_body(choice, option_id) or _choice_confirm_body(choice)
  if body ~= nil then
    return body
  end
  return _fallback_confirm_body(_resolved_option_label(choice, option_id, option_label))
end

function M.build_secondary_confirm_body(choice, game, selected_option_id)
  return M.resolve_secondary_confirm_body(
    choice,
    game,
    "secondary_confirm",
    selected_option_id,
    M.resolve_option_label_by_id(choice, selected_option_id)
  )
end

function M.uses_item_slots(choice)
  return choice ~= nil and choice.uses_item_slots == true
end

function M.requires_item_slot_pre_confirm(choice)
  return choice ~= nil and choice.pre_confirm_before_slot_pick == true
end

function M.is_optional_action_choice(choice)
  return optional_action_choice.is_optional_action_choice(choice)
end

function M.is_cancelable_optional_action_choice(choice)
  return optional_action_choice.is_cancelable_optional_action_choice(choice)
end

function M.is_pre_action_item_phase_passive(choice)
  return optional_action_choice.is_pre_action_item_phase_passive(choice)
end

function M.is_item_target_selection_choice(choice)
  return optional_action_choice.is_item_target_selection_choice(choice)
end

function M.is_base_cancel_choice(choice)
  return optional_action_choice.is_base_cancel_choice(choice)
end

M.resolve_screen_key = choice_route_policy.resolve

return M

--[[ mutate4lua-manifest
version=4
projectHash=e71dae92d0f2568a
scope.0.id=chunk:src/ui/view/choice_support.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=f1c88e41bdb2b5b4
scope.1.id=function:_fallback_confirm_body
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=bee1ce2fd755a9a2
scope.2.id=function:_non_empty_string
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=21
scope.2.semanticHash=bc99f6081a215c33
scope.3.id=function:M.resolve_secondary_confirm_title
scope.3.kind=function
scope.3.startLine=23
scope.3.endLine=32
scope.3.semanticHash=5646de95c94a953e
scope.4.id=function:_option_confirm_body
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=40
scope.4.semanticHash=58c6dead68418bad
scope.5.id=function:_choice_confirm_body
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=47
scope.5.semanticHash=8a6cc1a419b63f48
scope.6.id=function:_resolved_option_label
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=51
scope.6.semanticHash=657b14f5307a2dfd
scope.7.id=function:M.resolve_secondary_confirm_body
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=62
scope.7.semanticHash=471637ba02489f09
scope.8.id=function:M.build_secondary_confirm_body
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=72
scope.8.semanticHash=59eecb966a30fc29
scope.9.id=function:M.uses_item_slots
scope.9.kind=function
scope.9.startLine=74
scope.9.endLine=76
scope.9.semanticHash=be8994585243633b
scope.10.id=function:M.requires_item_slot_pre_confirm
scope.10.kind=function
scope.10.startLine=78
scope.10.endLine=80
scope.10.semanticHash=be8994585243633b
scope.11.id=function:M.is_optional_action_choice
scope.11.kind=function
scope.11.startLine=82
scope.11.endLine=84
scope.11.semanticHash=f1ce1850b7232305
scope.12.id=function:M.is_cancelable_optional_action_choice
scope.12.kind=function
scope.12.startLine=86
scope.12.endLine=88
scope.12.semanticHash=f1ce1850b7232305
scope.13.id=function:M.is_pre_action_item_phase_passive
scope.13.kind=function
scope.13.startLine=90
scope.13.endLine=92
scope.13.semanticHash=f1ce1850b7232305
scope.14.id=function:M.is_item_target_selection_choice
scope.14.kind=function
scope.14.startLine=94
scope.14.endLine=96
scope.14.semanticHash=f1ce1850b7232305
scope.15.id=function:M.is_base_cancel_choice
scope.15.kind=function
scope.15.startLine=98
scope.15.endLine=100
scope.15.semanticHash=f1ce1850b7232305
]]
