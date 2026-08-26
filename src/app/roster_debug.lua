local debug_flags = require("src.config.gameplay.debug_flags")

local M = {}

local function _add_debug_auto_player(auto_players, entry)
  if entry == nil or entry.role_id == nil then
    return auto_players
  end
  auto_players = auto_players or {}
  auto_players[entry.role_id] = true
  return auto_players
end

-- 起始席位：全托管联调开关打开时从 1 号位(真人)开始全席位托管,关闭则不建表。
local function _first_auto_slot()
  if debug_flags.debug_auto_all_roles == true then
    return 1
  end
  return nil
end

function M.build_auto_players(role_roster)
  local first_slot = _first_auto_slot()
  if first_slot == nil then
    return nil
  end
  local auto_players = nil
  for i = first_slot, #role_roster do
    auto_players = _add_debug_auto_player(auto_players, role_roster[i])
  end
  return auto_players
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=31bcca6eecf0c6d0
scope.0.id=chunk:src/app/roster_debug.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=35
scope.0.semanticHash=f197bc3ac5a0249b
scope.1.id=function:_add_debug_auto_player
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=12
scope.1.semanticHash=0e17d7909c99ea8c
scope.2.id=function:_first_auto_slot
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=20
scope.2.semanticHash=51da0d89916877c1
scope.3.id=function:M.build_auto_players
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=32
scope.3.semanticHash=eea9f953bd9506db
]]
