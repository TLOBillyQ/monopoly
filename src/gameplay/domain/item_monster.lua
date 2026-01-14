local logger = require("src.util.logger")
local Tile = require("src.core.tile")
local BoardUtils = require("src.gameplay.domain.item_board_utils")
local WorldOps = require("src.gameplay.domain.item_world_ops")

local Monster = {}

local tile_state = Tile.get_state

function Monster.find_target(game, player, distance)
  local idx = BoardUtils.find_best_tile(game, player, distance, {
    allow_self = true,
    score_fn = function(tile)
      if tile.type ~= "land" then
        return nil
      end
      local st = tile_state(game, tile)
      if (st.level or 0) <= 0 or not st.owner_id or st.owner_id == player.id then
        return nil
      end
      return BoardUtils.total_invested(tile, st.owner_id, st.level)
    end,
  })
  return idx
end

function Monster.use(game, player, distance)
  local idx = Monster.find_target(game, player, distance)
  if not idx then
    logger.warn(player.name .. " 前后无可拆除建筑，怪兽卡未生效")
    return false
  end
  local tile = game.board:get_tile(idx)
  WorldOps.destroy_building(game, tile)
  logger.event(player.name .. " 释放怪兽拆毁 " .. tile.name .. " 的建筑")
  return {
    ok = true,
    intent = {
      kind = "push_popup",
      payload = { title = "怪兽卡", body = player.name .. " 拆毁了 " .. tile.name .. " 的建筑" },
    },
  }
end

return Monster
