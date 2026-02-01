local logger = require("Components.Logger")
local Tile = require("Components.Tile")
local BoardUtils = require("Manager.ItemManager.Item.ItemBoardUtils")
local constants = require("Config.Generated.Constants")

local Demolish = {}

local list_unpack = table.unpack or unpack

local function clear_overlays(game, idx)
  if game and game.board and game.board.clear_all then
    game.board:clear_all(idx)
  end
end

local function destroy_building(game, tile)
  if not tile or tile.type ~= "land" then return end
  game:set_tile_level(tile, 0)
end

local tile_state = Tile.get_state

local function send_players_to_hospital(game, idx)
  local occupants = game.occupants[idx]
  if not occupants then
    return 0
  end

  local hospital_index = game.board:find_first_by_type("hospital")

  local count = 0
  local snapshot = { list_unpack(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = game.players[pid]
    if target then
      if target:is_vehicle_indestructible() then
        logger.event(target.name .. " 座驾免疫导弹效果")
      else
        game:set_player_seat(target, nil)
        if hospital_index then
          game:update_player_position(target, hospital_index)
        end
        game:set_player_status(target, "move_dir", nil)
        game:set_player_status(target, "stay_turns", constants.hospital_stay_turns)
        logger.event(target.name .. " 被炸伤送往医院，需停留 " .. constants.hospital_stay_turns .. " 回合")
        count = count + 1
      end
    end
  end
  return count
end

function Demolish.find_target(game, player, distance)
  local idx = BoardUtils.find_best_tile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return nil
      end
      local st = tile_state(game, tile)
      if not st.owner_id or st.owner_id == player.id or (st.level or 0) <= 0 then
        return nil
      end
      return BoardUtils.total_invested(tile, st.level)
    end,
  })
  return idx
end

function Demolish.apply(game, player, idx, opts)
  opts = opts or {}
  clear_overlays(game, idx)
  local tile = game.board:get_tile(idx)

  destroy_building(game, tile)

  local hit = 0
  if opts.injure then
    hit = send_players_to_hospital(game, idx)
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
  local queued = false
  if game.ui_port and game.ui_port.wait_action_anim then
    game:queue_action_anim({
      kind = kind,
      player_id = player.id,
      tile_index = idx,
      item_id = opts.item_id,
    })
    queued = true
  end
  return { ok = true, action_anim = queued }
end

function Demolish.use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = Demolish.find_target(game, player, distance)
  if not best_idx then
    logger.warn(player.name .. " 前后无可破坏目标，道具未生效")
    return false
  end

  if not opts.by_ai then
    local idxs = BoardUtils.indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}

    local function push_option(idx)
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
       push_option(idx)
    end

    if #options == 0 then
       push_option(best_idx)
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
  return Demolish.apply(game, player, best_idx, opts)
end

return Demolish


