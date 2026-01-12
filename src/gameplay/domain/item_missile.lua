local logger = require("src.util.logger")
local UI = require("src.gameplay.ports.ui_port")
local Services = require("src.util.services")
local GameState = require("src.util.game_state")
local BoardUtils = require("src.gameplay.domain.item_board_utils")
local WorldOps = require("src.gameplay.domain.item_world_ops")

local Missile = {}

local tile_state = GameState.tile_state

local function send_players_to_hospital(game, idx)
  local occupants = game.occupants[idx]
  if not occupants then
    return 0
  end
  local status = Services.status(game)
  if not status then
    logger.warn("缺少 StatusService，无法送医")
    return 0
  end
  local count = 0
  local unpack_fn = table.unpack or unpack
  local snapshot = { unpack_fn(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = game.players[pid]
    if target then
      game:set_player_seat(target, nil)
      status.send_to_hospital(game, target, { skip_fee = true })
      count = count + 1
    end
  end
  return count
end

function Missile.find_target(game, player, distance)
  local idx = BoardUtils.find_best_tile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return 0
      end
      local st = tile_state(game, tile)
      return BoardUtils.total_invested(tile, st.owner_id, st.level)
    end,
  })
  return idx
end

function Missile.apply(game, player, idx)
  WorldOps.clear_overlays(game, idx)
  local tile = game.board:get_tile(idx)
  WorldOps.destroy_building(game, tile)
  local hit = send_players_to_hospital(game, idx)
  local msg = player.name .. " 发射导弹轰炸 " .. tile.name
  if tile.type == "land" then
    msg = msg .. "，建筑被摧毁"
  end
  if hit > 0 then
    msg = msg .. "，" .. hit .. " 名玩家送医"
  end
  logger.event(msg)
  UI.push_popup(game, { title = "导弹卡", body = msg })
end


function Missile.use(game, player, distance, consume_fn)
  local best_idx = Missile.find_target(game, player, distance)
  if not best_idx then
    logger.warn(player.name .. " 前后无可轰炸目标，导弹卡未生效")
    return false
  end

  if UI.is_available(game) then
    local idxs = BoardUtils.indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}
    for _, idx in ipairs(idxs) do
      if idx ~= player.position then
        local tile = game.board:get_tile(idx)
        table.insert(body_lines, "#" .. idx .. " " .. tile.name)
        table.insert(options, { id = idx, label = tile.name })
      end
    end
    if #options > 0 then
      return {
        waiting = true,
        intent = {
          kind = "need_choice",
          choice_spec = {
            kind = "missile_target",
            title = "导弹卡：选择目标格子",
            body_lines = body_lines,
            options = options,
            allow_cancel = true,
            cancel_label = "取消",
            meta = { player_id = player.id },
          },
        },
      }
    end
  end

  if not consume_fn(player, 2013) then
    return false
  end
  Missile.apply(game, player, best_idx)
  return true
end

return Missile
