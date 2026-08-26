local tile_mod = require("src.rules.board.tile")
local board_query = require("src.rules.board.query")
local property_value = require("src.rules.commerce.property_value")
local target_query = require("src.rules.items.target_query")

local demolish_choice = {}

local tile_state = tile_mod.get_state

-- 打分口径:他人名下且有建筑(level > 0)的地产才是拆除目标。
local function _is_demolish_target(st, player_id)
  return st.owner_id and st.owner_id ~= player_id and (st.level or 0) > 0
end

function demolish_choice.find_target(game, player, distance)
  local idx, value = target_query.find_best_tile(game, player, distance, {
    score_fn = function(tile)
      if tile.type ~= "land" then
        return -1
      end
      local st = tile_state(game, tile)
      if not _is_demolish_target(st, player.id) then
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

local function _not_own_land(st, player)
  return st.owner_id and st.owner_id ~= player.id and st.level > 0
end

local function _is_demolishable_tile(game, player, idx)
  if not idx or idx == player.position then return nil end
  local tile = game.board:get_tile(idx)
  if tile.type ~= "land" then return nil end
  local st = tile_state(game, tile)
  if not _not_own_land(st, player) then
    return nil
  end
  return tile
end

function demolish_choice.build_human_choice(game, player, distance, best_idx, opts)
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

return demolish_choice

--[[ mutate4lua-manifest
version=4
projectHash=b80a46c5026e04ef
scope.0.id=chunk:src/rules/items/demolish_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=99
scope.0.semanticHash=1f9b1b75ac351df1
scope.1.id=function:_is_demolish_target
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=13
scope.1.semanticHash=6140025952c8b847
scope.2.id=function:demolish_choice.find_target
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=32
scope.2.semanticHash=42a5a328b0a6fb0a
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=17
scope.3.endLine=26
scope.3.semanticHash=2aa7ef480e53882d
scope.4.id=function:_not_own_land
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=07602c2edb3e10af
scope.5.id=function:_is_demolishable_tile
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=47
scope.5.semanticHash=9e2f7a168e7d83da
scope.6.id=function:demolish_choice.build_human_choice
scope.6.kind=function
scope.6.startLine=49
scope.6.endLine=96
scope.6.semanticHash=8c4c4f9fdc71c64a
scope.7.id=function:_push_option
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=59
scope.7.semanticHash=bc6bada9d38c8af6
]]
