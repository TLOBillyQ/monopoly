local availability = require("src.rules.items.availability")
local item_phase = require("src.rules.items.phase")
local number_utils = require("src.foundation.lang.number")

local copy_table = availability.copy_table
local normalize_integer_field = availability.normalize_integer_field

local normalize = {}

normalize.copy_table = copy_table
normalize.normalize_integer_field = normalize_integer_field

local function _normalize_integer_list(values, field_name, choice_kind)
  assert(type(values) == "table", tostring(choice_kind) .. " requires table meta." .. tostring(field_name))
  local normalized = {}
  for index, value in ipairs(values) do
    normalized[index] = assert(
      number_utils.to_integer(value),
      tostring(choice_kind) .. " requires numeric meta." .. tostring(field_name) .. "[" .. tostring(index) .. "]"
    )
  end
  return normalized
end

function normalize.choice_action_option_id(choice_kind, action)
  local normalized_action = copy_table(action)
  normalize_integer_field(normalized_action, "option_id", choice_kind, "action", true)
  return normalized_action
end

function normalize.validate_item_player(game, choice_kind, meta)
  return assert(game:find_player_by_id(meta.player_id), "missing player: " .. tostring(meta.player_id))
end

function normalize.validate_item_target(game, field_name, meta)
  return assert(game:find_player_by_id(meta[field_name]), "missing " .. tostring(field_name) .. ": " .. tostring(meta[field_name]))
end

function normalize.consume_if_needed(player, item_id, already_consumed)
  if not item_id or already_consumed == true then
    return
  end
  local inventory = require("src.rules.items.inventory")
  assert(inventory.consume(player, item_id) == true, "consume committed item failed: " .. tostring(item_id))
end

function normalize.is_repeatable_phase_meta(meta)
  return type(meta) == "table" and item_phase.is_repeatable(meta.phase)
end

function normalize.finish_item_phase_by_name(game, phase)
  if type(phase) ~= "string" or phase == "" then
    return
  end
  item_phase.finish(game, phase)
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

function normalize.steal_meta(_, meta, choice_spec)
  local normalized_meta = normalize.owner_meta(choice_spec.kind, meta, choice_spec)
  normalize_integer_field(normalized_meta, "target_id", choice_spec.kind)
  return normalized_meta
end

function normalize.validate_steal_meta(game, meta, choice_spec)
  normalize.validate_item_player(game, choice_spec.kind, meta)
  normalize.validate_item_target(game, "target_id", meta)
end

function normalize.steal_prompt_meta(_, meta, choice_spec)
  local normalized_meta = normalize.steal_meta(nil, meta, choice_spec)
  normalized_meta.queue = _normalize_integer_list(normalized_meta.queue, "queue", choice_spec.kind)
  normalize_integer_field(normalized_meta, "index", choice_spec.kind)
  return normalized_meta
end

function normalize.validate_steal_prompt_meta(game, meta, choice_spec)
  normalize.validate_steal_meta(game, meta, choice_spec)
  assert(meta.queue[meta.index] ~= nil, tostring(choice_spec.kind) .. " requires meta.queue[meta.index]")
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
