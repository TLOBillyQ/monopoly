-- Coverage for the view-model projection modules src.ui.view.board_slice and
-- src.ui.view.item_slice: contiguous count/rent projection onto tile states,
-- and the standalone item-slot builder that trims empty inventory entries.
local lu = require("luaunit")
local board_slice = require("src.ui.view.board_slice")
local item_slice = require("src.ui.view.item_slice")

TestBoardSlice = {}

function TestBoardSlice:test_projects_contiguous_counts_and_rents_per_owner()
  local game = {
    board = {
      path = {
        { id = 1, type = "land" },
        { id = 2, type = "land" },
      },
      tile_lookup = {
        [1] = { type = "land", owner_id = "p1", level = 0, price = 100 },
        [2] = { type = "land", owner_id = "p1", level = 0, price = 100 },
      },
      map = {
        neighbors = {
          [1] = { 2 },
          [2] = { 1 },
        },
      },
      get_overlays = function() return {} end,
    },
    players = {},
  }
  game.board.get_tile_by_id = function(_, tile_id)
    return game.board.tile_lookup[tile_id]
  end
  local env = { game = game }
  local turn = { phase = "pre_action" }

  local result = board_slice.build(game, env, turn)
  lu.assertEquals(result.tile_states[1].contiguous_count, 2, "p1 tile 1 should see count 2")
  lu.assertEquals(result.tile_states[2].contiguous_count, 2, "p1 tile 2 should see count 2")
  lu.assertEquals(result.tile_states[1].contiguous_rent, 100, "p1 tile 1 should see summed contiguous rent")
  lu.assertEquals(result.tile_states[2].contiguous_rent, 100, "p1 tile 2 should see summed contiguous rent")

  local game2 = {
    board = {
      path = { { id = 1, type = "land" } },
      tile_lookup = { [1] = { type = "land", owner_id = nil, level = 0 } },
      map = { neighbors = { [1] = {} } },
      get_overlays = function() return {} end,
    },
    players = {},
  }
  game2.board.get_tile_by_id = function(_, tile_id)
    return game2.board.tile_lookup[tile_id]
  end
  local result2 = board_slice.build(game2, { game = game2 }, turn)
  lu.assertEquals(result2.tile_states[1].contiguous_count, nil, "unowned tile should have nil count")
  lu.assertEquals(result2.tile_states[1].contiguous_rent, nil, "unowned tile should have nil rent")
end

