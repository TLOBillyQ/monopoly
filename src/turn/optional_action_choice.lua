local optional_action_choice = {}

function optional_action_choice.is_optional_action_choice(choice)
  local kind = choice and choice.kind or nil
  return kind == "item_phase_passive" or kind == "landing_optional_effect"
end

function optional_action_choice.is_cancelable_optional_action_choice(choice)
  return optional_action_choice.is_optional_action_choice(choice) and choice.allow_cancel ~= false
end

local function _is_cancelable_item_phase_passive(choice)
  if not optional_action_choice.is_cancelable_optional_action_choice(choice) then
    return false
  end
  return choice.kind == "item_phase_passive"
end

-- A pre_action item phase passive choice is opened at turn start, before the roll.
-- Unlike post_action/landing optional phases (which resolve through the 结束 button),
-- skipping it belongs on the 行动 button so 行动 precedes the roll even while a
-- pre-action card is still in the bag. Item target selection (passive_origin) is a
-- usage follow-up with its own base-cancel exit and is excluded here.
function optional_action_choice.is_pre_action_item_phase_passive(choice)
  if not _is_cancelable_item_phase_passive(choice) then
    return false
  end
  local meta = choice.meta
  return type(meta) == "table" and meta.phase == "pre_action" and meta.passive_origin ~= true
end

-- Item target selection is a follow-up of item usage (道具使用后续选择): rules
-- marks every followup choice_spec with meta.passive_origin
-- (src/rules/choice_handlers/item_phase_handlers._decorate_phase_followup); the
-- kind varies per card (item_target_player / remote_dice_value / roadblock_target
-- / demolish_target), so the marker, not the kind, is the truth source. The base
-- screen keeps its cancel button up as the exit back to the item phase window.
function optional_action_choice.is_item_target_selection_choice(choice)
  local meta = choice and choice.meta
  return type(meta) == "table" and meta.passive_origin == true
end

-- 基础屏取消按钮唯一口径：渲染显隐(panel_action_controls)与意图构造(route_base)
-- 都只问这个谓词，两边永不脱节。只有道具使用后续选择拥有基础屏取消出口
-- （取消 → rules 侧 followup_cancel → reopen_or_finish 重开道具窗、卡不消耗）；
-- escrow / 预消耗 followup 由 rules 写 allow_cancel=false 关掉出口。
function optional_action_choice.is_base_cancel_choice(choice)
  return optional_action_choice.is_item_target_selection_choice(choice)
    and choice.allow_cancel ~= false
end

return optional_action_choice

--[[ mutate4lua-manifest
version=4
projectHash=d3cda1983c3164b0
scope.0.id=chunk:src/turn/optional_action_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=53
scope.0.semanticHash=c6e5af9b83fd5374
scope.1.id=function:optional_action_choice.is_optional_action_choice
scope.1.kind=function
scope.1.startLine=3
scope.1.endLine=6
scope.1.semanticHash=21a4b5f0add45b92
scope.2.id=function:optional_action_choice.is_cancelable_optional_action_choice
scope.2.kind=function
scope.2.startLine=8
scope.2.endLine=10
scope.2.semanticHash=f5a8027e67a6d0b2
scope.3.id=function:_is_cancelable_item_phase_passive
scope.3.kind=function
scope.3.startLine=12
scope.3.endLine=17
scope.3.semanticHash=55a0a7bb85479e59
scope.4.id=function:optional_action_choice.is_pre_action_item_phase_passive
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=30
scope.4.semanticHash=c803002dda2c4bb3
scope.5.id=function:optional_action_choice.is_item_target_selection_choice
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=41
scope.5.semanticHash=adfc32a7cde87c00
scope.6.id=function:optional_action_choice.is_base_cancel_choice
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=50
scope.6.semanticHash=f5a8027e67a6d0b2
]]
