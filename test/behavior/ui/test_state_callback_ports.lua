-- src/ui/ports/callbacks.lua 的棋盘回调桥行为规约。首跑变异里
-- require(render.board) → nil 与 sync_many 转发返回值两个突变幸存,
-- 说明三个棋盘回调从未被测试真正调用、sync 结果也没人断言。
local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local _with_patches = support.with_patches

local callbacks_ports = require("src.ui.ports.callbacks")
local board_view = require("src.ui.render.board")

-- 原生 LuaUnit(推翻自研 busted 兼容运行器决策的迁移):describe/it 拍平为文件级 Test* 类,
-- 无钩子不拆类,中文用例名按原名逐字保留为方括号方法键,
-- 用例数与改写前一一对应(2 例);断言走 _assert_eq 共享辅助 + lu.assertNotNil。
TestStateCallbackPorts = {}

TestStateCallbackPorts["test_on_board_visual_sync 转发载荷并把 board 的同步结果原样返回"] = function(self)
  local seen = nil
  local state = {}
  local payload = { tiles = { 1, 2 } }

  _with_patches({
    { target = board_view, key = "sync_many", value = function(s, p)
      seen = { state = s, payload = p }
      return 3
    end },
  }, function()
    callbacks_ports.install(state, function() return nil end)
    local result = state:on_board_visual_sync(payload)
    _assert_eq(result, 3, "the board sync result must propagate through the callback")
  end)

  lu.assertNotNil(seen, "on_board_visual_sync must reach board_view.sync_many")
  _assert_eq(seen.state, state, "sync must forward the state handle")
  _assert_eq(seen.payload, payload, "sync must forward the payload untouched")
end

TestStateCallbackPorts["test_地块升级 / 易主回调带实参抵达棋盘渲染层"] = function(self)
  local upgraded = nil
  local owner_changed = nil
  local state = {}

  _with_patches({
    { target = board_view, key = "on_tile_upgraded", value = function(s, tile_id, level)
      upgraded = { state = s, tile_id = tile_id, level = level }
    end },
    { target = board_view, key = "on_tile_owner_changed", value = function(s, tile_id, owner_id)
      owner_changed = { state = s, tile_id = tile_id, owner_id = owner_id }
    end },
  }, function()
    callbacks_ports.install(state, function() return nil end)
    state:on_tile_upgraded(5, 2)
    state:on_tile_owner_changed(7, 1)
  end)

  lu.assertNotNil(upgraded, "on_tile_upgraded must reach the board renderer")
  _assert_eq(upgraded.state, state, "tile upgrade must forward the state handle")
  _assert_eq(upgraded.tile_id, 5, "tile upgrade must forward the tile id")
  _assert_eq(upgraded.level, 2, "tile upgrade must forward the level")
  lu.assertNotNil(owner_changed, "on_tile_owner_changed must reach the board renderer")
  _assert_eq(owner_changed.tile_id, 7, "owner change must forward the tile id")
  _assert_eq(owner_changed.owner_id, 1, "owner change must forward the owner id")
end

-- 地块升级回调的真实实现(不 patch on_tile_upgraded):走棋盘 events 的
-- _sync_single_tile 同步单块地。
TestStateCallbackPorts["test_地块升级回调真实同步单块地"] = function(self)
  local visual_sync = require("src.ui.render.board.visual_sync")
  local synced = nil
  local state = {}

  _with_patches({
    { target = visual_sync, key = "sync_many", value = function(s, payload)
      synced = payload
      return true
    end },
  }, function()
    callbacks_ports.install(state, function() return nil end)
    state:on_tile_upgraded(5, 2)
  end)

  lu.assertNotNil(synced, "on_tile_upgraded must reach board events sync")
  _assert_eq(synced.tile_ids[1], 5, "sync payload should carry the upgraded tile id")
end


return TestStateCallbackPorts