local function _slice_game(path_ids)
  local path = {}
  for _, id in ipairs(path_ids or { 1, 2 }) do
    path[#path + 1] = { id = id }
  end
  local game = {
    board = {
      path = path,
      tile_lookup = {},
      map = { neighbors = {} },
      get_overlays = function() return { "overlay_a" } end,
      get_tile_by_id = function() return nil end,
    },
    players = { { id = 1 }, { id = 2 } },
  }
  return game
end

function TestBoardSlice:test_build_projects_tile_fields_from_config()
  -- L85-L91 cfg 字段投影(名称/类型/价格/行列的换 nil 变异):path 里的
  -- tile 必须按 tiles_cfg 投影全量字段。
  local game = _slice_game({ 1, 2 })
  local result = board_slice.build(game, { game = game }, { phase = "pre_action" })
  lu.assertEquals(result.tiles[1].id, 1, "tile id must project")
  lu.assertEquals(result.tiles[1].name, "福州路", "tile name must come from cfg")
  lu.assertEquals(result.tiles[1].type, "land", "tile type must come from cfg")
  lu.assertEquals(result.tiles[1].price, 1000, "tile price must come from cfg")
  lu.assertEquals(result.tiles[1].row, 9, "tile row must come from cfg")
  lu.assertEquals(result.tiles[1].col, 8, "tile col must come from cfg")
  lu.assertEquals(#result.tiles, 2, "one projected tile per path entry")
end

function TestBoardSlice:test_build_populates_board_envelope_fields()
  -- L103-L113 封套字段(players/phase/move_anim/action_anim/布尔强制/
  -- 序号回退/玩家 id/tile_count/overlays 的换 nil 变异):target 必须全量
  -- 搬运,布尔字段必须真值化,序号缺省回退 0。
  local game = _slice_game({ 1 })
  local move_anim = { steps = {} }
  local action_anim = { kind = "roadblock" }
  local turn = {
    phase = "wait_action",
    move_anim = move_anim,
    action_anim = action_anim,
    move_followup_pending = true,
    turn_start_prompt_player_id = "p7",
  }
  local result = board_slice.build(game, { game = game }, turn)
  lu.assertEquals(result.players, game.players, "players must reference the game roster")
  lu.assertEquals(result.phase, "wait_action", "phase must pass through")
  lu.assertEquals(result.move_anim, move_anim, "move anim must pass through")
  lu.assertEquals(result.action_anim, action_anim, "action anim must pass through")
  lu.assertEquals(result.move_followup_pending, true, "truthy followup pending must coerce to true")
  lu.assertEquals(result.turn_start_prompt_seq, 0, "missing prompt seq must default to zero")
  lu.assertEquals(result.turn_start_prompt_player_id, "p7", "prompt player id must pass through")
  lu.assertEquals(result.tile_count, 1, "tile count must match the projected path")
  lu.assertEquals(result.overlays[1], "overlay_a", "overlays must come from the board")
end

function TestBoardSlice:test_build_overlays_come_from_board()
  -- L94 `env.game.board:get_overlays()` 调用换 nil:overlays 必须直取
  -- board 的 get_overlays 结果。
  local game = _slice_game({ 1 })
  local result = board_slice.build(game, { game = game }, { phase = "x" })
  lu.assertEquals(result.overlays[1], "overlay_a", "overlays must be the board overlays")
end

function TestBoardSlice:test_update_caches_board_tiles_and_tracks_count()
  -- L66 缓存换 path 的 and->or 与 L117 缓存赋值换 nil:tile_count 必须
  -- 反映最近一次 build 的投影结果。
  local game = _slice_game({ 1, 2 })
  board_slice.build(game, { game = game }, { phase = "x" })
  lu.assertEquals(board_slice.tile_count(), 2, "tile count must reflect the last build")
  local game2 = _slice_game({ 1 })
  local second = board_slice.build(game2, { game = game2 }, { phase = "x" })
  lu.assertEquals(#second.tiles, 1, "a new path must rebuild the projection")
  lu.assertEquals(board_slice.tile_count(), 1, "tile count must follow the new build")
end

function TestBoardSlice:test_single_owned_tile_projects_count_one_and_level_zero_rent()
  -- L26 `count > 0` 的 0 -> 1(变异体对单连片误判为 nil)与 L31
  -- `tile.level or 0` 的 0 -> 1(变异体把 level 0 抬成 level 1 换租金档):
  -- 单块自有地与 0 级租金必须按真实连片数与 0 级档投影。
  local game = {
    board = {
      path = { { id = 1, type = "land" } },
      tile_lookup = {
        -- level 缺省(nil):`tile.level or 0` 的回退才可达——level 显式 0 时
        -- 0 为 truthy,or 短路,`0 -> 1` 变异不可观测。
        [1] = { type = "land", owner_id = "p1", price = 100, rents = { 100, 200, 300 }, upgrade_costs = { 100, 200 } },
      },
      map = { neighbors = { [1] = {} } },
      get_overlays = function() return {} end,
    },
    players = {},
  }
  game.board.get_tile_by_id = function(_, tile_id)
    return game.board.tile_lookup[tile_id]
  end
  local result = board_slice.build(game, { game = game }, { phase = "x" })
  lu.assertEquals(result.tile_states[1].contiguous_count, 1, "single owned tile must see count 1")
  lu.assertEquals(result.tile_states[1].contiguous_rent, 50, "level zero rent must be the level zero tier")
end

function TestBoardSlice:test_update_reuses_the_cached_projection_for_the_same_path()
  -- L69 `#cached_board_tiles > 0` 的 0 -> 1(变异体对单块缓存误判重建):
  -- 同一 path 表的连续 build 必须复用同一张投影表。
  local game = _slice_game({ 1 })
  local first = board_slice.build(game, { game = game }, { phase = "x" })
  local second = board_slice.build(game, { game = game }, { phase = "x" })
  lu.assertEvalToTrue(second.tiles == first.tiles, "same path must reuse the cached tiles table")
  lu.assertEquals(board_slice.tile_count(), 1, "tile count must stay one")
end

function TestBoardSlice:test_standalone_slots_map_bag_index_directly_without_compaction()
  -- CONTEXT「道具槽位」 稳定槽位:槽位 i 直映射背包第 i 格,无 id 条目留空、不补位,
  -- 后面的卡保持原槽位,超槽数部分裁掉。
  local slots = item_slice.build_item_slots_for_player({
    inventory = {
      items = {
        { id = 11 },
        {},
        { id = 22 },
        { id = 33 },
      },
    },
  }, 3)

  lu.assertEquals(slots[1], 11, "slot 1 maps bag index 1")
  lu.assertEquals(slots[2], nil, "bag entry without id leaves slot 2 empty (no compaction)")
  lu.assertEquals(slots[3], 22, "the card after the empty entry keeps slot 3")
  lu.assertEquals(slots[4], nil, "slot builder should trim beyond slot count")
end


return TestBoardSlice
