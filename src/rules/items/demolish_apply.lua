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
  -- 无入口守卫:唯一调用方先断言 tile 非 nil 且只在 type == "land" 时进入,
  -- 守卫恒真不可达(#259 删除)。st.level 在 tile 构造即初始化为 0,
  -- `(st.level or 0)` 的兜底同样是死防御。
  local st = tile_state(game, tile)
  if not st.owner_id or st.level <= 0 then
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

local function _build_missile_msg(player, tile, destroyed, hit)
  local msg = player.name .. " 发射导弹轰炸 " .. tile.name
  if destroyed and tile.type == "land" then
    msg = msg .. "，建筑被摧毁"
  end
  if hit > 0 then
    msg = msg .. "，" .. number_utils.format_integer_part(hit) .. " 名玩家送医"
  end
  return msg, "missile"
end

local function _build_demolish_msg(player, tile, injure, destroyed, hit)
  if injure then
    return _build_missile_msg(player, tile, destroyed, hit)
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
  -- hit 不在声明处初始化:未致伤时保持 nil,所有读取点(fully_blocked 第二臂、
  -- 消息伤亡后缀、handle_result 分支)都被 opts.injure 短路守卫;`local hit = 0`
  -- 的 0→1 变异在旧形态下不可观测(#259 化简,同时封死 fully_blocked
  -- 第二臂 not 删除变异——nil == 0 为假,行为分歧可观测)。
  local hit
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

local function _is_fully_blocked(destroyed, injure, hit)
  return (not destroyed) and (not injure or hit == 0)
end

function demolish_apply.apply(game, player, idx, opts)
  opts = opts or {}
  local tile, destroyed, destroyed_owner, hospital_targets, hit = _apply_demolish_effects(game, idx, opts)
  local fully_blocked = _is_fully_blocked(destroyed, opts.injure, hit)
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
version=4
projectHash=db88c209c6cd7fd2
scope.0.id=chunk:src/rules/items/demolish_apply.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=1838bd5713110d43
scope.1.id=function:_try_destroy_building
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=32
scope.1.semanticHash=18bde1339c7ed64d
scope.2.id=function:_build_missile_msg
scope.2.kind=function
scope.2.startLine=34
scope.2.endLine=43
scope.2.semanticHash=a3fbb3da6e294ee7
scope.3.id=function:_build_demolish_msg
scope.3.kind=function
scope.3.startLine=45
scope.3.endLine=53
scope.3.semanticHash=7ae25e40cf794396
scope.4.id=function:_apply_demolish_effects
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=74
scope.4.semanticHash=8102cef15514a533
scope.5.id=function:_queue_demolish_anim
scope.5.kind=function
scope.5.startLine=76
scope.5.endLine=85
scope.5.semanticHash=21fe43905c40d457
scope.6.id=function:_record_monster_demolish
scope.6.kind=function
scope.6.startLine=87
scope.6.endLine=91
scope.6.semanticHash=ce4a91327e071943
scope.7.id=function:_finish_demolish_without_injury
scope.7.kind=function
scope.7.startLine=93
scope.7.endLine=98
scope.7.semanticHash=b21810c347aa72e5
scope.8.id=function:_is_fully_blocked
scope.8.kind=function
scope.8.startLine=100
scope.8.endLine=102
scope.8.semanticHash=b572bb97eab29b7e
scope.9.id=function:demolish_apply.apply
scope.9.kind=function
scope.9.startLine=104
scope.9.endLine=116
scope.9.semanticHash=34f88298ca3d04ce
]]
