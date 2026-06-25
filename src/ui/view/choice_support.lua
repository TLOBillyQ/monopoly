local choice_route_policy = require("src.config.choice.route_policy")
local choice_options = require("src.ui.view.choice_options")
local optional_action_completion = require("src.turn.optional_action_completion")

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

function M.resolve_secondary_confirm_title(choice, _game, _source_screen, option_id)
  local option = M.resolve_option_by_id(choice, option_id)
  if option and type(option.confirm_title) == "string" and option.confirm_title ~= "" then
    return option.confirm_title
  end
  if choice and type(choice.confirm_title) == "string" and choice.confirm_title ~= "" then
    return choice.confirm_title
  end
  return "请确认"
end

function M.resolve_secondary_confirm_body(choice, _game, _source_screen, option_id, option_label)
  if not choice then
    return _fallback_confirm_body(option_label)
  end

  local option = M.resolve_option_by_id(choice, option_id)
  if option and type(option.confirm_body) == "string" and option.confirm_body ~= "" then
    return option.confirm_body
  end
  if type(choice.confirm_body) == "string" and choice.confirm_body ~= "" then
    return choice.confirm_body
  end
  return _fallback_confirm_body(option_label or M.resolve_option_label_by_id(choice, option_id))
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
  return optional_action_completion.is_optional_action_choice(choice)
end

function M.is_cancelable_optional_action_choice(choice)
  return optional_action_completion.is_cancelable_optional_action_choice(choice)
end

M.resolve_screen_key = choice_route_policy.resolve

return M

--[[ mutate4lua-manifest
version=2
projectHash=663ac734cda22e60
scope.0.id=chunk:src/ui/view/choice_support.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=74
scope.0.semanticHash=23ffbc44ddd3e039
scope.1.id=function:_fallback_confirm_body:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=17
scope.1.semanticHash=33c327bcb736d127
scope.2.id=function:M.resolve_secondary_confirm_title:19
scope.2.kind=function
scope.2.startLine=19
scope.2.endLine=28
scope.2.semanticHash=0bbc587697030a3c
scope.3.id=function:M.resolve_secondary_confirm_body:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=43
scope.3.semanticHash=2f025d9979168e69
scope.4.id=function:M.build_secondary_confirm_body:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=53
scope.4.semanticHash=6d9b79d2e8917f58
scope.5.id=function:M.uses_item_slots:55
scope.5.kind=function
scope.5.startLine=55
scope.5.endLine=57
scope.5.semanticHash=dfae0487ccc495ba
scope.6.id=function:M.requires_item_slot_pre_confirm:59
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=61
scope.6.semanticHash=89eb01fc29bae829
scope.7.id=function:M.is_optional_action_choice:63
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=65
scope.7.semanticHash=1fb1dc4cbbd166cb
scope.8.id=function:M.is_cancelable_optional_action_choice:67
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=69
scope.8.semanticHash=b59ee131e29e96c7
]]
