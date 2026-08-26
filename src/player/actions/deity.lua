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

local function _has_effective_deity(d)
  return d.type ~= nil and d.type ~= "" and (d.remaining or 0) > 0
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
  return _has_effective_deity(d)
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

local function _emit_deity_applied(player, name, actual_duration)
  monopoly_event.emit(monopoly_event.feedback.deity_applied, {
    player = player,
    player_id = player and player.id or nil,
    deity_type = name,
    remaining = actual_duration,
  })
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
  _emit_deity_applied(player, name, actual_duration)
end

local function _effective_source_deity(src)
  local src_deity = src.status and src.status.deity
  assert(src_deity and src_deity.type ~= "" and (src_deity.remaining or 0) > 0,
         "src has no effective deity")
  return src_deity
end

local function _copy_deity_to_player(self, dst, src_deity)
  local dst_deity = _ensure_deity(dst)
  -- 转移即续神(#529):不分 dst 同神/异神/无神,剩余回合一律重置满时长
  -- (+1 约定同 set_player_deity),不照抄 src 残余。
  local actual_duration = dst.deity_duration_turns
  dst_deity.type = src_deity.type
  dst_deity.remaining = actual_duration + 1
  common.mark_players(self)
  achievement_progress.deity_attached(self, dst, src_deity.type)
  _emit_deity_applied(dst, src_deity.type, actual_duration)
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
version=4
projectHash=bbbede775e29a8ae
scope.0.id=chunk:src/player/actions/deity.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=140
scope.0.semanticHash=05195919dad113b7
scope.1.id=function:_ensure_deity
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=12
scope.1.semanticHash=b1db058deb6676f8
scope.2.id=function:deity_ops.player_has_deity
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=20
scope.2.semanticHash=ba52501de033fa5c
scope.3.id=function:_has_effective_deity
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=166888d024a3bdd9
scope.4.id=function:deity_ops.player_has_any_deity
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=36
scope.4.semanticHash=ed1495287a7a47c2
scope.5.id=function:deity_ops.player_deity_type
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=44
scope.5.semanticHash=30071235f084c882
scope.6.id=function:deity_ops.player_has_angel
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=48
scope.6.semanticHash=372f4c35c0f783b0
scope.7.id=function:deity_ops.angel_immune_to_item
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=57
scope.7.semanticHash=8d9bb5dc3251fd3e
scope.8.id=function:deity_ops.clear_player_deity
scope.8.kind=function
scope.8.startLine=59
scope.8.endLine=64
scope.8.semanticHash=521c7888b624c699
scope.9.id=function:_emit_deity_applied
scope.9.kind=function
scope.9.startLine=66
scope.9.endLine=73
scope.9.semanticHash=7507571367efd949
scope.10.id=function:deity_ops.set_player_deity
scope.10.kind=function
scope.10.startLine=75
scope.10.endLine=86
scope.10.semanticHash=bda7611db0489bed
scope.11.id=function:_effective_source_deity
scope.11.kind=function
scope.11.startLine=88
scope.11.endLine=93
scope.11.semanticHash=92f660c73d986bf1
scope.12.id=function:_copy_deity_to_player
scope.12.kind=function
scope.12.startLine=95
scope.12.endLine=105
scope.12.semanticHash=240610ed6810e254
scope.13.id=function:_complete_deity_transfer
scope.13.kind=function
scope.13.startLine=107
scope.13.endLine=110
scope.13.semanticHash=d7d683ffd038e1f8
scope.14.id=function:deity_ops.transfer_deity
scope.14.kind=function
scope.14.startLine=112
scope.14.endLine=123
scope.14.semanticHash=984d9deec83512d8
scope.15.id=function:deity_ops.tick_player_deity
scope.15.kind=function
scope.15.startLine=125
scope.15.endLine=137
scope.15.semanticHash=3ff7f183a83ef42a
]]
