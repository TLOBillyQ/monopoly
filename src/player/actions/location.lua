local bankruptcy_port = require("src.rules.ports.bankruptcy")
local achievement_progress = require("src.rules.ports.achievement_progress")
local event_feed = require("src.rules.ports.event_feed")
local event_kinds = require("src.config.gameplay.event_kinds")
local facing_policy = require("src.rules.board.facing_policy")
local common = require("src.player.actions.state_common")
local number_utils = require("src.foundation.number")
local role_id_utils = require("src.foundation.identity")
local monopoly_event = require("src.foundation.events")

local location_ops = {}

local function _emit_status_feedback(self, player, status_type, cue_name)
  local board = self and self.board or nil
  local tile = board and board.get_tile and board:get_tile(player.position) or nil
  monopoly_event.emit(monopoly_event.feedback.status_applied, {
    player = player,
    player_id = player and player.id or nil,
    status_type = status_type,
    cue_name = cue_name,
    tile_id = tile and tile.id or nil,
    tile_index = player and player.position or nil,
  })
end

local function _resolve_required_index(value, resolve_fn, missing_label)
  return assert(resolve_fn(value), missing_label .. tostring(value))
end

local function _resolve_relocate_index(self, opts)
  opts = opts or {}
  if opts.destination_index ~= nil then
    return opts.destination_index
  end
  if opts.destination_tile_id ~= nil then
    return _resolve_required_index(opts.destination_tile_id, function(tile_id)
      return self.board:index_of_tile_id(tile_id)
    end, "missing destination tile index: ")
  end
  if opts.tile_type ~= nil then
    return _resolve_required_index(opts.tile_type, function(tile_type)
      return self.board:find_first_by_type(tile_type)
    end, "missing tile type: ")
  end
  error("missing relocation destination")
end

function location_ops.player_apply_hospital_effects(self, player)
  self:set_player_status(player, "pending_location_effect", nil)
  self:set_player_status(player, "stay_turns", common.constants.hospital_stay_turns)
  achievement_progress.location_effect(self, player, "hospital")
  local fee = common.constants.hospital_fee
  self:add_player_cash(player, -fee)
  event_feed.publish(self, {
    kind = event_kinds.medical_fee,
    text = player.name .. " 支付医药费 " .. number_utils.format_integer_part(fee),
    tip = true,
  })
  if self:player_balance(player, "金币") <= 0 then
    bankruptcy_port.eliminate(self, player, { reason = player.name .. " 支付医药费后破产" })
    return
  end
  _emit_status_feedback(self, player, "hospital", "hospital_shock")
  event_feed.publish(self, {
    kind = event_kinds.hospital_stay,
    text = player.name .. " 住院，需停留 " .. tostring(player.status.stay_turns) .. " 回合",
    tip = true,
  })
end

function location_ops.player_apply_mountain_effects(self, player)
  self:set_player_status(player, "pending_location_effect", nil)
  self:set_player_status(player, "stay_turns", common.constants.mountain_stay_turns)
  achievement_progress.location_effect(self, player, "mountain")
  _emit_status_feedback(self, player, "mountain", "mountain_stun")
  event_feed.publish(self, {
    kind = event_kinds.mountain_stay,
    text = player.name .. " 进入深山，停留 " .. tostring(player.status.stay_turns) .. " 回合",
    tip = true,
  })
end

function location_ops.player_apply_location_effect(self, player, effect)
  if effect == "hospital" then
    return self:player_apply_hospital_effects(player)
  end
  if effect == "mountain" then
    return self:player_apply_mountain_effects(player)
  end
  error("unknown location effect: " .. tostring(effect))
end

function location_ops.player_relocate(self, player, opts)
  opts = opts or {}
  local idx = _resolve_relocate_index(self, opts)
  self:update_player_position(player, idx)
  facing_policy.sync_move_dir_after_position_change(self, player, idx, opts.move_dir_mode or "forced_move")
  return idx, assert(self.board:get_tile(idx), "missing tile: " .. tostring(idx))
