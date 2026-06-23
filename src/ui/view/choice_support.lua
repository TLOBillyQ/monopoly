local choice_route_policy = require("src.config.choice.route_policy")
local choice_options = require("src.ui.view.choice_options")

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
  local kind = choice and choice.kind or nil
  return kind == "item_phase_passive" or kind == "landing_optional_effect"
end

function M.is_cancelable_optional_action_choice(choice)
  return M.is_optional_action_choice(choice) and choice.allow_cancel ~= false
end

M.resolve_screen_key = choice_route_policy.resolve

return M

--[[ mutate4lua-manifest
version=2
projectHash=c5c24122eb05d714
scope.0.id=chunk:src/ui/view/choice_support.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=113
scope.0.semanticHash=d5decd6f63510e91
scope.0.lastMutatedAt=2026-06-23T03:13:46Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=13
scope.0.lastMutationKilled=13
scope.1.id=function:_fallback_confirm_body:19
scope.1.kind=function
scope.1.startLine=19
scope.1.endLine=24
scope.1.semanticHash=33c327bcb736d127
scope.1.lastMutatedAt=2026-06-23T03:13:46Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=6
scope.1.lastMutationKilled=6
scope.2.id=function:M.resolve_option_id:26
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=667ddf720635612a
scope.2.lastMutatedAt=2026-06-23T03:13:46Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=5
scope.2.lastMutationKilled=5
scope.3.id=function:M.resolve_option_label:30
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=35
scope.3.semanticHash=a7e22f4fd8f101bf
scope.3.lastMutatedAt=2026-06-23T03:13:46Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=10
scope.3.lastMutationKilled=10
scope.4.id=function:anonymous@41:41
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=43
scope.4.semanticHash=b63d73f7e2597557
scope.5.id=function:M.resolve_option_by_id:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=45
scope.5.semanticHash=86f6a693a66601b3
scope.5.lastMutatedAt=2026-06-23T03:13:46Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=7
scope.5.lastMutationKilled=7
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
scope.7.lastMutatedAt=2026-06-23T03:13:46Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=8
scope.7.lastMutationKilled=8
scope.8.id=function:M.resolve_secondary_confirm_title:57
scope.8.kind=function
scope.8.startLine=57
scope.8.endLine=66
scope.8.semanticHash=0bbc587697030a3c
scope.8.lastMutatedAt=2026-06-23T03:13:46Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=16
scope.8.lastMutationKilled=16
scope.9.id=function:M.resolve_secondary_confirm_body:68
scope.9.kind=function
scope.9.startLine=68
scope.9.endLine=81
scope.9.semanticHash=2f025d9979168e69
scope.9.lastMutatedAt=2026-06-23T03:13:46Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=17
scope.9.lastMutationKilled=17
scope.10.id=function:M.build_secondary_confirm_body:83
scope.10.kind=function
scope.10.startLine=83
scope.10.endLine=91
scope.10.semanticHash=6d9b79d2e8917f58
scope.10.lastMutatedAt=2026-06-23T03:13:46Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:M.uses_item_slots:93
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=95
scope.11.semanticHash=dfae0487ccc495ba
scope.11.lastMutatedAt=2026-06-23T03:13:46Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:M.requires_item_slot_pre_confirm:97
scope.12.kind=function
scope.12.startLine=97
scope.12.endLine=99
scope.12.semanticHash=89eb01fc29bae829
scope.12.lastMutatedAt=2026-06-23T03:13:46Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=4
scope.12.lastMutationKilled=4
scope.13.id=function:M.is_optional_action_choice:101
scope.13.kind=function
scope.13.startLine=101
scope.13.endLine=104
scope.13.semanticHash=00f02060e728d4bc
scope.13.lastMutatedAt=2026-06-23T03:13:46Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=7
scope.13.lastMutationKilled=7
scope.14.id=function:M.is_cancelable_optional_action_choice:106
scope.14.kind=function
scope.14.startLine=106
scope.14.endLine=108
scope.14.semanticHash=6c547b481afe8ecf
scope.14.lastMutatedAt=2026-06-23T03:13:46Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=4
scope.14.lastMutationKilled=4
]]
