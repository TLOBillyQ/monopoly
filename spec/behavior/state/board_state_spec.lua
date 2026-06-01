local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq
local board_state = require("src.state.board_state")

-- board_state mixin methods route every tile mutation through _sync_board_visual;
-- these exercise that port resolution (attached / lazily ensured / missing / throwing)
-- via the public set_tile_owner entry.
local function _land_tile(id, owner_id)
  return { type = "land", id = id, owner_id = owner_id }
end

describe("board_state._sync_board_visual via set_tile_owner", function()
  it("pushes the changed tile through an attached feedback port", function()
    local synced = nil
    local self_state = {
      dirty = {},
      board_visual_feedback_port = {
        sync_many = function(_, payload)
          synced = payload
          return true
        end,
      },
    }

    board_state.set_tile_owner(self_state, _land_tile(5, 2), 7)

    _assert_eq(self_state.dirty.board_tiles, true, "owner change should mark the board dirty")
    assert(synced ~= nil, "an attached feedback port should receive the sync payload")
    _assert_eq(synced.tile_ids[1], 5, "sync payload should target the changed tile id")
  end)

  it("lazily ensures a feedback port when none is attached yet", function()
    local ensured = 0
    local synced = false
    local self_state = {
      dirty = {},
      ensure_board_visual_feedback_port = function()
        ensured = ensured + 1
        return {
          sync_many = function()
            synced = true
            return true
          end,
        }
      end,
    }

    board_state.set_tile_owner(self_state, _land_tile(1), 3)

    _assert_eq(ensured, 1, "a missing port should be lazily ensured exactly once")
    _assert_eq(synced, true, "the ensured port should receive the sync")
  end)

  it("still completes the owner change with no port and survives a throwing port", function()
    local no_port = { dirty = {} }
    board_state.set_tile_owner(no_port, _land_tile(1), 3)
    _assert_eq(no_port.dirty.board_tiles, true,
      "owner change should mark dirty even without a feedback port")

    local throwing = {
      dirty = {},
      board_visual_feedback_port = {
        sync_many = function()
          error("sync boom")
        end,
      },
    }
    local tile = _land_tile(2)
    local ok = pcall(board_state.set_tile_owner, throwing, tile, 4)
    _assert_eq(ok, true, "a throwing feedback port must not break the owner update")
    _assert_eq(tile.owner_id, 4, "the owner should still be applied despite the port error")
  end)
end)
