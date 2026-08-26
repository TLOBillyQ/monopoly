local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local angel_feedback = require("src.rules.items.angel_feedback")

local demolish_hospital = {}

local list_unpack = table.unpack

function demolish_hospital.collect_targets(game, idx, item_id)
  local occupants = assert(game.occupants[idx], "missing occupants: " .. tostring(idx))
  local targets = {}
  local snapshot = { list_unpack(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = assert(game:find_player_by_id(pid), "missing target player: " .. tostring(pid))
    if game:angel_immune_to_item(target, item_id) then
      angel_feedback.publish(game, target, "导弹", { tile_index = idx })
    else
      targets[#targets + 1] = target
    end
  end
  return targets
end

function demolish_hospital.target_player_ids(targets)
  local ids = {}
  for index, target in ipairs(targets or {}) do
    ids[index] = target.id
  end
  return ids
end

local function _relocate_to_hospital(game, targets)
  local hospital_index = assert(game.board:find_first_by_type("hospital"), "missing hospital")
  for _, target in ipairs(targets) do
    game:player_relocate(target, {
      destination_index = hospital_index,
      move_dir_mode = "clear",
    })
  end
  return hospital_index
end

local function _apply_hospital_effects(game, targets)
  for _, target in ipairs(targets) do
    game:player_apply_hospital_effects(target)
  end
end

local function _patch_queued_anim_targets(game, kind, player_id, tile_index, to_index)
  if not (game and game.turn) then
    return
  end
  local function _patch(anim)
    if anim and anim.kind == kind and anim.tile_index == tile_index and anim.player_id == player_id then
      anim.to_index = to_index
    end
  end
  _patch(game.turn.action_anim)
  for _, anim in ipairs(game.turn.action_anim_queue or {}) do
    _patch(anim)
  end
end

local function _build_hospital_followup(targets, log_entries)
  local effects = {}
  for index, target in ipairs(targets) do
    effects[index] = {
      player_id = target.id,
      effect = "hospital",
    }
  end
  return {
    next_state = "move_followup",
    next_args = {
      mode = "apply_location_effects",
      log_entries = log_entries,
      effects = effects,
    },
  }
end

function demolish_hospital.handle_result(game, player, idx, kind, hospital_targets, queued, msg, log_entries)
  local hospital_index = _relocate_to_hospital(game, hospital_targets)
  _patch_queued_anim_targets(game, kind, player.id, idx, hospital_index)
  if queued then
    return {
      ok = true,
      action_anim = queued,
      after_action_anim = _build_hospital_followup(hospital_targets, log_entries),
    }
  end
  event_feed.publish(game, { kind = event_kinds.demolish, text = msg })
  _apply_hospital_effects(game, hospital_targets)
  return { ok = true, action_anim = queued }
end

return demolish_hospital

--[[ mutate4lua-manifest
version=4
projectHash=1ff01aa8f367088f
scope.0.id=chunk:src/rules/items/demolish_hospital.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=31003600c1955724
scope.1.id=function:demolish_hospital.collect_targets
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=22
scope.1.semanticHash=60fedd891c04a3ec
scope.2.id=function:demolish_hospital.target_player_ids
scope.2.kind=function
scope.2.startLine=24
scope.2.endLine=30
scope.2.semanticHash=9267cde488f11dc7
scope.3.id=function:_relocate_to_hospital
scope.3.kind=function
scope.3.startLine=32
scope.3.endLine=41
scope.3.semanticHash=9cd038dd84649d66
scope.4.id=function:_apply_hospital_effects
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=47
scope.4.semanticHash=3573626b33370ea2
scope.5.id=function:_patch_queued_anim_targets
scope.5.kind=function
scope.5.startLine=49
scope.5.endLine=62
scope.5.semanticHash=e8e7910082205f76
scope.6.id=function:_patch
scope.6.kind=function
scope.6.startLine=53
scope.6.endLine=57
scope.6.semanticHash=e1b85b78152b2665
scope.7.id=function:_build_hospital_followup
scope.7.kind=function
scope.7.startLine=64
scope.7.endLine=80
scope.7.semanticHash=2f646d17963f1fc4
scope.8.id=function:demolish_hospital.handle_result
scope.8.kind=function
scope.8.startLine=82
scope.8.endLine=95
scope.8.semanticHash=08c5a5d1b5e91dd9
]]
