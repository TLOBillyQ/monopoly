local tile_mod = require("src.rules.board.tile")
local board_query = require("src.rules.board.query")
local property_value = require("src.rules.commerce.property_value")
local target_query = require("src.rules.items.target_query")

local demolish_choice = {}

local tile_state = tile_mod.get_state

function demolish_choice.find_target(game, player, distance)
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
version=2
projectHash=6017899d87366b14
scope.0.id=chunk:src/rules/items/demolish_choice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=90
scope.0.semanticHash=518b1759df59c6e0
scope.0.lastMutatedAt=2026-07-07T04:15:26Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=22
scope.0.lastMutationKilled=22
scope.1.id=function:anonymous@12:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=21
scope.1.semanticHash=ae21837dfbe18ed0
scope.1.lastMutatedAt=2026-07-07T03:35:27Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=no_sites
scope.1.lastMutationSites=0
scope.1.lastMutationKilled=0
scope.2.id=function:demolish_choice.find_target:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=27
scope.2.semanticHash=e490d74ab3e1b64a
scope.2.lastMutatedAt=2026-07-07T04:15:26Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:_is_demolishable_tile:29
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=38
scope.3.semanticHash=ad48a3f725565c80
scope.3.lastMutatedAt=2026-07-07T04:15:26Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=13
scope.3.lastMutationKilled=13
scope.4.id=function:_push_option:45
scope.4.kind=function
scope.4.startLine=45
scope.4.endLine=50
scope.4.semanticHash=f4c3dd34eb25242f
scope.4.lastMutatedAt=2026-07-07T04:15:26Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=4
scope.4.lastMutationKilled=4
]]
