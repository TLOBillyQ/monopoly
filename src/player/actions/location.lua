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

local function _board_of(self)
  return self and self.board or nil
end

local function _tile_of(board, position)
  return board and board.get_tile and board:get_tile(position) or nil
end

local function _field(holder, key)
  return holder and holder[key] or nil
end

local function _emit_status_feedback(self, player, status_type, cue_name)
  local board = _board_of(self)
  local tile = _tile_of(board, player.position)
  monopoly_event.emit(monopoly_event.feedback.status_applied, {
    player = player,
    player_id = _field(player, "id"),
    status_type = status_type,
    cue_name = cue_name,
    tile_id = _field(tile, "id"),
    tile_index = _field(player, "position"),
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
  if self:player_cash(player) <= 0 then
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

local function _matches_normalized(player, normalized_id)
  return player ~= nil and role_id_utils.equals(player.id, normalized_id)
end

local function _find_normalized(self, normalized_id)
  for _, player in ipairs(self.players or {}) do
    if _matches_normalized(player, normalized_id) then
      return player
    end
  end
  return nil
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
  local player = _find_normalized(self, normalized_id)
  if player ~= nil then
    _cache_put(by_id, player_id, normalized_id, player)
    return player
  end
  return nil
end

function location_ops.current_player(self)
  local idx = self.turn.current_player_index
  assert(idx ~= nil, "missing current_player_index")
  return self.players[idx]
end

local function _remove_occurrences(list, player_id)
  for i = #list, 1, -1 do
    if list[i] == player_id then
      table.remove(list, i)
    end
  end
end

local function _remove_from_occupancy(self, player, old_index)
  if old_index and self.occupants and self.occupants[old_index] then
    _remove_occurrences(self.occupants[old_index], player.id)
  end
end

local function _add_to_occupancy(self, player, new_index)
  self.occupants[new_index] = self.occupants[new_index] or {}
  table.insert(self.occupants[new_index], player.id)
end

function location_ops.update_player_position(self, player, new_index)
  local old_index = player.position
  _remove_from_occupancy(self, player, old_index)
  player.position = new_index
  common.mark_players(self)
  _add_to_occupancy(self, player, new_index)
end

return location_ops

--[[ mutate4lua-manifest
version=4
projectHash=77ae7026f8a122d0
scope.0.id=chunk:src/player/actions/location.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=169
scope.0.semanticHash=244065170a520b4e
scope.1.id=function:_emit_status_feedback
scope.1.kind=function
scope.1.startLine=13
scope.1.endLine=24
scope.1.semanticHash=a18a7079bff144f8
scope.2.id=function:_resolve_required_index
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=28
scope.2.semanticHash=b7b33f178780652a
scope.3.id=function:_resolve_relocate_index
scope.3.kind=function
scope.3.startLine=30
scope.3.endLine=46
scope.3.semanticHash=9d6043c612608234
scope.4.id=function:<anonymous>
scope.4.kind=function
scope.4.startLine=36
scope.4.endLine=38
scope.4.semanticHash=8cafff996153f998
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=43
scope.5.semanticHash=8cafff996153f998
scope.6.id=function:location_ops.player_apply_hospital_effects
scope.6.kind=function
scope.6.startLine=48
scope.6.endLine=69
scope.6.semanticHash=572754b5f053e34b
scope.7.id=function:location_ops.player_apply_mountain_effects
scope.7.kind=function
scope.7.startLine=71
scope.7.endLine=81
scope.7.semanticHash=fa83a6c267036d55
scope.8.id=function:location_ops.player_apply_location_effect
scope.8.kind=function
scope.8.startLine=83
scope.8.endLine=91
scope.8.semanticHash=2b7f8a07560e8a33
scope.9.id=function:location_ops.player_relocate
scope.9.kind=function
scope.9.startLine=93
scope.9.endLine=99
scope.9.semanticHash=eeff3c3c47c1241b
scope.10.id=function:location_ops.player_is_in_mountain
scope.10.kind=function
scope.10.startLine=101
scope.10.endLine=105
scope.10.semanticHash=9003b88e3c339200
scope.11.id=function:location_ops.alive_players
scope.11.kind=function
scope.11.startLine=107
scope.11.endLine=115
scope.11.semanticHash=c2207303920af9d9
scope.12.id=function:_cache_put
scope.12.kind=function
scope.12.startLine=117
scope.12.endLine=121
scope.12.semanticHash=edfb7e84b16565b7
scope.13.id=function:_cache_get
scope.13.kind=function
scope.13.startLine=123
scope.13.endLine=126
scope.13.semanticHash=f1ac1b295347a2f5
scope.14.id=function:location_ops.find_player_by_id
scope.14.kind=function
scope.14.startLine=128
scope.14.endLine=144
scope.14.semanticHash=3a47ba970caeb33a
scope.15.id=function:location_ops.current_player
scope.15.kind=function
scope.15.startLine=146
scope.15.endLine=150
scope.15.semanticHash=1af8dfaa484825a7
scope.16.id=function:location_ops.update_player_position
scope.16.kind=function
scope.16.startLine=152
scope.16.endLine=166
scope.16.semanticHash=5a3a9038b5b68367
]]
