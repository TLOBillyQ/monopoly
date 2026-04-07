local common = require("src.player.actions.state_ops.common")
local monopoly_event = require("src.core.events")

local deity_ops = {}

function deity_ops.player_has_deity(_self, player, name)
  local deity = player.status and player.status.deity
  if not deity then
    return false
  end
  return deity.type == name and deity.remaining > 0
end

function deity_ops.player_has_angel(self, player)
  return self:player_has_deity(player, "angel")
end

function deity_ops.clear_player_deity(self, player)
  local status = common.player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = ""
  status.deity.remaining = 0
  common.mark_players(self)
end

function deity_ops.set_player_deity(self, player, name, duration)
  assert(name ~= nil, "missing deity name")
  local status = common.player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  status.deity.type = name
  status.deity.remaining = duration or player.deity_duration_turns
  common.mark_players(self)
  monopoly_event.emit(monopoly_event.feedback.deity_applied, {
    player = player,
    player_id = player and player.id or nil,
    deity_type = name,
    remaining = status.deity.remaining,
  })
end

function deity_ops.tick_player_deity(self, player)
  local status = common.player_status_table(player)
  status.deity = status.deity or { type = "", remaining = 0 }
  local deity = status.deity
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
