local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")

local copy_table = availability.copy_table
local normalize_integer_field = availability.normalize_integer_field

local normalize = {}

normalize.copy_table = copy_table
normalize.normalize_integer_field = normalize_integer_field

function normalize.choice_action_option_id(choice_kind, action)
  local normalized_action = copy_table(action)
  normalize_integer_field(normalized_action, "option_id", choice_kind, "action", true)
  return normalized_action
end

function normalize.validate_item_player(game, choice_kind, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

function normalize.is_repeatable_phase_meta(meta)
  return type(meta) == "table" and item_phase.is_repeatable(meta.phase)
end

function normalize.merge_after_action_anim(result, final_res)
  if type(result) == "table" and type(result.after_action_anim) == "table" then
    final_res.after_action_anim = result.after_action_anim
  end
  return final_res
end

function normalize.owner_meta(choice_kind, meta, choice_spec)
  local normalized_meta = copy_table(meta)
  normalize_integer_field(normalized_meta, "player_id", choice_kind)
  choice_spec.owner_role_id = choice_spec.owner_role_id or normalized_meta.player_id
  return normalized_meta
end

function normalize.item_phase_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  assert(type(normalized_meta.phase) == "string" and normalized_meta.phase ~= "",
    tostring(choice_spec.kind) .. " requires string meta.phase")
  return normalized_meta
end

function normalize.validate_item_phase_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
  assert(item_phase.is_enabled(meta.phase), tostring(choice_spec.kind) .. " requires enabled meta.phase")
end

function normalize.validate_item_owner_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
end

function normalize.item_target_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "item_id", choice_spec.kind)
  return normalized_meta
end

function normalize.remote_dice_meta(_, meta, choice_spec)
  local normalized_meta = normalize.item_target_meta(nil, meta, choice_spec)
  normalize_integer_field(normalized_meta, "dice_count", choice_spec.kind)
  return normalized_meta
end

function normalize.validate_remote_dice_meta(game, meta, choice_spec)
  normalize.validate_item_owner_meta(game, meta, choice_spec)
  if meta.dice_count ~= nil then
    assert(meta.dice_count >= 1, tostring(choice_spec.kind) .. " requires positive meta.dice_count")
  end
end

return normalize

--[[ mutate4lua-manifest
version=4
projectHash=13232613d2ff12f7
scope.0.id=chunk:src/rules/choice_handlers/item_normalize.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=76
scope.0.semanticHash=489ec7b9f6ba7401
scope.1.id=function:normalize.choice_action_option_id
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=16
scope.1.semanticHash=5bd3a55d9b6705e5
scope.2.id=function:normalize.validate_item_player
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=3607f67e4d7766bd
scope.3.id=function:normalize.is_repeatable_phase_meta
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=e59df6bf3529c88c
scope.4.id=function:normalize.merge_after_action_anim
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=31
scope.4.semanticHash=5337d992223f999d
scope.5.id=function:normalize.owner_meta
scope.5.kind=function
scope.5.startLine=33
scope.5.endLine=38
scope.5.semanticHash=f68aba342f7196f8
scope.6.id=function:normalize.item_phase_meta
scope.6.kind=function
scope.6.startLine=40
scope.6.endLine=45
scope.6.semanticHash=73dc0229828c979e
scope.7.id=function:normalize.validate_item_phase_meta
scope.7.kind=function
scope.7.startLine=47
scope.7.endLine=50
scope.7.semanticHash=d199c6e81eebe212
scope.8.id=function:normalize.validate_item_owner_meta
scope.8.kind=function
scope.8.startLine=52
scope.8.endLine=54
scope.8.semanticHash=b092cf3a70cecce3
scope.9.id=function:normalize.item_target_meta
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=60
scope.9.semanticHash=43cf4fddfbb8efd9
scope.10.id=function:normalize.remote_dice_meta
scope.10.kind=function
scope.10.startLine=62
scope.10.endLine=66
scope.10.semanticHash=9e770230c0986ca7
scope.11.id=function:normalize.validate_remote_dice_meta
scope.11.kind=function
scope.11.startLine=68
scope.11.endLine=73
scope.11.semanticHash=f84f15fabf562521
]]
