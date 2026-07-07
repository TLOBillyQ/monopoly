local event_kinds = require("src.config.gameplay.event_kinds")
local tile_mod = require("src.rules.board.tile")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")
local achievement_progress = require("src.rules.ports.achievement_progress")
local angel_feedback = require("src.rules.items.angel_feedback")
local demolish_hospital = require("src.rules.items.demolish_hospital")

local demolish_apply = {}
local action_anim_duration = timing.action_anim_default_seconds or 1.0

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
    hospital_targets = demolish_hospital.collect_targets(game, idx, opts.item_id)
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
    target_player_ids = opts.injure and demolish_hospital.target_player_ids(hospital_targets) or nil,
  })
end

local function _record_monster_demolish(game, destroyed_owner, kind)
  if destroyed_owner and kind == "monster" then
    achievement_progress.monster_demolished_building(game, destroyed_owner)
  end
end

local function _finish_demolish_without_injury(game, fully_blocked, queued, msg)
  if not fully_blocked then
    event_feed.publish(game, { kind = event_kinds.demolish, text = msg })
  end
  return { ok = true, action_anim = queued }
end

function demolish_apply.apply(game, player, idx, opts)
  opts = opts or {}
  local tile, destroyed, destroyed_owner, hospital_targets, hit = _apply_demolish_effects(game, idx, opts)
  local fully_blocked = (not destroyed) and (not opts.injure or hit == 0)
  local msg, kind = _build_demolish_msg(player, tile, opts.injure, destroyed, hit)
  local log_entries = { msg }
  local queued = _queue_demolish_anim(game, player, idx, opts, kind, hospital_targets)
  _record_monster_demolish(game, destroyed_owner, kind)
  if opts.injure and hit > 0 then
    return demolish_hospital.handle_result(game, player, idx, kind, hospital_targets, queued, msg, log_entries)
  end
  return _finish_demolish_without_injury(game, fully_blocked, queued, msg)
end

return demolish_apply

--[[ mutate4lua-manifest
version=2
projectHash=cd7d1ab8e208ca7d
scope.0.id=chunk:src/rules/items/demolish_apply.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=105
scope.0.semanticHash=f006aecc6e84a1d0
scope.0.lastMutatedAt=2026-07-07T04:15:13Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=10
scope.0.lastMutationKilled=10
scope.1.id=function:_try_destroy_building:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=30
scope.1.semanticHash=c43288bbcbe5f90a
scope.1.lastMutatedAt=2026-07-07T04:15:13Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=survived
scope.1.lastMutationSites=17
scope.1.lastMutationKilled=16
scope.2.id=function:_build_demolish_msg:32
scope.2.kind=function
scope.2.startLine=32
scope.2.endLine=47
scope.2.semanticHash=c6b02ed1d605950e
scope.2.lastMutatedAt=2026-07-07T04:15:13Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=17
scope.2.lastMutationKilled=17
scope.3.id=function:_apply_demolish_effects:49
scope.3.kind=function
scope.3.startLine=49
scope.3.endLine=64
scope.3.semanticHash=0e2992ab05d12530
scope.3.lastMutatedAt=2026-07-07T04:15:13Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=survived
scope.3.lastMutationSites=8
scope.3.lastMutationKilled=7
scope.4.id=function:_queue_demolish_anim:66
scope.4.kind=function
scope.4.startLine=66
scope.4.endLine=75
scope.4.semanticHash=aa8e5673af470b24
scope.4.lastMutatedAt=2026-07-07T04:15:13Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:_record_monster_demolish:77
scope.5.kind=function
scope.5.startLine=77
scope.5.endLine=81
scope.5.semanticHash=d46b5bd8cb8e09a1
scope.5.lastMutatedAt=2026-07-07T04:15:13Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=4
scope.5.lastMutationKilled=4
scope.6.id=function:_finish_demolish_without_injury:83
scope.6.kind=function
scope.6.startLine=83
scope.6.endLine=88
scope.6.semanticHash=3de6fc04f9d9ddd1
scope.6.lastMutatedAt=2026-07-07T04:15:13Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=3
scope.6.lastMutationKilled=3
scope.7.id=function:demolish_apply.apply:90
scope.7.kind=function
scope.7.startLine=90
scope.7.endLine=102
scope.7.semanticHash=05184682cebed014
scope.7.lastMutatedAt=2026-07-07T04:15:13Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=survived
scope.7.lastMutationSites=16
scope.7.lastMutationKilled=15
]]
