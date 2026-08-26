local lu = require("luaunit")
local board = require("src.rules.board.init")
local _config_reset = require("test.support.config_reset")

-- 原生 LuaUnit 迁移:describe/it 拍平为文件级 TestBoardDirectionUtils 类,
-- before_each → setUp,断言切到 lu.assertXxx,用例数与改写前一一对应(7 例)。

local _pick_any_dir = board._M_test._pick_any_dir

local function _assert_eq(a, b, msg)
  lu.assertEquals(a, b, msg)
end

TestBoardDirectionUtils = {}

function TestBoardDirectionUtils:setUp()
  _config_reset.reset_all()
end

function TestBoardDirectionUtils:test_pick_any_dir_all_four_dirs_no_avoid()
  local neigh = { up = 1, right = 2, down = 3, left = 4 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "up", "all dirs: picks up (highest priority)")
  _assert_eq(id, 1, "all dirs: returns correct neighbor id")
end

function TestBoardDirectionUtils:test_pick_any_dir_avoid_up_picks_right()
  local neigh = { up = 1, right = 2, down = 3, left = 4 }
  local dir, id = _pick_any_dir(neigh, "up")
  _assert_eq(dir, "right", "avoid up: should pick right")
  _assert_eq(id, 2, "avoid up: correct id for right")
end

function TestBoardDirectionUtils:test_pick_any_dir_avoid_right_picks_up()
  local neigh = { up = 10, right = 20 }
  local dir, id = _pick_any_dir(neigh, "right")
  _assert_eq(dir, "up", "avoid right: should pick up")
  _assert_eq(id, 10, "avoid right: correct id")
end

function TestBoardDirectionUtils:test_pick_any_dir_only_left_no_avoid()
  local neigh = { left = 99 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "left", "only left: picks left")
  _assert_eq(id, 99, "only left: correct id")
end

function TestBoardDirectionUtils:test_pick_any_dir_only_left_avoid_left_returns_nil()
  local neigh = { left = 99 }
  local dir, id = _pick_any_dir(neigh, "left")
  _assert_eq(dir, nil, "avoid only dir: returns nil dir")
  _assert_eq(id, nil, "avoid only dir: returns nil id")
end

function TestBoardDirectionUtils:test_pick_any_dir_down_vs_left_picks_down()
  local neigh = { down = 30, left = 40 }
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, "down", "down vs left: picks down (priority 3 < 4)")
  _assert_eq(id, 30, "down vs left: correct id")
end

function TestBoardDirectionUtils:test_pick_any_dir_empty_neigh_returns_nil()
  local neigh = {}
  local dir, id = _pick_any_dir(neigh, nil)
  _assert_eq(dir, nil, "empty neigh: returns nil dir")
  _assert_eq(id, nil, "empty neigh: returns nil id")
end


return TestBoardDirectionUtils