end

function location_ops.player_is_in_mountain(self, player)
  local tile = self.board:get_tile(player.position)
  assert(tile ~= nil, "missing tile at position: " .. tostring(player.position))
  return tile.type == "mountain"
end

function location_ops.alive_players(self)
  local alive = {}
  for _, player in ipairs(self.players) do
    if not player.eliminated then
      alive[#alive + 1] = player
    end
  end
  return alive
end

local function _cache_put(by_id, player_id, normalized_id, player)
  if type(by_id) ~= "table" then return end
  if normalized_id ~= nil then by_id[normalized_id] = player end
  by_id[player_id] = player
end

local function _cache_get(by_id, player_id, normalized_id)
  if type(by_id) ~= "table" then return nil end
  return by_id[player_id] or (normalized_id and (by_id[normalized_id] or by_id[tostring(normalized_id)]))
end

function location_ops.find_player_by_id(self, player_id)
  if player_id == nil then return nil end
  local normalized_id = role_id_utils.normalize(player_id)
  local by_id = self.player_by_id
  local cached = _cache_get(by_id, player_id, normalized_id)
  if cached then
    _cache_put(by_id, player_id, normalized_id, cached)
    return cached
  end
  for _, player in ipairs(self.players or {}) do
    if player and role_id_utils.equals(player.id, normalized_id) then
      _cache_put(by_id, player_id, normalized_id, player)
      return player
    end
  end
  return nil
end

function location_ops.current_player(self)
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

function location_ops.update_player_position(self, player, new_index)
  local old_index = player.position
  if old_index and self.occupants and self.occupants[old_index] then
    local list = self.occupants[old_index]
    for i = #list, 1, -1 do
      if list[i] == player.id then
        table.remove(list, i)
      end
    end
  end
  player.position = new_index
  common.mark_players(self)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

return location_ops

--[[ mutate4lua-manifest
version=2
projectHash=ece2ba76f8aa03a2
scope.0.id=chunk:src/player/actions/location.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=162
scope.0.semanticHash=72c404e5b230a01f
scope.1.id=function:_emit_status_feedback:12
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=23
scope.1.semanticHash=061ded2f92f6a308
scope.2.id=function:_resolve_relocate_index:25
scope.2.kind=function
scope.2.startLine=25
scope.2.endLine=41
scope.2.semanticHash=be044109e5245ef7
scope.3.id=function:location_ops.player_apply_hospital_effects:43
scope.3.kind=function
scope.3.startLine=43
scope.3.endLine=63
scope.3.semanticHash=f540d7ec1ffe1db8
scope.4.id=function:location_ops.player_apply_mountain_effects:65
scope.4.kind=function
scope.4.startLine=65
scope.4.endLine=74
scope.4.semanticHash=0be2e2d61c0fdf1f
scope.5.id=function:location_ops.player_apply_location_effect:76
scope.5.kind=function
scope.5.startLine=76
scope.5.endLine=84
scope.5.semanticHash=2341f03d3a976494
scope.6.id=function:location_ops.player_relocate:86
scope.6.kind=function
scope.6.startLine=86
scope.6.endLine=92
scope.6.semanticHash=06ba61f784cfc196
scope.7.id=function:location_ops.player_is_in_mountain:94
scope.7.kind=function
scope.7.startLine=94
scope.7.endLine=98
scope.7.semanticHash=a04d27166e5651dd
scope.8.id=function:_cache_put:110
scope.8.kind=function
scope.8.startLine=110
scope.8.endLine=114
scope.8.semanticHash=ddc3381feb66d620
scope.9.id=function:_cache_get:116
scope.9.kind=function
scope.9.startLine=116
scope.9.endLine=119
scope.9.semanticHash=ba0ce02e51b2fe8a
scope.10.id=function:location_ops.current_player:139
scope.10.kind=function
scope.10.startLine=139
scope.10.endLine=143
scope.10.semanticHash=4d194597d221d9b3
]]
