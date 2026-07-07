local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local demolish = require("src.rules.items.demolish")
local roadblock = require("src.rules.items.roadblock")
local property_query = require("src.rules.board.property_query")
local property_value = require("src.rules.commerce.property_value")
local number_utils = require("src.foundation.number")
local tables = require("src.foundation.tables")

local availability = {}
local phase_timing = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, turn = true },
}

local target_item_set = {}
for _, target_item_id in ipairs(effects.target_item_ids()) do
  target_item_set[target_item_id] = true
end

local followup_choice_item_set = {
  [item_ids.remote_dice] = true,
  [item_ids.roadblock] = true,
  [item_ids.monster] = true,
  [item_ids.missile] = true,
}

for _, target_item_id in ipairs(effects.target_item_ids()) do
  followup_choice_item_set[target_item_id] = true
end

local function normalize_integer_field(target, key, choice_kind, field_prefix, required)
  local value = target[key]
  if value == nil then
    if required then
      assert(false, tostring(choice_kind) .. " requires numeric " .. tostring(field_prefix or "meta") .. "." .. tostring(key))
    end
    return nil
  end
  target[key] = assert(
    number_utils.to_integer(value),
    tostring(choice_kind) .. " requires numeric " .. tostring(field_prefix or "meta") .. "." .. tostring(key)
  )
  return target[key]
end

availability.copy_table = tables.copy_table
availability.contains = tables.contains
availability.normalize_integer_field = normalize_integer_field

function availability.resolve_offer_in_phases(_item_id, cfg)
  if type(cfg) ~= "table" then
    return nil
  end
  if type(cfg.offer_in_phases) == "table" and #cfg.offer_in_phases > 0 then
    return cfg.offer_in_phases
  end
  return nil
end

local function _offer_phase_allowed(offer_in_phases, phase, allow_missing_phase)
  if type(offer_in_phases) ~= "table" or #offer_in_phases == 0 then
    return false
  end
  if not phase then
    return allow_missing_phase
  end
  return tables.contains(offer_in_phases, phase)
end

