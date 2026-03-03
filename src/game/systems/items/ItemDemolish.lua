local logger = require("src.core.Logger")
local tile = require("src.game.systems.board.Tile")
local board_utils = require("src.game.systems.land.LandBoardUtils")
local constants = require("Config.Generated.Constants")
local gameplay_rules = require("src.core.config.GameplayRules")
local action_anim_port = require("src.core.ActionAnimPort")

local demolish = {}
local action_anim_duration = gameplay_rules.action_anim_default_seconds or 1.0

local list_unpack = table.unpack or unpack

local function _clear_overlays(game, idx)
  assert(game ~= nil, "missing game")
  assert(game.board ~= nil and game.board.clear_all ~= nil, "missing board.ClearAll")
  game.board:clear_all(idx)
end

local function _destroy_building(game, tile)
  assert(tile ~= nil and tile.type == "land", "invalid tile for demolish")
  game:set_tile_level(tile, 0)
end

local tile_state = tile.get_state

local function _send_players_to_hospital(game, idx)
  local occupants = assert(game.occupants[idx], "missing occupants: " .. tostring(idx))

  local hospital_index = assert(game.board:find_first_by_type("hospital"), "missing hospital")

  local count = 0
  local snapshot = { list_unpack(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = assert(game:find_player_by_id(pid), "missing target player: " .. tostring(pid))
    if game:player_is_vehicle_indestructible(target) then
      logger.event(target.name .. " 座驾免疫导弹效果")
    else
      game:set_player_seat(target, nil)
      game:update_player_position(target, hospital_index)
      game:set_player_status(target, "move_dir", nil)
      game:set_player_status(target, "stay_turns", constants.hospital_stay_turns)
      logger.event(target.name .. " 被炸伤送往医院，需停留 " .. constants.hospital_stay_turns .. " 回合")
      count = count + 1
    end
  end
  return count
end

function demolish.find_target(game, player, distance)
  local idx, value = board_utils.find_best_tile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return -1
      end
      local st = tile_state(game, tile)
      if not st.owner_id or st.owner_id == player.id or (st.level or 0) <= 0 then
        return -1
      end
      return board_utils.total_invested(tile, st.level)
    end,
  })
  if value < 0 then
    return nil
  end
  return idx
end

function demolish.apply(game, player, idx, opts)
  opts = opts or {}
  _clear_overlays(game, idx)
  local tile = assert(game.board:get_tile(idx), "missing tile: " .. tostring(idx))

  _destroy_building(game, tile)

  local hit = 0
  if opts.injure then
    hit = _send_players_to_hospital(game, idx)
  end

  local msg
  if opts.injure then
    msg = player.name .. " 发射导弹轰炸 " .. tile.name
    if tile.type == "land" then
       msg = msg .. "，建筑被摧毁"
    end
    if hit > 0 then
      msg = msg .. "，" .. hit .. " 名玩家送医"
    end
  else
    msg = player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑"
  end

  logger.event(msg)

  local kind = "monster"
  if opts.injure then
    kind = "missile"
  end
  local queued = action_anim_port.queue(game, {
    kind = kind,
    player_id = player.id,
    tile_index = idx,
    item_id = opts.item_id,
    duration = action_anim_duration,
  })
  return { ok = true, action_anim = queued }
end

function demolish.use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = demolish.find_target(game, player, distance)
  if best_idx == nil then
    logger.warn((opts.title or "拆除类道具") .. " 无可用目标")
    return false
  end

  if not opts.by_ai then
    local idxs = board_utils.indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}

    local function _push_option(idx)
      if idx and idx ~= player.position then
        local tile = game.board:get_tile(idx)
        if tile.type == "land" then
          local st = tile_state(game, tile)
          if st.owner_id and st.owner_id ~= player.id and st.level > 0 then
            table.insert(body_lines, "#" .. idx .. " " .. tile.name)
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
      return {
        waiting = true,
        intent = {
          kind = "need_choice",
          choice_spec = {
            kind = "demolish_target",
            title = title .. "：选择目标格子",
            body_lines = body_lines,
            options = options,
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
