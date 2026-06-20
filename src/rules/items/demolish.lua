local logger = require("src.foundation.log")
local event_kinds = require("src.config.gameplay.event_kinds")
local tile_mod = require("src.rules.board.tile")
local board_query = require("src.rules.board.query")
local property_value = require("src.rules.commerce.property_value")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")
local achievement_progress = require("src.rules.ports.achievement_progress")
local target_query = require("src.rules.items.target_query")
local angel_feedback = require("src.rules.items.angel_feedback")

local demolish = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

local list_unpack = table.unpack

local tile_state = tile_mod.get_state

local function _try_destroy_building(game, tile, idx, item_id)
  assert(tile ~= nil and tile.type == "land", "invalid tile for demolish")
  local st = tile_state(game, tile)
  if not st.owner_id or (st.level or 0) <= 0 then
    game:set_tile_level(tile, 0)
    return true, nil
  end
  local owner = game:find_player_by_id(st.owner_id)
  if owner and game:angel_immune_to_item(owner, item_id) then
    angel_feedback.publish(game, owner, "建筑摧毁", { tile_index = idx })
    return false, nil
  end
  game:set_tile_level(tile, 0)
  return true, owner
end

local function _collect_hospital_targets(game, idx, item_id)
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

local function _build_target_player_ids(targets)
  local ids = {}
  for index, target in ipairs(targets or {}) do
    ids[index] = target.id
  end
  return ids
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

function demolish.find_target(game, player, distance)
  local idx, value = target_query.find_best_tile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return -1
      end
      local st = tile_state(game, tile)
      if not st.owner_id or st.owner_id == player.id or (st.level or 0) <= 0 then
        return -1
      end
      return property_value.total_invested(tile, st.level)
    end,
  })
  if value < 0 then
    return nil
  end
  return idx
end

local function _build_demolish_msg(player, tile, injure, destroyed, hit)
  if injure then
    local msg = player.name .. " 发射导弹轰炸 " .. tile.name
    if destroyed and tile.type == "land" then
       msg = msg .. "，建筑被摧毁"
    end
    if hit > 0 then
      msg = msg .. "，" .. number_utils.format_integer_part(hit) .. " 名玩家送医"
    end
    return msg, "missile"
  end
  if destroyed then
    return player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑", "monster"
  end
  return player.name .. " 释放怪兽，但 " .. tile.name .. " 建筑未被摧毁", "monster"
end

local function _apply_demolish_effects(game, idx, opts)
  game:clear_all_overlays(idx)
  local tile = assert(game.board:get_tile(idx), "missing tile: " .. tostring(idx))
  local destroyed = false
  local destroyed_owner = nil
  if tile.type == "land" then
    destroyed, destroyed_owner = _try_destroy_building(game, tile, idx, opts.item_id)
  end
  local hospital_targets = nil
  local hit = 0
  if opts.injure then
    hospital_targets = _collect_hospital_targets(game, idx, opts.item_id)
    hit = #hospital_targets
  end
  return tile, destroyed, destroyed_owner, hospital_targets, hit
end

local function _queue_demolish_anim(game, player, idx, opts, kind, hospital_targets)
  return action_anim_port.queue(game, {
    kind = kind,
    player_id = player.id,
    tile_index = idx,
    item_id = opts.item_id,
    duration = action_anim_duration,
    target_player_ids = opts.injure and _build_target_player_ids(hospital_targets) or nil,
  })
end

local function _handle_injure_result(game, player, idx, kind, hospital_targets, hit, queued, msg, log_entries)
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

function demolish.apply(game, player, idx, opts)
  opts = opts or {}
  local tile, destroyed, destroyed_owner, hospital_targets, hit = _apply_demolish_effects(game, idx, opts)
  local fully_blocked = (not destroyed) and (not opts.injure or hit == 0)
  local msg, kind = _build_demolish_msg(player, tile, opts.injure, destroyed, hit)
  local log_entries = { msg }
  local queued = _queue_demolish_anim(game, player, idx, opts, kind, hospital_targets)
  if destroyed_owner and kind == "monster" then
    achievement_progress.monster_demolished_building(game, destroyed_owner)
  end
  if opts.injure and hit > 0 then
    return _handle_injure_result(game, player, idx, kind, hospital_targets, hit, queued, msg, log_entries)
  end
  if not fully_blocked then
    event_feed.publish(game, { kind = event_kinds.demolish, text = msg })
  end
  return { ok = true, action_anim = queued }
end

local function _is_demolishable_tile(game, player, idx)
  if not idx or idx == player.position then return nil end
  local tile = game.board:get_tile(idx)
  if tile.type ~= "land" then return nil end
  local st = tile_state(game, tile)
  if not (st.owner_id and st.owner_id ~= player.id and st.level > 0) then
    return nil
  end
  return tile
end

