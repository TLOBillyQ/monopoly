local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

describe("presentation visual_sync facade", function()
  it("re-exports the tile, overlay, and batch sync entry points", function()
    local facade_path = "src.ui.render.board.visual_sync"
    local saved = package.loaded[facade_path]
    package.loaded[facade_path] = nil
    local facade = require(facade_path)
    package.loaded[facade_path] = saved

    local tile_sync = require("src.ui.render.board.visual_sync_tile")
    local overlay_sync = require("src.ui.render.board.visual_sync_overlay")
    local batch_sync = require("src.ui.render.board.visual_sync_batch")

    _assert_eq(facade.sync_tile_visual, tile_sync.sync_tile_visual,
      "facade should re-export the tile sync entry point")
    _assert_eq(facade.sync_overlay_visual, overlay_sync.sync_overlay_visual,
      "facade should re-export the overlay sync entry point")
    _assert_eq(facade.sync_many, batch_sync.sync_many,
      "facade should re-export the batch sync entry point")
  end)
end)
