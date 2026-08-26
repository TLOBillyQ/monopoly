-- #293 批3 pin:src/ui/render/board/visual_sync_tile.lua 的幸存者分四簇:
-- ① 归属渲染链(_resolve_owner_name / _tile_owner_and_level / _resolve_contiguous_rent
--    的 and/or/nil 变异,经 tile_renderer.render_tile 实参捕获击杀);
-- ② 建筑同步链(_sync_building_level / _sync_building_visual 的 spawned-or 语义、
--    clear 调用、q_zero 实参,经 building_effects 桩捕获击杀);
-- ③ 早退链(sync_tile_visual 的 tile_id nil / board nil / idx nil 的 == ~= 变异);
-- ④ _board_and_scene 的可同步判定(board/scene/index_of_tile_id 三连 and)。
-- 桩 tile_renderer.render_tile 与 building_effects 两个同表模块,contiguous
-- 计数桩化以控制租金值(50 / 0 / nil 三态)。shared 用真实模块。

local lu = require("luaunit")

local visual_sync_tile = require("src.ui.render.board.visual_sync_tile")
local tile_renderer = require("src.ui.render.board.tile")
local building_effects = require("src.ui.render.board.building_effects")
local contiguous_count = require("src.ui.view.contiguous_count")
local runtime_constants = require("src.config.gameplay.runtime_constants")

local _saved_render_tile = tile_renderer.render_tile
local _saved_spawn = building_effects.spawn_upgrade_building_units
local _saved_clear = building_effects.clear_building_units
local _saved_build_rent = contiguous_count.build_rent_for_owner

local _captured = nil

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

-- tile_id 3 -> idx 1;其余 tile_id 查无(返回 nil,触发 idx nil 早退)。
local function _board(tile)
  return {
    index_of_tile_id = function(_, tile_id)
      if tile_id == 3 then
        return 1
      end
      return nil
    end,
    get_tile_by_id = function(_, _)
      return tile
    end,
    find_player_by_id = function(_, _)
      return { name = "P1" }
    end,
  }
end

local function _state(overrides)
  local state = {
    game = {
      board = _board({ owner_id = "p1", level = 2 }),
      find_player_by_id = function(_, _)
        return { name = "P1" }
      end,
    },
    board_scene = { tiles = {}, buildings = {}, building_unit_groups = {} },
    tile_units = { [1] = "tile_unit_handle" },
    presentation_runtime = { marker = "rt" },
  }
  for key, value in pairs(overrides or {}) do
    state[key] = value
  end
  return state
end

TestVisualSyncTile = {}

