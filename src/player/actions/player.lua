local Class = require("src.foundation.class")
local control = require("src.player.control")
local player = Class("Player")

function player:init(attrs)
  assert(attrs ~= nil, "Player.new(attrs) requires attrs")
  local constants = attrs.constants
  assert(constants ~= nil, "Player.new(attrs) requires attrs.constants")

  self.id = attrs.id
  assert(attrs.name ~= nil, "Player.new(attrs) requires attrs.name")
  self.name = attrs.name
  self.role_id = attrs.role_id
  self.is_ai = attrs.is_ai
  control.initialize(self)
  -- 与托管状态同口径从 attrs 恢复：回放/断线重连/读档重建 player 时
  -- 不把「已弹过分享面板」静默重置回 false。
  self.auto_share_panel_shown = attrs.auto_share_panel_shown == true
  self._coin_role = attrs.coin_role
  self.position = attrs.start_index
  self.deity_duration_turns = attrs.deity_duration_turns
  self.status = {
    stay_turns = 0,
    own_turn_started_count = 0,
    deity = { type = "", remaining = 0 },
    pending_remote_dice = nil,
    pending_dice_multiplier = 1,
    pending_free_rent = false,
    pending_tax_free = false,
  }
  self.inventory = attrs.inventory
  self.properties = {}
  self.eliminated = false
end

return player

--[[ mutate4lua-manifest
version=4
projectHash=5711841194baf017
scope.0.id=chunk:src/player/actions/player.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=37
scope.0.semanticHash=61c37f8c3c08a1d8
scope.1.id=function:player:init
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=34
scope.1.semanticHash=9cae2a0610d9f269
]]
