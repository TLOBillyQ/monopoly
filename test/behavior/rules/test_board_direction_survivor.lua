-- direction.lua 变异 survivor 补测（#167）：钉住 legacy 解析路径——
-- 回落链取向优先级、avoid-dir 语义、朝向连续性（map.direction 消费）、
-- 入口门控 flag、fresh_forward 与 facing 的互斥。全部走公开面 + 合成地图。
local lu = require("luaunit")
local direction = require("src.rules.board.direction")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 TestBoardDirectionSurvivor 类
-- (无钩子,不拆子类),中文 it 名按原名逐字保留为 test_ 前缀方法,断言切到
-- lu.assertXxx,用例数与改写前一一对应(17 例)。

local function _assert_eq(a, b, msg)
  lu.assertEquals(a, b, msg)
end

-- 由坐标网格合成 board：tiles = { id = {row, col} }，邻接与 map.direction 都从
-- 坐标推导，朝向断言因此有真实几何意义。不配 outer_next/fresh 链，
-- 逼解析器走 facing / 回落路径。
local function _grid_board(tiles, opts)
  opts = opts or {}
  local coords = {}
  local id_to_index = {}
  local index_to_tile = {}
  local n = 0
  for id, rc in pairs(tiles) do
    n = n + 1
    coords[id] = { row = rc[1], col = rc[2] }
  end
  -- 稳定编号：按 id 排序
  local ids = {}
  for id in pairs(tiles) do
    ids[#ids + 1] = id
  end
  table.sort(ids)
  for i, id in ipairs(ids) do
    id_to_index[id] = i
    index_to_tile[i] = { id = id }
  end
  local function dir_between(from_id, to_id)
    local f, t = coords[from_id], coords[to_id]
    if f == nil or t == nil then
      return nil
    end
    if t.row < f.row then return "up" end
    if t.row > f.row then return "down" end
    if t.col > f.col then return "right" end
    if t.col < f.col then return "left" end
    return nil
  end
  local neighbors = {}
  for id, c in pairs(coords) do
    neighbors[id] = {}
    for other, oc in pairs(coords) do
      if other ~= id and math.abs(c.row - oc.row) + math.abs(c.col - oc.col) == 1 then
        neighbors[id][dir_between(id, other)] = other
      end
    end
  end
  local map = {
    outer_next = opts.outer_next or {},
    outer_prev = opts.outer_prev or {},
    neighbors = neighbors,
    entry_points = opts.entry_points or {},
    fresh_forward_next = opts.fresh_forward_next,
    backward_fallback = opts.backward_fallback,
    direction = dir_between,
  }
  local board = {
    map = map,
    get_tile = function(_, index)
      return index_to_tile[index]
    end,
    index_of_tile_id = function(_, id)
      return id_to_index[id]
    end,
  }
  return board, map, id_to_index
end

local function _player_at(board, tile_id, move_dir)
  return {
    position = board:index_of_tile_id(tile_id),
    status = { move_dir = move_dir },
  }
end

local function _step_ids(board, result)
  local ids = {}
  for _, entry in ipairs(result.list) do
    ids[#ids + 1] = board:get_tile(entry.index).id
  end
  return ids
end

TestBoardDirectionSurvivor = {}

TestBoardDirectionSurvivor["test_前向行走朝向连续：竖直链一路向下,不回头"] = function(self)
  -- a(上) b(中) c(下)：b 的邻居含回头路 a（up,优先级最高）。丢失朝向的
  -- 实现会在 b 回落到 any-dir 优先选 up 回到 a——正确实现必须走到 c。
  local board = _grid_board({ a = { 1, 1 }, b = { 2, 1 }, c = { 3, 1 } })
  local result = direction.collect_forward_indices(board, _player_at(board, "a", "down"), 2)
  local ids = _step_ids(board, result)
  _assert_eq(#ids, 2, "walk should take two steps")
  _assert_eq(ids[1], "b", "first forward step")
  _assert_eq(ids[2], "c", "facing continuity must carry the walk past b")
end

TestBoardDirectionSurvivor["test_后向行走朝向连续：从顶端一路退到底,不折返"] = function(self)
  -- c(上) b(中) a(下)，玩家在 c 朝 up：退一步到 b 后,朝向必须按
  -- map.direction(b, c) 更新,否则 b 处回落 any-dir 优先选 up 折返 c。
  local board = _grid_board({ a = { 3, 1 }, b = { 2, 1 }, c = { 1, 1 } })
  local result = direction.collect_backward_indices(board, _player_at(board, "c", "up"), 2)
  local ids = _step_ids(board, result)
  _assert_eq(#ids, 2, "backward walk should take two steps")
  _assert_eq(ids[1], "b", "first backward step")
  _assert_eq(ids[2], "a", "backward facing continuity must not revisit c")
end

TestBoardDirectionSurvivor["test_回落链 any-dir 取向优先级：up > right > down > left,逐个剥离"] = function(self)
  -- 十字地图：中心 m 四邻俱全。无 facing 时 any-dir 依优先级取 up；
  -- 依次移除最高优先级邻居,验证 right、down、left 的完整次序。
  local full = { m = { 2, 2 }, u = { 1, 2 }, r = { 2, 3 }, d = { 3, 2 }, l = { 2, 1 } }
  local expectations = {
    { remove = nil, expected = "u" },
    { remove = "u", expected = "r" },
    { remove = "r", expected = "d" },
    { remove = "d", expected = "l" },
  }
  local tiles = full
  for _, case in ipairs(expectations) do
    if case.remove then
      local trimmed = {}
      for id, rc in pairs(tiles) do
        if id ~= case.remove then
          trimmed[id] = rc
        end
      end
      tiles = trimmed
    end
    local _, map = _grid_board(tiles)
    local next_id = direction.resolve_forward_next_id(map, "m", map.neighbors.m, nil, nil, true, nil)
    _assert_eq(next_id, case.expected, "any-dir priority pick after removing " .. tostring(case.remove))
  end
end

TestBoardDirectionSurvivor["test_回落链取向平级 tie-break：未知方向名按字典序取小"] = function(self)
  -- 非常规方向名优先级同为兜底值,比较器落入 tostring 字典序分支。
  local _, map = _grid_board({ m = { 2, 2 } })
  local neigh = { zz = "p", aa = "q" }
  local next_id = direction.resolve_forward_next_id(map, "m", neigh, nil, nil, true, nil)
  _assert_eq(next_id, "q", "equal-priority dirs should tie-break lexicographically")
end

TestBoardDirectionSurvivor["test_回落链 unique-dir 尊重 avoid-dir：唯一非回头邻居胜过高优先级回头路"] = function(self)
  -- m 只有 up=u（回头方向）与 left=l：facing=down 时 back_dir=up 被排除,
  -- 唯一候选是 left——尽管 up 优先级更高。
  local _, map = _grid_board({ m = { 2, 2 }, u = { 1, 2 }, l = { 2, 1 } })
  local next_id = direction.resolve_forward_next_id(map, "m", map.neighbors.m, "down", nil, true, nil)
  _assert_eq(next_id, "l", "unique non-back neighbor should win over a higher-priority back path")
end

TestBoardDirectionSurvivor["test_回落链绝路：仅剩回头邻居时仍可回头(最终兜底)"] = function(self)
  local _, map = _grid_board({ m = { 2, 2 }, u = { 1, 2 } })
  local next_id = direction.resolve_forward_next_id(map, "m", map.neighbors.m, "down", nil, true, nil)
  _assert_eq(next_id, "u", "dead end should fall back to the only (back) neighbor")
end

TestBoardDirectionSurvivor["test_facing 命中时不落入回落链取向"] = function(self)
  -- m 有 right=r 与 down=d：facing=down 必须直取 d；丢失 facing 判定的
  -- 实现会回落 any-dir 依优先级选 r。
  local _, map = _grid_board({ m = { 2, 2 }, r = { 2, 3 }, d = { 3, 2 } })
  local next_id = direction.resolve_forward_next_id(map, "m", map.neighbors.m, "down", nil, true, nil)
  _assert_eq(next_id, "d", "a live facing must win over fallback priority")
end

TestBoardDirectionSurvivor["test_回落链多候选仍避回头：非回头候选胜过高优先级回头路"] = function(self)
  -- m 有 up(回头)/right/down 三邻,facing=down→back=up:
  -- 有两个非回头候选时也必须避开 up,取优先级最高的 right。
  local _, map = _grid_board({ m = { 2, 2 }, u = { 1, 2 }, r = { 2, 3 }, d = { 3, 2 } })
  local neigh = { up = "u", right = "r", down = "d" }
  local next_id = direction.resolve_forward_next_id(map, "m", neigh, "down", nil, true, nil)
  -- facing=down 命中 d?注意 neigh.down 存在 → facing 直取。改用无 down 邻的构形:
  local neigh2 = { up = "u", right = "r", left = "l" }
  local pick = direction.resolve_forward_next_id(map, "m", neigh2, "down", nil, true, nil)
  _assert_eq(next_id, "d", "facing hit still wins when down exists")
  _assert_eq(pick, "r", "with multiple non-back options the back path must stay excluded")
end

TestBoardDirectionSurvivor["test_后向邻居回落多候选仍避 facing 方向"] = function(self)
  -- facing=up 的 opposite(down)缺席、无 outer_prev/backward_fallback →
  -- 落到 neighbor_fallback:多候选(up/right)时必须避开 facing 方向 up,取 right。
  local _, map = _grid_board({ m = { 2, 2 }, u = { 1, 2 }, r = { 2, 3 } })
  map.outer_prev = {}
  local result = direction.resolve_backward_next_source(map, "m", { up = "u", right = "r" }, "up")
  _assert_eq(result.next_id, "r", "neighbor fallback must avoid the facing dir even with multiple options")
  _assert_eq(result.source, "neighbor_fallback", "resolution should come from the neighbor fallback tier")
end

TestBoardDirectionSurvivor["test_前向行走的初始朝向必须生效"] = function(self)
  -- 玩家在十字中心 m 朝 down:首步必须是 d;丢失初始朝向的实现回落
  -- any-dir 会先选 u。同时钉 set 集合成员为 true。
  local board = _grid_board({ m = { 2, 2 }, u = { 1, 2 }, r = { 2, 3 }, d = { 3, 2 } })
  local result = direction.collect_forward_indices(board, _player_at(board, "m", "down"), 1)
  local ids = _step_ids(board, result)
  _assert_eq(ids[1], "d", "initial facing must drive the first forward step")
  _assert_eq(result.set[board:index_of_tile_id("d")], true, "collected index must be set-marked true")
end

TestBoardDirectionSurvivor["test_后向行走的初始朝向必须生效"] = function(self)
  -- facing=up 时首级 facing_reverse 取 opposite 邻居 d;丢失初始朝向的实现
  -- 落到 neighbor_fallback 依优先级取 u。同时钉 set 集合成员为 true。
  local board = _grid_board({ m = { 2, 2 }, u = { 1, 2 }, r = { 2, 3 }, d = { 3, 2 } })
  board.map.outer_prev = {}
  local result = direction.collect_backward_indices(board, _player_at(board, "m", "up"), 1)
  local ids = _step_ids(board, result)
  _assert_eq(ids[1], "d", "initial facing must resolve the retreat to the opposite neighbor")
  _assert_eq(result.set[board:index_of_tile_id("d")], true, "collected index must be set-marked true")
end

TestBoardDirectionSurvivor["test_fresh_forward 链只在无 facing 时生效"] = function(self)
  local _, map = _grid_board({ a = { 1, 1 }, b = { 1, 2 } }, {
    fresh_forward_next = { a = "z" },
  })
  local fresh_pick = direction.resolve_forward_next_id(map, "a", map.neighbors.a, nil, nil, true, nil)
  _assert_eq(fresh_pick, "z", "no facing should consult the fresh_forward chain")
  local facing_pick = direction.resolve_forward_next_id(map, "a", map.neighbors.a, "right", nil, true, nil)
  _assert_eq(facing_pick, "b", "an explicit facing must bypass the fresh_forward chain")
end

TestBoardDirectionSurvivor["test_入口门控 flag 矩阵：parity/entered_inner/skip 三闸各自独立生效"] = function(self)
  local _, map = _grid_board({ e = { 1, 1 }, o = { 1, 2 } }, {
    outer_next = { e = "o" },
    entry_points = { e = { inner_id = "i" } },
  })
  local cases = {
    { parity = 2, can_enter = true, skip = nil, expected = "i", entered = true, label = "even parity turns inner" },
    { parity = 3, can_enter = true, skip = nil, expected = "o", entered = false, label = "odd parity stays outer" },
    { parity = nil, can_enter = true, skip = nil, expected = "o", entered = false, label = "nil parity stays outer" },
    { parity = 2, can_enter = false, skip = nil, expected = "o", entered = false, label = "already-inner walk stays outer" },
    { parity = 2, can_enter = true, skip = "e", expected = "o", entered = false, label = "skip flag suppresses this entry" },
  }
  for _, case in ipairs(cases) do
    local next_id, entered = direction.resolve_forward_next_id(
      map, "e", map.neighbors.e, nil, case.parity, case.can_enter, case.skip)
    _assert_eq(next_id, case.expected, case.label)
    _assert_eq(entered, case.entered, case.label .. " (entered_inner flag)")
  end
end

TestBoardDirectionSurvivor["test_resolve_forward_facing：无邻接表时原样保持 facing"] = function(self)
  local _, map = _grid_board({ a = { 1, 1 }, b = { 1, 2 } })
  map.neighbors.a = nil
  local facing = direction.resolve_forward_facing(map, "a", "left", { parity = nil, entered_inner = false })
  _assert_eq(facing, "left", "missing neighbors should keep the incoming facing")
end

TestBoardDirectionSurvivor["test_resolve_forward_facing：正常路径返回真实几何朝向"] = function(self)
  local _, map = _grid_board({ a = { 1, 1 }, b = { 1, 2 } })
  local facing = direction.resolve_forward_facing(map, "a", "right", { parity = nil, entered_inner = false })
  _assert_eq(facing, "right", "facing should be map.direction of the resolved step")
end

TestBoardDirectionSurvivor["test_resolve_backward_next_source：四级来源逐级回落且标签准确"] = function(self)
  -- 1) facing 反向邻居
  local _, map = _grid_board({ m = { 2, 2 }, u = { 1, 2 } })
  local via_facing = direction.resolve_backward_next_source(map, "m", map.neighbors.m, "down")
  _assert_eq(via_facing.next_id, "u", "reverse of facing=down is the up neighbor")
  _assert_eq(via_facing.source, "facing_reverse_neighbor", "facing-reverse source label")
  -- 2) outer_prev
  local _, prev_map = _grid_board({ m = { 2, 2 } }, { outer_prev = { m = "p" } })
  local via_prev = direction.resolve_backward_next_source(prev_map, "m", prev_map.neighbors.m, nil)
  _assert_eq(via_prev.next_id, "p", "outer_prev should resolve when no facing reverse exists")
  _assert_eq(via_prev.source, "outer_prev", "outer_prev source label")
  -- 3) backward_fallback 映射
  local _, fb_map = _grid_board({ m = { 2, 2 } }, { backward_fallback = { m = "f" } })
  local via_fb = direction.resolve_backward_next_source(fb_map, "m", fb_map.neighbors.m, nil)
  _assert_eq(via_fb.next_id, "f", "backward_fallback map should resolve after outer_prev")
  _assert_eq(via_fb.source, "backward_fallback", "backward_fallback source label")
  -- 4) 邻居回落
  local _, n_map = _grid_board({ m = { 2, 2 }, r = { 2, 3 } })
  local via_neigh = direction.resolve_backward_next_source(n_map, "m", n_map.neighbors.m, nil)
  _assert_eq(via_neigh.next_id, "r", "neighbor fallback should pick the remaining neighbor")
  _assert_eq(via_neigh.source, "neighbor_fallback", "neighbor fallback source label")
  -- 5) 全部落空
  local _, empty_map = _grid_board({ m = { 2, 2 } })
  local dead = direction.resolve_backward_next_source(empty_map, "m", empty_map.neighbors.m, nil)
  _assert_eq(dead.next_id, nil, "no source should yield nil next")
  _assert_eq(dead.source, nil, "no source should yield nil label")
end

TestBoardDirectionSurvivor["test_normalize_forward_step_context：表直通,标量展开为精确字段"] = function(self)
  local ctx = { parity = 4, entered_inner = true, skip_entry_on_tile_id = "e" }
  lu.assertEvalToTrue(direction.normalize_forward_step_context(ctx) == ctx, "table context should pass through unchanged")
  local expanded = direction.normalize_forward_step_context(6)
  _assert_eq(expanded.parity, 6, "scalar parity should be preserved")
  _assert_eq(expanded.entered_inner, false, "scalar form starts outside the inner ring")
  _assert_eq(expanded.skip_entry_on_tile_id, nil, "scalar form has no skip entry")
end


return TestBoardDirectionSurvivor
