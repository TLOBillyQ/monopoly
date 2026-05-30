local choice_route_policy = require("src.config.choice.route_policy")

local M = {}

local function _find_option(choice, predicate)
  local options = choice and choice.options or nil
  if type(options) ~= "table" then
    return nil
  end
  for _, option in ipairs(options) do
    local option_id = type(option) == "table" and option.id or option
    if predicate(option, option_id) then
      return option, option_id
    end
  end
  return nil
end

local function _fallback_confirm_body(option_label)
  if option_label and option_label ~= "" then
    return "你选的是：" .. tostring(option_label)
  end
  return "请再确认一次"
end

function M.resolve_option_id(option)
  return type(option) == "table" and option.id or option
end

function M.resolve_option_label(option)
  if type(option) == "table" then
    return option.label or (option.id ~= nil and tostring(option.id)) or tostring(option)
  end
  return tostring(option)
end

function M.resolve_option_by_id(choice, option_id)
  if not choice or option_id == nil then
    return nil
  end
  local option = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  return type(option) == "table" and option or nil
end

function M.resolve_option_label_by_id(choice, option_id)
  local option, matched_option_id = _find_option(choice, function(_, current_option_id)
    return current_option_id == option_id
  end)
  if option == nil then
    return nil
  end
  return type(option) == "table" and option.label or tostring(matched_option_id)
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

M.resolve_screen_key = choice_route_policy.resolve

return M

--[[ mutate4lua-manifest
version=2
projectHash=1e35c12d3bd224db
scope.0.id=chunk:src/ui/view/choice_support.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=104
scope.0.semanticHash=1880b68b948810f5
scope.1.id=function:_fallback_confirm_body:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=24
scope.1.semanticHash=33c327bcb736d127
scope.2.id=function:M.resolve_option_id:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=667ddf720635612a
scope.3.id=function:M.resolve_option_label:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=35
scope.3.semanticHash=a7e22f4fd8f101bf
scope.4.id=function:anonymous@41:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=b63d73f7e2597557
scope.5.id=function:M.resolve_option_by_id:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=45
scope.5.semanticHash=1672e51ebd49e508
scope.6.id=function:anonymous@48:48
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=50
scope.6.semanticHash=b63d73f7e2597557
scope.7.id=function:M.resolve_option_label_by_id:47
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=55
scope.7.semanticHash=ddfd0cdca68901fe
scope.8.id=function:M.resolve_secondary_confirm_title:57
scope.8.kind=function
scope.8.startLine=57
scope.8.endLine=66
scope.8.semanticHash=0bbc587697030a3c
scope.9.id=function:M.resolve_secondary_confirm_body:68
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=81
scope.9.semanticHash=2f025d9979168e69
scope.10.id=function:M.build_secondary_confirm_body:83
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=91
scope.10.semanticHash=6d9b79d2e8917f58
scope.11.id=function:M.uses_item_slots:93
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=95
scope.11.semanticHash=dfae0487ccc495ba
scope.12.id=function:M.requires_item_slot_pre_confirm:97
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=99
scope.12.semanticHash=89eb01fc29bae829
]]
