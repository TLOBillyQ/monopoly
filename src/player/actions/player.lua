require "vendor.third_party.ClassUtils"
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
  self.auto = attrs.auto
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
version=2
projectHash=ca715b55b99a58d4
scope.0.id=chunk:src/player/actions/player.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=33
scope.0.semanticHash=b4678ca55874bb49
scope.1.id=function:player:init:4
scope.1.kind=function
scope.1.startLine=4
scope.1.endLine=30
scope.1.semanticHash=1880ef31c3f23de7
]]
