-- settlement_shared 直测:结算共享助手的形状与解析路径。
-- card_choice 等集成 spec 只驱动 choice_meta/resolve_actor 少数臂(变异清扫 #259
-- survivor 真缺口闭合);本 spec 钉 settled/with_ok 结果形状与 resolve_tile 全家
-- (context 直通 / tile_id / board_index / actor.position / 缺 board 兜底)。
-- shared_support 仅加载即建立共享运行时基线(窄车道 #217 纪律),本 spec 不调其函数。
require("test.support.shared_support")
require("test.bootstrap").install_package_paths()
local luassert = assert
local shared = require("src.rules.land.settlement_shared")

local function _make_game(board)
  return {
    board = board,
    find_player_by_id = function(_, pid)
      return { id = pid }
    end,
  }
end

local function _make_board()
  return {
    get_tile_by_id = function(_, tile_id)
      return { from = "by_id", tile_id = tile_id }
    end,
    get_tile = function(_, index)
      return { from = "by_index", index = index }
    end,
  }
end

describe("TestSettlementShared", function()
it("test_settled_pins_the_settled_result_shape", function()
  local result = shared.settled()

  luassert.truthy(result.ok == true and result.status == "settled" and result.settled == true,
    "settled shape: ok/status/settled")
end)

it("test_with_ok_fills_a_missing_ok_flag_and_preserves_an_explicit_one", function()
  local filled = shared.with_ok({ status = "resolved" })
  luassert.truthy(filled.ok == true, "missing ok defaults to true")

  local explicit = shared.with_ok({ ok = false, status = "rejected" })
  luassert.truthy(explicit.ok == false, "explicit ok is preserved")

  luassert.is.equal("not-a-table", shared.with_ok("not-a-table"))
end)

it("test_resolve_actor_returns_nil_without_a_finder_and_the_player_with_one", function()
  luassert.is_nil(shared.resolve_actor({}, 1))
  luassert.is_nil(shared.resolve_actor(nil, 1))

  local player = shared.resolve_actor(_make_game(), 9)
  luassert.truthy(player ~= nil and player.id == 9, "finder resolves the actor")
end)

it("test_resolve_tile_prefers_the_context_tile_over_any_board_lookup", function()
  local context_tile = { from = "context" }
  local tile = shared.resolve_tile(_make_game(_make_board()), { position = 2 }, { tile = context_tile })

  luassert.is.equal(context_tile, tile)
end)

it("test_resolve_tile_resolves_by_tile_id_through_the_board", function()
  local tile = shared.resolve_tile(_make_game(_make_board()), { position = 2 }, { tile_id = 7 })

  luassert.truthy(tile ~= nil and tile.from == "by_id" and tile.tile_id == 7,
    "tile_id routes to get_tile_by_id")
end)

it("test_resolve_tile_prefers_board_index_over_the_actor_position", function()
  local tile = shared.resolve_tile(_make_game(_make_board()), { position = 2 }, { board_index = 5 })

  luassert.truthy(tile ~= nil and tile.from == "by_index" and tile.index == 5,
    "board_index routes to get_tile")
end)

it("test_resolve_tile_falls_back_to_the_actor_position_and_accepts_a_nil_context", function()
  local game = _make_game(_make_board())

  local by_position = shared.resolve_tile(game, { position = 2 }, {})
  luassert.truthy(by_position ~= nil and by_position.from == "by_index" and by_position.index == 2,
    "empty context falls back to actor.position")

  local nil_context = shared.resolve_tile(game, { position = 3 }, nil)
  luassert.truthy(nil_context ~= nil and nil_context.from == "by_index" and nil_context.index == 3,
    "nil context behaves like an empty one")
end)

it("test_resolve_tile_returns_nil_when_the_game_has_no_board", function()
  luassert.is_nil(shared.resolve_tile(_make_game(nil), { position = 2 }, {}))
end)

it("test_resolve_tile_returns_nil_when_neither_board_index_nor_actor_position_resolves", function()
  -- 无 actor、context 无 tile_id/board_index:get_tile 的 index 实参为 nil,
  -- 板查询按缺实参短路返回 nil(而不是把 nil 当索引去问 board)。
  luassert.is_nil(shared.resolve_tile(_make_game(_make_board()), nil, {}))
end)

it("test_resolve_choice_player_rejects_when_the_actor_is_unresolvable", function()
  local player, err = shared.resolve_choice_player({}, { player_id = 1 })

  luassert.is_nil(player)
  luassert.truthy(err ~= nil and err.ok == false and err.reason == "missing_actor",
    "missing actor rejects with missing_actor")
end)

it("test_resolve_choice_tile_rejects_when_the_tile_is_unresolvable", function()
  local tile, err = shared.resolve_choice_tile(_make_game(nil), { id = 1 }, { tile_id = 7 })

  luassert.is_nil(tile)
  luassert.truthy(err ~= nil and err.ok == false and err.reason == "missing_tile",
    "missing tile rejects with missing_tile")
end)

it("test_build_game_ctx_defaults_phase_to_landing", function()
  -- #293:build_game_ctx 的 phase_default 默认("landing"→nil / or→and 变异)未测。
  local ctx = shared.build_game_ctx({ turn = {} }, {})
  luassert.truthy(ctx.phase == "landing",
    "phase should fall back to the landing default; got " .. tostring(ctx.phase))
  luassert.truthy(ctx.on_landing == true, "on_landing should be set")
end)


end)
