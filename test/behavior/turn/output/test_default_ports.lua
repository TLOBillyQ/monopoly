-- #293 批3 pin:src/turn/output/default_ports.lua 的两个委托位点
-- (pick_remote_dice_value / pick_roadblock_target)无既有直测,调用换 nil
-- 变异体存活。桩 agent 模块同表函数,端口必须把返回值原样透出。

local lu = require("luaunit")
local default_ports = require("src.turn.output.default_ports")
local agent = require("src.computer.agent")

local original_pick_remote = agent.pick_remote_dice_value
local original_pick_roadblock = agent.pick_roadblock_target

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

TestDefaultPorts = {}

function TestDefaultPorts:tearDown()
  agent.pick_remote_dice_value = original_pick_remote
  agent.pick_roadblock_target = original_pick_roadblock
end

function TestDefaultPorts:test_auto_play_port_delegates_remote_dice_value()
  -- L22 `agent.pick_remote_dice_value(game, player, dice_count)` 换 nil:
  -- 端口必须透出 agent 的返回值。
  agent.pick_remote_dice_value = function(g, p, c)
    return "dice_7"
  end
  local game = default_ports.resolve_game_opts({})
  lu.assertEvalToTrue(type(game.auto_play_port) == "table", "default ports must install auto_play_port")
  local result = game.auto_play_port.pick_remote_dice_value({}, "p1", 2)
  _assert_eq(result, "dice_7", "remote dice value must delegate to the agent")
end

function TestDefaultPorts:test_auto_play_port_delegates_roadblock_target()
  -- L25 `agent.pick_roadblock_target(game, player)` 换 nil:
  -- 端口必须透出 agent 的返回值。
  agent.pick_roadblock_target = function(g, p)
    return 5
  end
  local game = default_ports.resolve_game_opts({})
  local result = game.auto_play_port.pick_roadblock_target({}, "p1")
  _assert_eq(result, 5, "roadblock target must delegate to the agent")
end

function TestDefaultPorts:test_install_keeps_existing_ports()
  -- 既有端口表必须原样保留(不重建)。
  local existing = { marker = true }
  local game = default_ports.install({ auto_play_port = existing })
  lu.assertEvalToTrue(game.auto_play_port == existing, "existing port table must be kept")
end

return TestDefaultPorts