function TestVisualSyncTile:setUp()
  _captured = {
    render = {},
    spawn = {},
    clear = {},
    rent_builds = 0,
    rent_value = 50,
  }
  tile_renderer.render_tile = function(tile_unit, tile_id, owner_id, owner_name, level, contiguous_rent)
    _captured.render[#_captured.render + 1] = {
      tile_unit = tile_unit, tile_id = tile_id, owner_id = owner_id,
      owner_name = owner_name, level = level, contiguous_rent = contiguous_rent,
    }
  end
  building_effects.spawn_upgrade_building_units = function(scene, root_quaternion, idx, level, deps)
    _captured.spawn[#_captured.spawn + 1] = {
      scene = scene, root_quaternion = root_quaternion, idx = idx, level = level, deps = deps,
    }
    return true
  end
  building_effects.clear_building_units = function(scene, idx, deps)
    _captured.clear[#_captured.clear + 1] = { scene = scene, idx = idx, deps = deps }
    return true
  end
  contiguous_count.build_rent_for_owner = function()
    _captured.rent_builds = _captured.rent_builds + 1
    return { [3] = _captured.rent_value }
  end
end

function TestVisualSyncTile:tearDown()
  tile_renderer.render_tile = _saved_render_tile
  building_effects.spawn_upgrade_building_units = _saved_spawn
  building_effects.clear_building_units = _saved_clear
  contiguous_count.build_rent_for_owner = _saved_build_rent
end

function TestVisualSyncTile:test_sync_renders_owner_tile_with_resolved_fields()
  -- 归属渲染链主契约:_resolve_tile_unit 优先取 state.tile_units,render_tile
  -- 收到 owner_id / owner_name / level / contiguous_rent 全量解析结果。
  -- L61 player.name 换 nil、L39 rent>0 的 0 换 nil 等变异在此击杀。
  local state = _state()
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, true, "sync must report success")
  _assert_eq(#_captured.render, 1, "render_tile must be called")
  local render = _captured.render[1]
  _assert_eq(render.tile_unit, "tile_unit_handle", "tile unit must come from state.tile_units")
  _assert_eq(render.tile_id, 3, "tile id must pass through")
  _assert_eq(render.owner_id, "p1", "owner id must be resolved")
  _assert_eq(render.owner_name, "P1", "owner name must be resolved via game")
  _assert_eq(render.level, 2, "level must be resolved")
  _assert_eq(render.contiguous_rent, 50, "contiguous rent must be resolved")
end

function TestVisualSyncTile:test_sync_uses_scene_tiles_when_state_tile_units_missing()
  -- L25 `from_state ~= nil` 的 ~= -> ==(变异体在 state 无值时跳过 scene
  -- 回退直接返回 nil):state.tile_units 缺该槽时须回退 scene.tiles。
  local state = _state({ tile_units = {} })
  state.board_scene.tiles[1] = "scene_tile_handle"
  visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(#_captured.render, 1, "scene fallback must render")
  _assert_eq(_captured.render[1].tile_unit, "scene_tile_handle", "tile unit must come from scene.tiles")
end

function TestVisualSyncTile:test_sync_reports_zero_rent_as_nil()
  -- L39 `rent > 0` 的 > -> >=:租金 0 时 contiguous_rent 必须回退 nil。
  _captured.rent_value = 0
  visual_sync_tile.sync_tile_visual(_state(), 3)
  _assert_eq(_captured.render[1].contiguous_rent, nil, "zero rent must report nil")
end

function TestVisualSyncTile:test_sync_skips_rent_build_when_no_owner()
  -- L32 `owner_id == nil or board == nil` 的 or -> and:owner 缺失时不得
  -- 调用租金构建器,owner_name / contiguous_rent 均为 nil。
  local state = _state()
  state.game.board = _board({ owner_id = nil, level = 2 })
  visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(_captured.rent_builds, 0, "no owner must not build rents")
  _assert_eq(_captured.render[1].owner_name, nil, "no owner must yield nil owner name")
  _assert_eq(_captured.render[1].contiguous_rent, nil, "no owner must yield nil rent")
end

function TestVisualSyncTile:test_sync_spawns_building_units_for_leveled_tile()
  -- 生成链主契约:level>0 时 spawn_upgrade_building_units 收到 scene /
  -- q_zero / idx / level / presentation_runtime,结果与 tile_unit 存在性
  -- 共同决定返回值(L88 spawned-or 语义,此例 tile_unit 缺失靠 spawned 兜底)。
  local state = _state({ tile_units = {} })
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, true, "spawn success must yield true even without a tile unit")
  _assert_eq(#_captured.spawn, 1, "spawn must be called for leveled tile")
  local spawn = _captured.spawn[1]
  _assert_eq(spawn.scene, state.board_scene, "spawn must receive the scene")
  _assert_eq(spawn.root_quaternion, runtime_constants.q_zero, "spawn must receive Q_ZERO")
  _assert_eq(spawn.idx, 1, "spawn must receive the scene index")
  _assert_eq(spawn.level, 2, "spawn must receive the tile level")
  _assert_eq(spawn.deps, state.presentation_runtime, "spawn must receive the presentation runtime deps")
end

function TestVisualSyncTile:test_sync_clears_building_units_for_unleveled_tile()
  -- 清除链主契约:level 0 时 clear_building_units 收到 scene / idx / deps,
  -- 返回值恒 true。
  local state = _state()
  state.game.board = _board({ owner_id = "p1", level = 0 })
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, true, "clear path must yield true")
  _assert_eq(#_captured.clear, 1, "clear must be called for unleveled tile")
  local clear = _captured.clear[1]
  _assert_eq(clear.scene, state.board_scene, "clear must receive the scene")
  _assert_eq(clear.idx, 1, "clear must receive the scene index")
  _assert_eq(clear.deps, state.presentation_runtime, "clear must receive the presentation runtime deps")
end

function TestVisualSyncTile:test_sync_falls_back_to_tile_unit_when_spawn_fails()
  -- L88 `spawned or tile_unit ~= nil` 的 ~= -> ==:生成失败但 tile_unit 在
  -- 手时仍须返回 true。
  local state = _state()
  building_effects.spawn_upgrade_building_units = function()
    return false
  end
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, true, "existing tile unit must back the failed spawn")
end

function TestVisualSyncTile:test_sync_returns_false_for_unknown_tile_index()
  -- L122 `idx == nil` 的 == -> ~=(变异体继续走同步链):查无 tile 时须早退
  -- false,不得触发任何生成/清除。
  local state = _state()
  local result = visual_sync_tile.sync_tile_visual(state, 99)
  _assert_eq(result, false, "unknown tile index must report failure")
  _assert_eq(#_captured.render, 0, "unknown tile must not render")
  _assert_eq(#_captured.clear, 0, "unknown tile must not clear")
  _assert_eq(#_captured.spawn, 0, "unknown tile must not spawn")
end

function TestVisualSyncTile:test_sync_returns_false_for_nil_tile_id()
  -- L114 `tile_id == nil` 的 == -> ~=(变异体放行后带 nil id 走同步链):
  -- nil tile_id 必须早退 false。
  local result = visual_sync_tile.sync_tile_visual(_state(), nil)
  _assert_eq(result, false, "nil tile id must report failure")
  _assert_eq(#_captured.render, 0, "nil tile id must not render")
end

function TestVisualSyncTile:test_sync_returns_false_when_board_or_scene_unavailable()
  -- L107 `board and scene and type(...)` 三连 and 的任一换 nil/or->and:
  -- 缺 scene 时同步必须整体不落地(render/spawn/clear 全不触发)。
  local state = _state()
  state.board_scene = nil
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, false, "missing scene must report failure")
  _assert_eq(#_captured.render, 0, "missing scene must not render")
  _assert_eq(#_captured.clear, 0, "missing scene must not clear")
end

function TestVisualSyncTile:test_sync_returns_false_when_scene_lacks_building_buckets()
  -- L97 `scene.buildings and scene.building_unit_groups` 的 and -> or
  -- (仅一桶存在时变异体放行进生成链):缺任一桶须按无可建筑早退。
  local state = _state()
  state.board_scene.building_unit_groups = nil
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, true, "no building buckets must fall back to tile unit presence")
  _assert_eq(#_captured.spawn, 0, "missing buckets must not spawn")
  _assert_eq(#_captured.clear, 0, "missing buckets must not clear")
end

function TestVisualSyncTile:test_sync_returns_false_without_index_of_tile_id()
  -- L107 `type(board.index_of_tile_id) == "function"` 的 == -> ~=:board
  -- 不可索引时须整体早退。
  local state = _state()
  state.game.board = { get_tile_by_id = function() return { owner_id = "p1", level = 2 } end }
  local result = visual_sync_tile.sync_tile_visual(state, 3)
  _assert_eq(result, false, "non-indexable board must report failure")
  _assert_eq(#_captured.render, 0, "non-indexable board must not render")
end

return TestVisualSyncTile
