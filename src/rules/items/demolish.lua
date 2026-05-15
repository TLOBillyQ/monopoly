local logger = require("src.foundation.log")
local event_kinds = require("src.config.gameplay.event_kinds")
local tile_mod = require("src.rules.board.tile")
local board_query = require("src.rules.board.query")
local property_value = require("src.rules.commerce.property_value")
local timing = require("src.config.gameplay.timing")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local number_utils = require("src.foundation.number")
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
    return true
  end
  local owner = game:find_player_by_id(st.owner_id)
  if owner and game:angel_immune_to_item(owner, item_id) then
    angel_feedback.publish(game, owner, "建筑摧毁", { tile_index = idx })
    return false
  end
  game:set_tile_level(tile, 0)
  return true
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

function demolish.apply(game, player, idx, opts)
  opts = opts or {}
  game:clear_all_overlays(idx)
  local tile = assert(game.board:get_tile(idx), "missing tile: " .. tostring(idx))

  local destroyed = false
  if tile.type == "land" then
    destroyed = _try_destroy_building(game, tile, idx, opts.item_id)
  end

  local hit = 0
  local hospital_targets = nil
  if opts.injure then
    hospital_targets = _collect_hospital_targets(game, idx, opts.item_id)
    hit = #hospital_targets
  end

  local fully_blocked = (not destroyed) and (not opts.injure or hit == 0)
  local msg, kind = _build_demolish_msg(player, tile, opts.injure, destroyed, hit)
  local log_entries = { msg }
  local queued = action_anim_port.queue(game, {
    kind = kind,
    player_id = player.id,
    tile_index = idx,
    item_id = opts.item_id,
    duration = action_anim_duration,
    target_player_ids = opts.injure and _build_target_player_ids(hospital_targets) or nil,
  })
  if opts.injure and hit > 0 then
    local hospital_index = _relocate_to_hospital(game, hospital_targets)
    _patch_queued_anim_targets(game, kind, player.id, idx, hospital_index)
    if queued then
      return {
        ok = true,
        action_anim = queued,
        after_action_anim = _build_hospital_followup(hospital_targets, log_entries),
      }
    end
    event_feed.publish(game, {
      kind = event_kinds.demolish,
      text = msg,
    })
    _apply_hospital_effects(game, hospital_targets)
    return { ok = true, action_anim = queued }
  end
  -- 天使全挡：保留 anim 让特效照播，但跳过 demolish 文案，不与免疫 tip 抢镜
  if not fully_blocked then
    event_feed.publish(game, {
      kind = event_kinds.demolish,
      text = msg,
    })
  end
  return { ok = true, action_anim = queued }
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
    local idxs = board_query.indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}

    local function _push_option(idx)
      if idx and idx ~= player.position then
        local tile = game.board:get_tile(idx)
        if tile.type == "land" then
          local st = tile_state(game, tile)
          if st.owner_id and st.owner_id ~= player.id and st.level > 0 then
            table.insert(body_lines, "#" .. tostring(idx) .. " " .. tile.name)
            table.insert(options, { id = idx, label = tile.name })
          end
        end
      end
    end

    for _, idx in ipairs(idxs) do
       _push_option(idx)
    end

    if #options == 0 then
       _push_option(best_idx)
    end

    if #options > 0 then
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
  end

  if consume_fn and not consume_fn(player, opts.item_id) then
    return false
  end
  return demolish.apply(game, player, best_idx, opts)
end

return demolish
