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

-- 只读当前生效的神明类型；无生效神明返回 nil（供展示/文案，不暴露存储布局）。
function deity_ops.player_deity_type(self, player)
  if not self:player_has_any_deity(player) then
    return nil
  end
  return player.status.deity.type
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
projectHash=21822ef402f66caa
scope.0.id=chunk:src/player/actions/deity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=126
scope.0.semanticHash=6f0881107588b570
scope.0.lastMutatedAt=2026-07-07T04:13:45Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=4
scope.0.lastMutationKilled=4
scope.1.id=function:_ensure_deity:8
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=12
scope.1.semanticHash=54225dd8b4cb3dd6
scope.1.lastMutatedAt=2026-07-07T04:13:45Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=4
scope.1.lastMutationKilled=4
scope.2.id=function:deity_ops.player_has_deity:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=20
scope.2.semanticHash=6ad788a2a4064563
scope.2.lastMutatedAt=2026-07-07T04:13:45Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=7
scope.2.lastMutationKilled=7
scope.3.id=function:deity_ops.player_has_any_deity:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=32
scope.3.semanticHash=eaa7163824ec53a9
scope.3.lastMutatedAt=2026-07-07T04:13:45Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=13
scope.3.lastMutationKilled=13
scope.4.id=function:deity_ops.player_has_angel:34
scope.4.kind=function
scope.4.startLine=34
scope.4.endLine=36
scope.4.semanticHash=a13b99263db3cbf1
scope.4.lastMutatedAt=2026-07-07T04:13:45Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:deity_ops.angel_immune_to_item:38
scope.5.kind=function
scope.5.startLine=38
scope.5.endLine=45
scope.5.semanticHash=6b31c368b15e61e7
scope.5.lastMutatedAt=2026-07-07T04:13:45Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=5
scope.5.lastMutationKilled=5
scope.6.id=function:deity_ops.clear_player_deity:47
scope.6.kind=function
scope.6.startLine=47
scope.6.endLine=52
scope.6.semanticHash=c3213fb0a88953e5
scope.6.lastMutatedAt=2026-07-07T04:13:45Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=4
scope.6.lastMutationKilled=4
scope.7.id=function:deity_ops.set_player_deity:54
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=70
scope.7.semanticHash=2f9ce54c0e5539c8
scope.7.lastMutatedAt=2026-07-07T04:13:45Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=10
scope.7.lastMutationKilled=10
scope.8.id=function:_effective_source_deity:72
scope.8.kind=function
scope.8.startLine=72
scope.8.endLine=77
scope.8.semanticHash=8c707246e8f223fe
scope.8.lastMutatedAt=2026-07-07T04:13:45Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=2
scope.8.lastMutationKilled=2
scope.9.id=function:_copy_deity_to_player:79
scope.9.kind=function
scope.9.startLine=79
scope.9.endLine=91
scope.9.semanticHash=4469784e4cab0fcc
scope.9.lastMutatedAt=2026-07-07T04:13:45Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=4
scope.9.lastMutationKilled=4
scope.10.id=function:_complete_deity_transfer:93
scope.10.kind=function
scope.10.startLine=93
scope.10.endLine=96
scope.10.semanticHash=ea603d15c2ce5b40
scope.10.lastMutatedAt=2026-07-07T04:13:45Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=2
scope.10.lastMutationKilled=2
scope.11.id=function:deity_ops.transfer_deity:98
scope.11.kind=function
scope.11.startLine=98
scope.11.endLine=109
scope.11.semanticHash=6489218e70f131a1
scope.11.lastMutatedAt=2026-07-07T04:13:45Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=9
scope.11.lastMutationKilled=9
scope.12.id=function:deity_ops.tick_player_deity:111
scope.12.kind=function
scope.12.startLine=111
scope.12.endLine=123
scope.12.semanticHash=2cc1107b782e14bd
scope.12.lastMutatedAt=2026-07-07T04:13:45Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=9
scope.12.lastMutationKilled=9
]]
