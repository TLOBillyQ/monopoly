local tile_renderer = require("src.ui.render.tile_renderer")

local M = {}

local function _collect_tile_positions(tiles, tile_count)
  local positions = {}
  for i = 1, tile_count do
    local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
    assert(unit.get_position ~= nil, "missing tile get_position: " .. tostring(i))
    positions[i] = unit.get_position()
  end
  return positions
end

local function _collect_tile_ids(board)
  local tile_ids = {}
  for i, tile in ipairs(board.tiles) do
    assert(tile ~= nil and tile.id ~= nil, "missing tile id: " .. tostring(i))
    tile_ids[i] = tile.id
  end
  return tile_ids
end

local function _find_owner_name(players, owner_id)
  if not owner_id or type(players) ~= "table" then
    return nil
  end
  for _, p in ipairs(players) do
    if p.id == owner_id then
      return p.name
    end
  end
  return nil
end

local function _render_board_tiles(board, tiles, tile_count)
  local board_tiles = assert(board.tile_states, "missing ui_model.board.tile_states")
  local tile_ids = _collect_tile_ids(board)
  for i = 1, tile_count do
    local tile_id = assert(tile_ids[i], "missing tile_id: " .. tostring(i))
    local unit = assert(tiles[i], "missing tile unit: " .. tostring(i))
    local tile = assert(board.tiles[i], "missing board tile: " .. tostring(i))
    local tile_state = board_tiles[tile_id]
    if tile.type == "land" then
      assert(tile_state ~= nil, "missing board tile state: " .. tostring(tile_id))
    end
    local owner_id = tile_state and tile_state.owner_id or nil
    local owner_name = _find_owner_name(board.players, owner_id)
    local level = tile_state and tile_state.level or nil
    tile_renderer.render_tile(unit, tile_id, owner_id, owner_name, level)
  end
end

local function _calc_tile_spacing(positions, tile_count)
  local spacing = 0
  local spacing_count = 0
  for i = 1, tile_count - 1 do
    local a = positions[i]
    local b = positions[i + 1]
    assert(a ~= nil and a.x ~= nil and a.y ~= nil and a.z ~= nil, "missing tile position: " .. tostring(i))
    assert(b ~= nil and b.x ~= nil and b.y ~= nil and b.z ~= nil, "missing tile position: " .. tostring(i + 1))
    local dx = b.x - a.x
    local dy = b.y - a.y
    local dz = b.z - a.z
    local dist = math.Vector3(dx, dy, dz):length()
    assert(dist ~= nil, "missing tile distance: " .. tostring(i))
    if dist > 0 then
      spacing = spacing + dist
      spacing_count = spacing_count + 1
    end
  end
  if spacing_count > 0 then
    return (spacing / spacing_count) * 0.28
  end
  return nil
end

function M.ensure_tile_anchors(state, board, scene, tile_count, log_once, build_log_prefix)
  if state.tile_positions and #state.tile_positions >= tile_count then
    return
  end

  assert(type(scene.tiles) == "table", "missing board_scene.tiles")
  assert(#scene.tiles >= tile_count, "insufficient board_scene.tiles")
  local tiles = scene.tiles

  local positions = _collect_tile_positions(tiles, tile_count)
  state.tile_units = tiles
  state.tile_positions = positions

  _render_board_tiles(board, tiles, tile_count)

  local spacing = _calc_tile_spacing(positions, tile_count)
  if spacing then
    state.tile_spacing = spacing
  end

  log_once(state, "info", "tiles_ready", build_log_prefix(), "tile anchors ready:", tostring(tile_count))
end

M._M_test = {
  _find_owner_name = _find_owner_name,
}

return M
