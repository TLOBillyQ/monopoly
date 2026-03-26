local auto_play_port = require("src.rules.ports.auto_play")
local effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local inventory = require("src.rules.items.inventory")
local demolish = require("src.rules.items.demolish")
local roadblock = require("src.rules.items.roadblock")
local property_query = require("src.rules.board.property_query")
local property_value = require("src.rules.commerce.property_value")
local number_utils = require("src.core.utils.number_utils")

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

local function copy_table(source)
  local out = {}
  if type(source) ~= "table" then
    return out
  end
  for key, value in pairs(source) do
    out[key] = value
  end
  return out
end

local function contains(list, value)
  if type(list) ~= "table" then
    return false
  end
  for _, current in ipairs(list) do
    if current == value then
      return true
    end
  end
  return false
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

availability.copy_table = copy_table
availability.contains = contains
availability.normalize_integer_field = normalize_integer_field

local function _resolve_item_cfg(item_id)
  return inventory.cfg(item_id)
end

function availability.resolve_offer_in_phases(item_id, cfg)
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
  return contains(offer_in_phases, phase)
end

local function _resolve_phase_timing(phase)
  if not phase then
    return nil
  end
  return phase_timing[phase]
end

function availability.trigger_timing_allowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = _resolve_phase_timing(phase)
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
  local owner, tile_state = property_query.resolve_rent_owner(game, tile_ref)
  return {
    tile_ref = tile_ref,
    owner = owner,
    tile_state = tile_state,
  }
end

local function _rent_response_available(ctx, player)
  local owner = ctx and ctx.owner or nil
  return owner ~= nil and owner.id ~= player.id
end

local function _can_afford_strong_rent_response(game, player, ctx)
  local tile_ref = assert(ctx and ctx.tile_ref, "missing rent response tile")
  local tile_state = ctx and ctx.tile_state or nil
  local total_value = property_value.total_invested(tile_ref, tile_state and tile_state.level or 0)
  return game:player_balance(player, "金币") >= total_value
end

local function _can_offer_rent_response(game, player, item_id)
  local ctx = _resolve_rent_response_context(game, player)
  if not _rent_response_available(ctx, player) then
    return false
  end
  if item_id ~= item_ids.strong then
    return true
  end
  return _can_afford_strong_rent_response(game, player, ctx)
end

local function _can_offer_special_item(game, player, item_id)
  if item_id == item_ids.roadblock then
    local candidates = _resolve_roadblock_candidates(game, player)
    return type(candidates) == "table" and #candidates > 0
  end

  if item_id == item_ids.monster or item_id == item_ids.missile then
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
  local cfg = _resolve_item_cfg(item_id)
  if not cfg then
    return false, "missing_item_cfg"
  end
  if not _offer_window_allowed(item_id, cfg, phase, false) then
    return false, "offer_in_phases_not_allowed"
  end
  local special_offer = _can_offer_special_item(game, player, item_id)
  if special_offer ~= nil then
    if special_offer then
      return true, "ok"
    end
    return false, "special_condition_failed"
  end
  return true, "ok"
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