function availability.trigger_timing_allowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = phase_timing[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

local function _offer_window_allowed(item_id, cfg, phase, allow_missing_phase)
  local offer_in_phases = availability.resolve_offer_in_phases(item_id, cfg)
  return _offer_phase_allowed(offer_in_phases, phase, allow_missing_phase)
end

local function _resolve_roadblock_candidates(game, player)
  if auto_play_port.is_auto_player(game, player) then
    return roadblock.auto_candidates(game, player, 3)
  end
  return roadblock.manual_candidates(game, player, 3)
end

local function _can_offer_target_item(game, player, item_id)
  local registries = game and game.registries or nil
  local registry = registries and registries.items or nil
  if type(registry) ~= "table" or type(registry.target_candidates) ~= "function" then
    return false
  end
  local candidates = registry:target_candidates(game, player, item_id)
  return type(candidates) == "table" and #candidates > 0
end

local function _resolve_rent_response_tile(game, player)
  local board = game and game.board or nil
  local player_position = player and player.position or nil
  local tile_ref = board and board:get_tile(player_position) or nil
  if not (tile_ref and tile_ref.type == "land") then
    return nil
  end
  return tile_ref
end

local function _resolve_rent_response_context(game, player)
  local tile_ref = _resolve_rent_response_tile(game, player)
  if tile_ref == nil then
    return nil
  end
  local owner, state = property_query.resolve_rent_owner(game, tile_ref)
  return {
    tile_ref = tile_ref,
    player_id = player and player.id or nil,
    owner = owner,
    state = state,
    total_value = property_value.total_invested(tile_ref, state and state.level or 0),
  }
end

local function _is_rent_response_available(ctx)
  local owner = ctx and ctx.owner or nil
  return owner ~= nil and owner.id ~= ctx.player_id
end

local function _can_afford_strong_card(game, player, ctx)
  local total_value = assert(ctx and ctx.total_value, "missing rent response total value")
  return game:player_balance(player, "金币") >= total_value
end

local function _can_offer_rent_response(game, player, item_id)
  local ctx = _resolve_rent_response_context(game, player)
  if not _is_rent_response_available(ctx) then
    return false
  end
  if item_id ~= item_ids.strong then
    return true
  end
  return _can_afford_strong_card(game, player, ctx)
end

local function _can_offer_special_item(game, player, item_id)
  if item_id == item_ids.roadblock then
    local candidates = _resolve_roadblock_candidates(game, player)
    return type(candidates) == "table" and #candidates > 0
  end

  if item_id == item_ids.monster then
    return demolish.find_target(game, player, 3) ~= nil
  end

  if target_item_set[item_id] then
    return _can_offer_target_item(game, player, item_id)
  end

  if item_id == item_ids.strong or item_id == item_ids.free_rent then
    return _can_offer_rent_response(game, player, item_id)
  end

  return nil
end

function availability.can_offer_in_phase(game, player, item_id, phase)
  local cfg = inventory.cfg(item_id)
  if not cfg then
    return false, "missing_item_cfg"
  end
  if not _offer_window_allowed(item_id, cfg, phase, false) then
    return false, "offer_in_phases_not_allowed"
  end
  local special_offer = _can_offer_special_item(game, player, item_id)
  if special_offer ~= nil and not special_offer then
    return false, "special_condition_failed"
  end
  local used_effect_groups = game and game.turn and game.turn.used_effect_groups or nil
  if type(used_effect_groups) == "table" and cfg.effect_group ~= nil and used_effect_groups[cfg.effect_group] == true then
    return false, "effect_group_used"
  end
  return true, "ok"
end

function availability.mark_effect_group_used(game, item_id)
  local cfg = inventory.cfg(item_id)
  if type(cfg) ~= "table" or cfg.effect_group == nil then
    return
  end
  local used_effect_groups = game and game.turn and game.turn.used_effect_groups or nil
  if type(used_effect_groups) ~= "table" then
    return
  end
  used_effect_groups[cfg.effect_group] = true
end

function availability.can_auto_consider_item(item_id, phase, cfg)
  local item_cfg = cfg or inventory.cfg(item_id)
  if not item_cfg then
    return false
  end
  return _offer_window_allowed(item_id, item_cfg, phase, true)
end

function availability.requires_followup_choice(item_id)
  return followup_choice_item_set[item_id] == true
end

function availability.analyze_offer(game, player, item_id, phase)
  local can_offer, deny_reason = availability.can_offer_in_phase(game, player, item_id, phase)
  local requires_followup_choice = availability.requires_followup_choice(item_id)
  return {
    can_offer = can_offer == true,
    can_execute_now = can_offer == true and not requires_followup_choice,
    requires_followup_choice = requires_followup_choice,
    deny_reason = can_offer and nil or deny_reason,
  }
end

return availability

--[[ mutate4lua-manifest
version=2
projectHash=87d057f6a09fea55
scope.0.id=chunk:src/rules/items/availability.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=229
scope.0.semanticHash=8548b1d1820d29b4
scope.0.lastMutatedAt=2026-07-07T04:15:00Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=24
scope.0.lastMutationKilled=23
scope.1.id=function:normalize_integer_field:35
scope.1.kind=function
scope.1.startLine=35
scope.1.endLine=48
scope.1.semanticHash=480acd99b882334a
scope.1.lastMutatedAt=2026-07-07T04:15:00Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=3
scope.1.lastMutationKilled=3
scope.2.id=function:availability.resolve_offer_in_phases:54
scope.2.kind=function
scope.2.startLine=54
scope.2.endLine=62
scope.2.semanticHash=dde6e3f74eb50564
scope.2.lastMutatedAt=2026-07-07T04:15:00Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=9
scope.2.lastMutationKilled=9
scope.3.id=function:_offer_phase_allowed:64
scope.3.kind=function
scope.3.startLine=64
scope.3.endLine=72
scope.3.semanticHash=599efc0d86907b8f
scope.3.lastMutatedAt=2026-07-07T04:15:00Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=9
scope.3.lastMutationKilled=9
scope.4.id=function:availability.trigger_timing_allowed:74
scope.4.kind=function
scope.4.startLine=74
scope.4.endLine=83
scope.4.semanticHash=ffcd435300c2b942
scope.4.lastMutatedAt=2026-07-07T04:15:00Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=7
scope.4.lastMutationKilled=7
scope.5.id=function:_offer_window_allowed:85
scope.5.kind=function
scope.5.startLine=85
scope.5.endLine=88
scope.5.semanticHash=796634638532e68d
scope.5.lastMutatedAt=2026-07-07T04:15:00Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=2
scope.5.lastMutationKilled=2
scope.6.id=function:_resolve_roadblock_candidates:90
scope.6.kind=function
scope.6.startLine=90
scope.6.endLine=95
scope.6.semanticHash=ba3f0cfa1939f850
scope.6.lastMutatedAt=2026-07-07T04:15:00Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:_can_offer_target_item:97
scope.7.kind=function
scope.7.startLine=97
scope.7.endLine=105
scope.7.semanticHash=dc4ff414c0fbb39c
scope.7.lastMutatedAt=2026-07-07T04:15:00Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=19
scope.7.lastMutationKilled=19
scope.8.id=function:_resolve_rent_response_tile:107
scope.8.kind=function
scope.8.startLine=107
scope.8.endLine=115
scope.8.semanticHash=fd4b333daa84ecbe
scope.8.lastMutatedAt=2026-07-07T04:15:00Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=11
scope.8.lastMutationKilled=11
scope.9.id=function:_resolve_rent_response_context:117
scope.9.kind=function
scope.9.startLine=117
scope.9.endLine=130
scope.9.semanticHash=ac717d314c2f9884
scope.9.lastMutatedAt=2026-07-07T04:15:00Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=6
scope.9.lastMutationKilled=6
scope.10.id=function:_is_rent_response_available:132
scope.10.kind=function
scope.10.startLine=132
scope.10.endLine=135
scope.10.semanticHash=67a7094916530657
scope.10.lastMutatedAt=2026-07-07T04:15:00Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=5
scope.10.lastMutationKilled=5
scope.11.id=function:_can_afford_strong_card:137
scope.11.kind=function
scope.11.startLine=137
scope.11.endLine=140
scope.11.semanticHash=a4fa1cc99175112f
scope.11.lastMutatedAt=2026-07-07T04:15:00Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=3
scope.11.lastMutationKilled=3
scope.12.id=function:_can_offer_rent_response:142
scope.12.kind=function
scope.12.startLine=142
scope.12.endLine=151
scope.12.semanticHash=30d379ebe9b9dfdd
scope.12.lastMutatedAt=2026-07-07T04:15:00Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=7
scope.12.lastMutationKilled=7
scope.13.id=function:_can_offer_special_item:153
scope.13.kind=function
scope.13.startLine=153
scope.13.endLine=172
scope.13.semanticHash=08536c8f07645e0a
scope.13.lastMutatedAt=2026-07-07T04:15:00Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=16
scope.13.lastMutationKilled=16
scope.14.id=function:availability.can_offer_in_phase:174
scope.14.kind=function
scope.14.startLine=174
scope.14.endLine=191
scope.14.semanticHash=d7c716e72c827b90
scope.14.lastMutatedAt=2026-07-07T04:15:00Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=passed
scope.14.lastMutationSites=29
scope.14.lastMutationKilled=29
scope.15.id=function:availability.mark_effect_group_used:193
scope.15.kind=function
scope.15.startLine=193
scope.15.endLine=203
scope.15.semanticHash=9da94bc3e6aa6a93
scope.15.lastMutatedAt=2026-07-07T04:15:00Z
scope.15.lastMutationLane=behavior
scope.15.lastMutationStatus=passed
scope.15.lastMutationSites=13
scope.15.lastMutationKilled=13
scope.16.id=function:availability.can_auto_consider_item:205
scope.16.kind=function
scope.16.startLine=205
scope.16.endLine=211
scope.16.semanticHash=b0cf7ef7e3ed2994
scope.16.lastMutatedAt=2026-07-07T04:15:00Z
scope.16.lastMutationLane=behavior
scope.16.lastMutationStatus=passed
scope.16.lastMutationSites=5
scope.16.lastMutationKilled=5
scope.17.id=function:availability.requires_followup_choice:213
scope.17.kind=function
scope.17.startLine=213
scope.17.endLine=215
scope.17.semanticHash=4216da4100daf9f4
scope.17.lastMutatedAt=2026-07-07T04:15:00Z
scope.17.lastMutationLane=behavior
scope.17.lastMutationStatus=passed
scope.17.lastMutationSites=2
scope.17.lastMutationKilled=2
scope.18.id=function:availability.analyze_offer:217
scope.18.kind=function
scope.18.startLine=217
scope.18.endLine=226
scope.18.semanticHash=478e2450220310a6
scope.18.lastMutatedAt=2026-07-07T04:15:00Z
scope.18.lastMutationLane=behavior
scope.18.lastMutationStatus=passed
scope.18.lastMutationSites=10
scope.18.lastMutationKilled=10
]]
