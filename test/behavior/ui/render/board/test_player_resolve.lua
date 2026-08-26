---@diagnostic disable: need-check-nil, different-requires, undefined-field

local P = require("test.support.shared_support")
local _assert_eq = P.assert_eq
local luax = require("test.support.luax")
local player_resolve = require("src.ui.render.board.player_resolve")

TestPlayerResolve = {}

function TestPlayerResolve:test_resolve_player_id_asserts_on_missing_id()
  -- L4 消息钉:player 无 id 时必须报 "missing player id: <i>"。
  luax.has_error(function()
    player_resolve.resolve_player_id({}, 2)
  end, "missing player id: 2")
end

function TestPlayerResolve:test_resolve_active_player_base_asserts_on_missing_position()
  -- L8 消息钉:player 无 position 时必须报 "missing player position: <i>"。
  luax.has_error(function()
    player_resolve.resolve_active_player_base({ tile_positions = {} }, {}, 1)
  end, "missing player position: 1")
end

function TestPlayerResolve:test_resolve_active_player_base_asserts_on_missing_tile_positions()
  -- L9 消息换 nil:state 未先建 tile_positions 时必须钉死报错(anchors 前置依赖)。
  luax.has_error(function()
    player_resolve.resolve_active_player_base({}, { position = 1 }, 1)
  end, "missing tile_positions")
end

function TestPlayerResolve:test_resolve_active_player_base_returns_index_base_and_player_id()
  local state = {
    tile_positions = {
      [3] = { x = 10.0, y = 0.0, z = 0.0 },
    },
  }
  local idx, base, pid = player_resolve.resolve_active_player_base(
    state,
    { position = 3, id = "p_1" },
    1
  )
  _assert_eq(idx, 3, "should return the player position index")
  _assert_eq(base.x, 10.0, "should return the resolved tile position")
  _assert_eq(pid, "p_1", "should return the resolved player id")
end

return TestPlayerResolve
