-- luacheck: ignore 143
require("test.bootstrap").install_package_paths()
local luassert = assert
---@diagnostic disable: need-check-nil, different-requires, undefined-field

local function _assert_eq(actual, expected, message) luassert.is.equal(expected, actual, message) end
local player_resolve = require("src.ui.render.board.player_resolve")

describe("TestPlayerResolve", function()

  it("test_resolve_player_id_asserts_on_missing_id", function()
    -- L4 消息钉:player 无 id 时必须报 "missing player id: <i>"。
    luassert.has_error(function()
      player_resolve.resolve_player_id({}, 2)
    end, "missing player id: 2")
  end)

  it("test_resolve_active_player_base_asserts_on_missing_position", function()
    -- L8 消息钉:player 无 position 时必须报 "missing player position: <i>"。
    luassert.has_error(function()
      player_resolve.resolve_active_player_base({ tile_positions = {} }, {}, 1)
    end, "missing player position: 1")
  end)

  it("test_resolve_active_player_base_asserts_on_missing_tile_positions", function()
    -- L9 消息换 nil:state 未先建 tile_positions 时必须钉死报错(anchors 前置依赖)。
    luassert.has_error(function()
      player_resolve.resolve_active_player_base({}, { position = 1 }, 1)
    end, "missing tile_positions")
  end)

  it("test_resolve_active_player_base_returns_index_base_and_player_id", function()
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
  end)

end)
