local visual_sync = require("src.ui.render.board.visual_sync")

local M = {}

local function _append_overlay_indices(overlay_indices, overlay_map)
  for board_index in pairs(overlay_map or {}) do
    overlay_indices[#overlay_indices + 1] = board_index
  end
end

function M.apply(state, board, scene)
  local game = state and state.game or nil
  local render_bootstrap = game and game.test_profile_render_bootstrap or nil
  if type(render_bootstrap) ~= "table" or render_bootstrap.applied == true then
    return false
  end

  local tile_ids = {}
  local overlay_indices = {}
  local tiles_by_id = render_bootstrap.tiles_by_id or {}
  for tile_id in pairs(tiles_by_id) do
    tile_ids[#tile_ids + 1] = tile_id
  end

  local overlays = render_bootstrap.overlays or {}
  _append_overlay_indices(overlay_indices, overlays.roadblock)
  _append_overlay_indices(overlay_indices, overlays.mine)
  local rendered = visual_sync.sync_many(state, {
    tile_ids = tile_ids,
    overlay_indices = overlay_indices,
  })
  render_bootstrap.applied = true
  return rendered
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=fe570af6e419b967
scope.0.id=chunk:src/ui/render/board/startup_render.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=293a465513097186
]]
