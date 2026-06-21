local common = require("src.player.actions.state_common")
local achievement_progress = require("src.rules.ports.achievement_progress")
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
  achievement_progress.deity_attached(self, player, name)
  monopoly_event.emit(monopoly_event.feedback.deity_applied, {
    player = player,
    player_id = player and player.id or nil,
    deity_type = name,
    remaining = actual_duration,
  })
end

local function _effective_source_deity(src)
  local src_deity = src.status and src.status.deity
  assert(src_deity and src_deity.type ~= "" and (src_deity.remaining or 0) > 0,
         "src has no effective deity")
  return src_deity
end

local function _copy_deity_to_player(self, dst, src_deity)
  local dst_deity = _ensure_deity(dst)
  dst_deity.type = src_deity.type
  dst_deity.remaining = src_deity.remaining
  common.mark_players(self)
  achievement_progress.deity_attached(self, dst, src_deity.type)
  monopoly_event.emit(monopoly_event.feedback.deity_applied, {
    player = dst,
    player_id = dst and dst.id or nil,
    deity_type = src_deity.type,
    remaining = src_deity.remaining,
  })
end

local function _complete_deity_transfer(self, src, dst, src_deity)
  _copy_deity_to_player(self, dst, src_deity)
  self:clear_player_deity(src)
end

function deity_ops.transfer_deity(self, src, dst)
  assert(src ~= nil and dst ~= nil, "missing src/dst")
  assert(src.id ~= dst.id, "cannot transfer to self")
  local src_deity = _effective_source_deity(src)
  self._deity_transferring = true
  local ok, err = pcall(_complete_deity_transfer, self, src, dst, src_deity)
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

--[[ mutate4lua-manifest
version=2
projectHash=99ed096324e01e9c
scope.0.id=chunk:src/player/actions/deity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=112
scope.0.semanticHash=9aee5c1d6d9596b3
scope.1.id=function:_ensure_deity:7
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=11
scope.1.semanticHash=54225dd8b4cb3dd6
scope.2.id=function:deity_ops.player_has_deity:13
scope.2.kind=function
scope.2.startLine=13
scope.2.endLine=19
scope.2.semanticHash=6ad788a2a4064563
scope.3.id=function:deity_ops.player_has_any_deity:21
scope.3.kind=function
scope.3.startLine=21
scope.3.endLine=31
scope.3.semanticHash=eaa7163824ec53a9
scope.4.id=function:deity_ops.player_has_angel:33
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=35
scope.4.semanticHash=a13b99263db3cbf1
scope.5.id=function:deity_ops.angel_immune_to_item:37
scope.5.kind=function
scope.5.startLine=37
scope.5.endLine=44
scope.5.semanticHash=6b31c368b15e61e7
scope.6.id=function:deity_ops.clear_player_deity:46
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=51
scope.6.semanticHash=c3213fb0a88953e5
scope.7.id=function:deity_ops.set_player_deity:53
scope.7.kind=function
scope.7.startLine=53
scope.7.endLine=68
scope.7.semanticHash=f1f7fefeaf328c26
scope.8.id=function:anonymous@77:77
scope.8.kind=function
scope.8.startLine=77
scope.8.endLine=89
scope.8.semanticHash=8f5dd039d20942b0
scope.9.id=function:deity_ops.transfer_deity:70
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=95
scope.9.semanticHash=3d2e5570b9faaf2b
scope.10.id=function:deity_ops.tick_player_deity:97
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=109
scope.10.semanticHash=2cc1107b782e14bd
]]
