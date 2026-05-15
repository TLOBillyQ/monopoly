local common = require("src.player.actions.state_common")
local monopoly_event = require("src.foundation.events")
local item_config = require("src.rules.items.config")

local deity_ops = {}

local function _ensure_deity(player)
  local status = common.player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  return status.deity
end

function deity_ops.player_has_deity(_, player, name)
  local deity = player.status and player.status.deity
  if not deity then
    return false
  end
  return deity.type == name and deity.remaining > 0
end

function deity_ops.player_has_any_deity(_, player)
  local status = player.status
  if not status then
    return false
  end
  local d = status.deity
  if not d then
    return false
  end
  return d.type ~= nil and d.type ~= "" and (d.remaining or 0) > 0
end

function deity_ops.player_has_angel(self, player)
  return self:player_has_deity(player, "angel")
end

function deity_ops.angel_immune_to_item(self, player, item_id)
  assert(item_id ~= nil, "missing item_id")
  local cfg = item_config.cfg_by_id[item_id]
  if not (cfg and cfg.angel_immune) then
    return false
  end
  return self:player_has_deity(player, "angel")
end

function deity_ops.clear_player_deity(self, player)
  local deity = _ensure_deity(player)
  deity.type = ""
  deity.remaining = 0
  common.mark_players(self)
end

function deity_ops.set_player_deity(self, player, name, duration)
  assert(type(name) == "string" and name ~= "", "deity name must be non-empty string")
  if duration ~= nil then assert(duration > 0, "explicit duration must be positive") end
  local actual_duration = duration or player.deity_duration_turns
  local deity = _ensure_deity(player)
  deity.type = name
  -- +1 so the activation-turn tick brings remaining to actual_duration.
  deity.remaining = actual_duration + 1
  common.mark_players(self)
  monopoly_event.emit(monopoly_event.feedback.deity_applied, {
    player = player,
    player_id = player and player.id or nil,
    deity_type = name,
    remaining = actual_duration,
  })
end

function deity_ops.transfer_deity(self, src, dst)
  assert(src ~= nil and dst ~= nil, "missing src/dst")
  assert(src.id ~= dst.id, "cannot transfer to self")
  local src_deity = src.status and src.status.deity
  assert(src_deity and src_deity.type ~= "" and (src_deity.remaining or 0) > 0,
         "src has no effective deity")
  self._deity_transferring = true
  local ok, err = pcall(function()
    local dst_deity = _ensure_deity(dst)
    dst_deity.type = src_deity.type
    dst_deity.remaining = src_deity.remaining
    common.mark_players(self)
    monopoly_event.emit(monopoly_event.feedback.deity_applied, {
      player = dst,
      player_id = dst and dst.id or nil,
      deity_type = src_deity.type,
      remaining = src_deity.remaining,
    })
    self:clear_player_deity(src)
  end)
  self._deity_transferring = false
  if not ok then
    error("transfer_deity failed mid-flight: " .. tostring(err))
  end
  return true
end

function deity_ops.tick_player_deity(self, player)
  if player.eliminated then return end
  local deity = _ensure_deity(player)
  if deity.remaining <= 0 then
    return
  end
  deity.remaining = deity.remaining - 1
  if deity.remaining <= 0 then
    self:clear_player_deity(player)
    return
  end
  common.mark_players(self)
end

return deity_ops
