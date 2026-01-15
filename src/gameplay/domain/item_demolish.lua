local logger = require("src.util.logger")
local Tile = require("src.core.tile")
local BoardUtils = require("src.gameplay.domain.item_board_utils")
local constants = require("src.config.constants")

local Demolish = {}

local function clear_overlays(game, idx)
  if game and game.board and game.board.clear_all then
    game.board:clear_all(idx)
  end
end

local function destroy_building(game, tile)
  if not tile or tile.type ~= "land" then return end
  if game and game.set_tile_level then
    game:set_tile_level(tile, 0)
  elseif game and game.store and tile and tile.id then
    game.store:set({ "board", "tiles", tile.id, "level" }, 0)
  end
end

local tile_state = Tile.get_state

local function send_players_to_hospital(game, idx)
  local occupants = game.occupants[idx]
  if not occupants then
    return 0
  end

  local hospital_index = game.board:find_first_by_type("hospital")
  
  local count = 0
  local unpack_fn = table.unpack or unpack
  local snapshot = { unpack_fn(occupants) }
  for _, pid in ipairs(snapshot) do
    local target = game.players[pid]
    if target then
      game:set_player_seat(target, nil)
      if hospital_index then
        game:update_player_position(target, hospital_index)
      end
      if game.set_player_status then
        game:set_player_status(target, "move_dir", nil)
      end
      game:set_player_status(target, "stay_turns", constants.hospital_stay_turns)
      logger.event(target.name .. " 被炸伤送往医院，需停留 " .. constants.hospital_stay_turns .. " 回合")
      count = count + 1
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
      -- Target occupied, developed lands not owned by self
      if not st.owner_id or st.owner_id == player.id or (st.level or 0) <= 0 then
        return nil
      end
      return BoardUtils.total_invested(tile, st.owner_id, st.level)
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
  
  local title = opts.title or "破坏"
  return {
    ok = true,
    intent = { kind = "push_popup", payload = { title = title, body = msg } },
  }
end

function Demolish.use(game, player, distance, consume_fn, opts)
  opts = opts or {}
  local best_idx = Demolish.find_target(game, player, distance)
  if not best_idx then
    logger.warn(player.name .. " 前后无可破坏目标，道具未生效")
    return false
  end

  if not opts.by_ai then
    -- Interactive Mode: Let user choose if multiple targets or just confirm
    local idxs = BoardUtils.indices_in_range(game.board, player.position, distance)
    local options = {}
    local body_lines = {}

    local function push_option(idx)
      if idx and idx ~= player.position then
        local tile = game.board:get_tile(idx)
        -- Only allow targeting valid tiles (owned by others, level > 0)
        -- We reuse logic from determine_score or simpler check
        if tile.type == "land" then
          local st = tile_state(game, tile)
          if st.owner_id and st.owner_id ~= player.id and (st.level or 0) > 0 then
            table.insert(body_lines, "#" .. idx .. " " .. tile.name)
            table.insert(options, { id = idx, label = tile.name })
          end
        end
      end
    end

    -- We specifically want to show the 'best' one first or all of them.
    -- The original Missile code iterated indices.
    -- Let's just iterate all indices in range.
    for _, idx in ipairs(idxs) do
       push_option(idx)
    end
    
    -- If no valid targets found in range (shouldn't happen if best_idx found one)
    if #options == 0 then
       -- This acts as a fallback if find_best_tile sees one but our strict loop misses it (unlikely)
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
