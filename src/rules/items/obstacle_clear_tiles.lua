local direction_constants = require("src.rules.board.directions")

local obstacle_clear_tiles = {}

function obstacle_clear_tiles.sorted_forward_dirs(neigh, back_dir)
  local dirs = {}
  for dir, _ in pairs(neigh) do
    if dir ~= back_dir then
      dirs[#dirs + 1] = dir
    end
  end
  table.sort(dirs)
  return dirs
end

function obstacle_clear_tiles.copy_path(src)
  -- 等价于 1..#src 的逐位复制(致密路径数组),化简后无循环下界字面量位点。
  return { table.unpack(src) }
end

local function _clear_obstacles_on_tile(game, state, tile_index, had_rb, had_mine)
  -- 无 cleared_map 去重守卫:唯一调用方 visit_tile 由 obstacle_snapshot
  -- 保证每格只进一次,守卫与字段均无读者(#259 删除)。
  if had_rb then
    game:clear_roadblock(tile_index)
    state.roadblock_cleared = state.roadblock_cleared + 1
  end
  if had_mine then
    game:clear_mine(tile_index)
    state.mine_cleared = state.mine_cleared + 1
  end
  if had_rb or had_mine then
    state.cleared = state.cleared + 1
  end
end

function obstacle_clear_tiles.visit_tile(game, board, state, tile_id, tile_index)
  if not state.obstacle_snapshot[tile_id] then
    local had_rb = board:has_roadblock(tile_index)
    local had_mine = board:has_mine(tile_index)
    state.obstacle_snapshot[tile_id] = (had_rb or had_mine) and "yes" or "no"
    _clear_obstacles_on_tile(game, state, tile_index, had_rb, had_mine)
  end
  return state.obstacle_snapshot[tile_id] == "yes"
end

function obstacle_clear_tiles.next_strict_or_turn(neigh, facing, opposite)
  if neigh[facing] then
    return { facing }
  end
  local back_dir = opposite[facing]
  return obstacle_clear_tiles.sorted_forward_dirs(neigh, back_dir)
end

function obstacle_clear_tiles.resolve_initial_dirs(start_neigh, facing)
  if facing == nil then
    return obstacle_clear_tiles.sorted_forward_dirs(start_neigh, nil)
  end
  if start_neigh[facing] then
    return { facing }
  end
  local back_dir = direction_constants.opposite[facing]
  return obstacle_clear_tiles.sorted_forward_dirs(start_neigh, back_dir)
end

return obstacle_clear_tiles

--[[ mutate4lua-manifest
version=4
projectHash=890b716376778094
scope.0.id=chunk:src/rules/items/obstacle_clear_tiles.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=67
scope.0.semanticHash=9d24e48cef67966e
scope.1.id=function:obstacle_clear_tiles.sorted_forward_dirs
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=14
scope.1.semanticHash=3310b41063076c3e
scope.2.id=function:obstacle_clear_tiles.copy_path
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=19
scope.2.semanticHash=b259fdd53a637c4a
scope.3.id=function:_clear_obstacles_on_tile
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=35
scope.3.semanticHash=1782d5664ad9324d
scope.4.id=function:obstacle_clear_tiles.visit_tile
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=45
scope.4.semanticHash=83b73f51f3b562cf
scope.5.id=function:obstacle_clear_tiles.next_strict_or_turn
scope.5.kind=function
scope.5.startLine=47
scope.5.endLine=53
scope.5.semanticHash=df1b6d9f733494a5
scope.6.id=function:obstacle_clear_tiles.resolve_initial_dirs
scope.6.kind=function
scope.6.startLine=55
scope.6.endLine=64
scope.6.semanticHash=fcc195f8712024ea
]]
