local bankruptcy_port = require("src.rules.ports.bankruptcy")
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

local function _resolve_relocate_index(self, opts)
  opts = opts or {}
  if opts.destination_index ~= nil then
    return opts.destination_index
  end
  if opts.destination_tile_id ~= nil then
    local idx = self.board:index_of_tile_id(opts.destination_tile_id)
    assert(idx ~= nil, "missing destination tile index: " .. tostring(opts.destination_tile_id))
    return idx
  end
  if opts.tile_type ~= nil then
    local idx = self.board:find_first_by_type(opts.tile_type)
    assert(idx ~= nil, "missing tile type: " .. tostring(opts.tile_type))
    return idx
  end
  error("missing relocation destination")
end

function location_ops.player_apply_hospital_effects(self, player)
  self:set_player_status(player, "pending_location_effect", nil)
  self:set_player_status(player, "stay_turns", common.constants.hospital_stay_turns)
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
