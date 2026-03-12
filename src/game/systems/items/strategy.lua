local auto_play_port = require("src.game.ports.auto_play_port")
local effects = require("src.game.systems.items.post_effects")
local gameplay_rules = require("src.core.config.gameplay_rules")
local logger = require("src.core.utils.logger")
local inventory = require("src.game.systems.items.inventory")
local executor = require("src.game.systems.items.executor")
local demolish = require("src.game.systems.items.demolish")
local roadblock = require("src.game.systems.items.roadblock")
local property_query = require("src.game.systems.board.property_query")
local property_value = require("src.game.systems.commerce.property_value")
local facing_policy = require("src.game.systems.board.facing_policy")

local strategy = {}
local item_ids = gameplay_rules.item_ids
local target_item_set = {}
for _, target_item_id in ipairs(effects.target_item_ids()) do
  target_item_set[target_item_id] = true
end

function strategy.target_candidates(game, player, item_id)
  local registries = assert(game.registries, "missing game.registries")
  local registry = assert(registries.items, "missing item registry")
  return registry:target_candidates(game, player, item_id)
end

function strategy.has_obstacles_ahead(game, player, distance)
  local board = game.board
  distance = distance or 12
  local parity = distance
  local current = player.position
  local facing = facing_policy.resolve_initial_facing("fresh_forward", player)

  for _ = 1, distance do
    local next_index, _passed, step_dir = board:step_forward_by_facing(current, facing, parity)
    current = next_index
    facing = step_dir
    if board:has_roadblock(current) or board:has_mine(current) then
      return true
    end
  end
  return false
end

local phase_timing = {
  pre_action = { pre_action = true, turn = true },
  pre_move = { pre_move = true, turn = true },
  post_action = { post_action = true, manual = true, turn = true },
}

function strategy.timing_allowed(phase, timing, allow_missing_phase)
  if not phase then
    return allow_missing_phase
  end
  local allowed = phase_timing[phase]
  if not allowed or not timing then
    return false
  end
  return allowed[timing] == true
end

local function _is_manual_pre_action_mine(item_id, phase, timing)
  return item_id == item_ids.mine and phase == "pre_action" and timing == "manual"
end

local function _resolve_roadblock_candidates(game, player)
  if auto_play_port.is_auto_player(game, player) then
    return roadblock.auto_candidates(game, player, 3)
  end
  return roadblock.ui_candidates(game, player, 3)
end

local function _can_offer_target_item(game, player, item_id)
  local candidates = strategy.target_candidates(game, player, item_id)
  return type(candidates) == "table" and #candidates > 0
end

local function _can_offer_rent_response(game, player, item_id)
  local tile_ref = game.board and game.board:get_tile(player.position) or nil
  if not (tile_ref and tile_ref.type == "land") then
    return false
  end
  local owner, st = property_query.resolve_rent_owner(game, tile_ref)
  if not owner or owner.id == player.id then
    return false
  end
  if item_id ~= item_ids.strong then
    return true
  end
  local total_value = property_value.total_invested(tile_ref, st and st.level or 0)
  return game:player_balance(player, "金币") >= total_value
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

function strategy.can_offer_in_phase(game, player, item_id, phase, auto_play)
  local cfg = inventory.cfg(item_id)
  if not cfg then
    return false
  end
  if _is_manual_pre_action_mine(item_id, phase, cfg.timing) then
    return true
  end
  if not strategy.timing_allowed(phase, cfg.timing, false) then
    return false
  end
  local special_offer = _can_offer_special_item(game, player, item_id)
  if special_offer ~= nil then
    return special_offer
  end
  return true
end

local function _ai_can_use_item(item_id, phase)
  local cfg = inventory.cfg(item_id)
  local timing = cfg.timing
  if item_id == item_ids.mine and phase == "pre_action" and timing == "manual" then
    return true
  end
  return strategy.timing_allowed(phase, timing, true)
end

local function _try_use_item(game, player, item_id, cond, auto_play)
  if cond and cond() == false then return nil end
  local phase = game and game.turn and game.turn.phase or nil
  if _ai_can_use_item(item_id, phase) then
  else
    return nil
  end
  if inventory.find_index(player, item_id) then
  else
    return nil
  end
  local res = executor.use_item(game, player, item_id, { by_ai = true, auto_play = auto_play })
  if type(res) == "table" and (res.waiting or res.intent or res.kind or res.action_anim) then
    return res
  end
  return nil
end

local function _has_target_player(game, player, item_id)
  return auto_play_port.pick_target_player(game, player, item_id, strategy.target_candidates(game, player, item_id)) and true or false
end

local function _has_demolish_target(game, player)
  return demolish.find_target(game, player, 3) and true or false
end

local function _try_clear_obstacles(game, player, auto_play)
  return _try_use_item(game, player, item_ids.clear_obstacles, function()
    local found = strategy.has_obstacles_ahead(game, player, 12)
    if found then logger.info(player.name .. " 前方发现障碍，准备使用清障卡") end
    return found
  end, auto_play)
end

local function _try_remote_dice(game, player, auto_play)
  return _try_use_item(game, player, item_ids.remote_dice, function()
    local dice_count = game:player_dice_count(player)
    return auto_play_port.pick_remote_dice_value(game, player, dice_count) and true or false
  end, auto_play)
end

local function _try_roadblock(game, player, auto_play)
  return _try_use_item(game, player, item_ids.roadblock, function()
    return auto_play_port.pick_roadblock_target(game, player) and true or false
  end, auto_play)
end

local function _try_target_items(game, player, auto_play)
  for _, id in ipairs(effects.target_item_ids()) do
    local res = _try_use_item(game, player, id, function() return _has_target_player(game, player, id) end, auto_play)
    if res then return res end
  end
  return nil
end

local function _try_deity_items(game, player, auto_play)
  local rich_result = _try_use_item(game, player, item_ids.rich, nil, auto_play)
  if rich_result then return rich_result end
  return _try_use_item(game, player, item_ids.angel, nil, auto_play)
end

local function _auto_pre_action_probes(game, player, auto_play)
  return {
    function()
      return _try_clear_obstacles(game, player, auto_play)
    end,
    function()
      return _try_remote_dice(game, player, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.mine, nil, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.dice_multiplier, nil, auto_play)
    end,
    function()
      return _try_roadblock(game, player, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.monster, function()
        return _has_demolish_target(game, player)
      end, auto_play)
    end,
    function()
      return _try_use_item(game, player, item_ids.missile, function()
        return _has_demolish_target(game, player)
      end, auto_play)
    end,
    function()
      return _try_target_items(game, player, auto_play)
    end,
    function()
      return _try_deity_items(game, player, auto_play)
    end,
  }
end

local function _run_auto_pre_action_probes(game, player, auto_play)
  for _, probe in ipairs(_auto_pre_action_probes(game, player, auto_play)) do
    local result = probe()
    if result then
      return result
    end
  end
  return nil
end

function strategy.auto_pre_action(game, player, _phase)
  if not auto_play_port.is_auto_player(game, player) then
    return nil
  end
  return _run_auto_pre_action_probes(game, player, nil)
end

-- Export helpers for testability
strategy._ai_can_use_item = _ai_can_use_item
strategy._try_use_item = _try_use_item
strategy._has_target_player = _has_target_player
strategy._has_demolish_target = _has_demolish_target
strategy._try_clear_obstacles = _try_clear_obstacles
strategy._try_remote_dice = _try_remote_dice
strategy._try_roadblock = _try_roadblock
strategy._try_target_items = _try_target_items
strategy._try_deity_items = _try_deity_items

return strategy