local function _build_human_demolish_choice(game, player, distance, best_idx, opts)
  local idxs = board_query.indices_in_range(game.board, player.position, distance)
  local options = {}
  local body_lines = {}

  local function _push_option(idx)
    local tile = _is_demolishable_tile(game, player, idx)
    if not tile then return end
    table.insert(body_lines, "#" .. tostring(idx) .. " " .. tile.name)
    table.insert(options, { id = idx, label = tile.name })
  end

  for _, idx in ipairs(idxs) do
    _push_option(idx)
  end
  if #options == 0 then
    _push_option(best_idx)
  end
  if #options == 0 then
    return nil
  end

  local title = opts.title or "选择目标"
  local arranged, slot_layout = board_query.arrange_target_options(game.board, player, options)
  return {
    waiting = true,
    intent = {
      kind = "need_choice",
      choice_spec = {
        kind = "demolish_target",
        route_key = "target",
        owner_role_id = player.id,
        title = title .. "：选择目标格子",
        body_lines = body_lines,
        options = arranged,
        target_slot_layout = slot_layout,
        allow_cancel = true,
        cancel_label = "取消",
        meta = {
          player_id = player.id,
          item_id = opts.item_id,
          injure = opts.injure,
          title = opts.title
        },
      },
    },
  }
end

function demolish.use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = demolish.find_target(game, player, distance)
  if best_idx == nil then
    -- migrated as DEV: internal target-selection failure, not player-facing game fact
    logger.info((opts.title or "拆除类道具") .. " 无可用目标")
    return false
  end

  if not opts.by_ai then
    local choice = _build_human_demolish_choice(game, player, distance, best_idx, opts)
    if choice then
      return choice
    end
  end

  if consume_fn and not consume_fn(player, opts.item_id) then
    return false
  end
  return demolish.apply(game, player, best_idx, opts)
end

return demolish

--[[ mutate4lua-manifest
version=2
projectHash=c82cdc758fb11811
scope.0.id=chunk:src/rules/items/demolish.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=286
scope.0.semanticHash=13d6637d28f1130b
scope.0.lastMutatedAt=2026-06-01T12:34:35Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=survived
scope.0.lastMutationSites=53
scope.0.lastMutationKilled=52
scope.1.id=function:_try_destroy_building:20
scope.1.kind=function
scope.1.startLine=20
scope.1.endLine=34
scope.1.semanticHash=8df120f3a9e1cd85
scope.1.lastMutatedAt=2026-06-01T12:34:35Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=17
scope.1.lastMutationKilled=16
scope.2.id=function:_patch:80
scope.2.kind=function
scope.2.startLine=80
scope.2.endLine=84
scope.2.semanticHash=31f27cff06de3443
scope.2.lastMutatedAt=2026-06-01T12:34:35Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=6
scope.2.lastMutationKilled=6
scope.3.id=function:anonymous@111:111
scope.3.kind=function
scope.3.startLine=111
scope.3.endLine=120
scope.3.semanticHash=ae21837dfbe18ed0
scope.4.id=function:demolish.find_target:109
scope.4.kind=function
scope.4.startLine=109
scope.4.endLine=126
scope.4.semanticHash=f0fa86808f6f4058
scope.4.lastMutatedAt=2026-06-01T12:34:35Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=survived
scope.4.lastMutationSites=3
scope.4.lastMutationKilled=1
scope.5.id=function:_build_demolish_msg:128
scope.5.kind=function
scope.5.startLine=128
scope.5.endLine=143
scope.5.semanticHash=c6b02ed1d605950e
scope.5.lastMutatedAt=2026-06-01T12:34:35Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=17
scope.5.lastMutationKilled=17
scope.6.id=function:_apply_demolish_effects:145
scope.6.kind=function
scope.6.startLine=145
scope.6.endLine=159
scope.6.semanticHash=0593f5ba94d28982
scope.6.lastMutatedAt=2026-06-01T12:34:35Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=survived
scope.6.lastMutationSites=8
scope.6.lastMutationKilled=7
scope.7.id=function:_queue_demolish_anim:161
scope.7.kind=function
scope.7.startLine=161
scope.7.endLine=170
scope.7.semanticHash=d6a3b6fa35a1548e
scope.7.lastMutatedAt=2026-06-01T12:34:35Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:_handle_injure_result:172
scope.8.kind=function
scope.8.startLine=172
scope.8.endLine=185
scope.8.semanticHash=833ddf7d95d5034f
scope.8.lastMutatedAt=2026-06-01T12:34:35Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=7
scope.8.lastMutationKilled=7
scope.9.id=function:demolish.apply:187
scope.9.kind=function
scope.9.startLine=187
scope.9.endLine=201
scope.9.semanticHash=88e9666c8ee8c54a
scope.9.lastMutatedAt=2026-06-01T12:34:35Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=survived
scope.9.lastMutationSites=17
scope.9.lastMutationKilled=16
scope.10.id=function:_is_demolishable_tile:203
scope.10.kind=function
scope.10.startLine=203
scope.10.endLine=212
scope.10.semanticHash=ad48a3f725565c80
scope.10.lastMutatedAt=2026-06-01T12:34:35Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=survived
scope.10.lastMutationSites=13
scope.10.lastMutationKilled=12
scope.11.id=function:_push_option:219
scope.11.kind=function
scope.11.startLine=219
scope.11.endLine=224
scope.11.semanticHash=f4c3dd34eb25242f
scope.11.lastMutatedAt=2026-06-01T12:34:35Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=4
scope.11.lastMutationKilled=4
scope.12.id=function:demolish.use:263
scope.12.kind=function
scope.12.startLine=263
scope.12.endLine=283
scope.12.semanticHash=13d80163ce903b87
scope.12.lastMutatedAt=2026-06-01T12:34:35Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=12
scope.12.lastMutationKilled=12
]]
