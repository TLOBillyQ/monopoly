-- turn 输出侧的玩家控制快照:UI 不依赖玩家领域模块,只消费本模块物化的
-- 不可变布尔快照。字段至少包含 is_delegated 与 is_computer_controlled;
-- 每次 build 返回全新的 map 与条目,调用方不得改写快照内容。
local control = require("src.player.control")
local identity = require("src.foundation.identity")

local snapshot = {}

local function _freeze(value)
  return setmetatable({}, {
    __index = value,
    __newindex = function()
      error("player control snapshot is immutable", 2)
    end,
    __pairs = function()
      return pairs(value)
    end,
    __len = function()
      return #value
    end,
  })
end

local function _entry(player)
  return _freeze({
    is_delegated = control.is_delegated(player),
    is_computer_controlled = control.is_computer_controlled(player),
  })
end

-- 单条落表(CRAP 门禁):归一化与空 id 跳过收敛到本函数,build 只留遍历。
local function _write_entry(by_player, player)
  local player_id = identity.normalize(player and player.id or nil)
  if player_id == nil then
    return
  end
  identity.write(by_player, player_id, _entry(player))
end

function snapshot.build(game)
  local by_player = {}
  for _, player in ipairs(game and game.players or {}) do
    _write_entry(by_player, player)
  end
  return _freeze(by_player)
end

function snapshot.install(game)
  local by_player = snapshot.build(game)
  if game ~= nil then
    game.player_control_snapshots = by_player
  end
  return by_player
end

function snapshot.find(game, role_id)
  local by_player = game and game.player_control_snapshots or nil
  if by_player == nil then
    return nil
  end
  return identity.read(by_player, identity.normalize(role_id))
end

return snapshot

--[[ mutate4lua-manifest
version=4
projectHash=0b1edebe03af12fd
scope.0.id=chunk:src/turn/output/player_control_snapshot.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=65
scope.0.semanticHash=9b4c77976f7d6a9d
scope.1.id=function:_freeze
scope.1.kind=function
scope.1.startLine=9
scope.1.endLine=22
scope.1.semanticHash=a7dacda791062610
scope.2.id=function:<anonymous>
scope.2.kind=function
scope.2.startLine=12
scope.2.endLine=14
scope.2.semanticHash=a93e0e24b98e0fe8
scope.3.id=function:<anonymous>#2
scope.3.kind=function
scope.3.startLine=15
scope.3.endLine=17
scope.3.semanticHash=7bbf31ab6751de78
scope.4.id=function:<anonymous>#3
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=20
scope.4.semanticHash=740726d371eb97be
scope.5.id=function:_entry
scope.5.kind=function
scope.5.startLine=24
scope.5.endLine=29
scope.5.semanticHash=8acafa9379eb38af
scope.6.id=function:_write_entry
scope.6.kind=function
scope.6.startLine=32
scope.6.endLine=38
scope.6.semanticHash=49ece1ca07112eaf
scope.7.id=function:snapshot.build
scope.7.kind=function
scope.7.startLine=40
scope.7.endLine=46
scope.7.semanticHash=3830bff04b2111dd
scope.8.id=function:snapshot.install
scope.8.kind=function
scope.8.startLine=48
scope.8.endLine=54
scope.8.semanticHash=cede65a82deb79bb
scope.9.id=function:snapshot.find
scope.9.kind=function
scope.9.startLine=56
scope.9.endLine=62
scope.9.semanticHash=a30405993db01141
]]
