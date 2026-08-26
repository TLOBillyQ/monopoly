-- 是否展示/调试日志、tip 文案构造、请求装配与入队,全部与时长/派发链解耦。
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local handlers = require("src.ui.render.anim.handlers")

local tip_chain = {}

local user_tip_whitelist = {
  monster = true,
  missile = true,
  item_target_player = true,
  teleport_effect = true,
  clear_obstacles = true,
}

local function _should_debug_log(anim)
  return anim
    and anim.kind ~= "roll"
    and logger.is_anim_debug_enabled()
    or false
end

local function _should_show_tip(anim)
  if not anim or anim.kind == "roll" then
    return false
  end
  if anim.tip_policy == "user" then
    return true
  end
  return user_tip_whitelist[anim.kind] == true
end

local function _to_fixed_duration(duration)
  local ok, as_fixed = pcall(math.tofixed, duration)
  if ok and as_fixed ~= nil then
    return as_fixed
  end
  return duration
end

local function _resolve_tip_duration(duration)
  if number_utils.is_numeric(duration) and math and math.tofixed then
    return _to_fixed_duration(duration)
  end
  return duration
end

local function _resolve_tip_text(state, anim)
  local should_show_tip = _should_show_tip(anim)
  local should_debug_log = _should_debug_log(anim)
  local tip_text = nil
  if should_show_tip or should_debug_log then
    tip_text = handlers.build_tip(state, anim)
  end
  return tip_text, should_show_tip, should_debug_log
end

local function _tip_request_field(anim, key)
  return anim and anim[key] or nil
end

local function _anim_kind(anim)
  return anim and anim.kind or nil
end

-- tip 的 source:显式 tip_source 优先,缺省时按 kind 组 action_anim.* 名。
local function _tip_source(anim)
  local source = anim and anim.tip_source or nil
  if source ~= nil then
    return source
  end
  return "action_anim." .. tostring(_anim_kind(anim) or "tip")
end

local function _build_tip_request(anim, tip_text, tip_duration)
  return {
    text = tip_text,
    duration = tip_duration,
    dedupe_key = _tip_request_field(anim, "dedupe_key"),
    blocks_inter_turn = anim and anim.blocks_inter_turn == true or false,
    source = _tip_source(anim),
    chain_key = _tip_request_field(anim, "chain_key"),
  }
end

local function _enqueue_tip_text(host_runtime, anim, tip_text, tip_duration)
  if not host_runtime then
    return
  end
  host_runtime.enqueue_tip(_build_tip_request(anim, tip_text, tip_duration))
end

local function _log_tip_debug(should_debug_log, has_tip, tip_text)
  if should_debug_log and has_tip then
    logger.info_unlimited("[ActionAnim]", tip_text)
  end
end

local function _emit_tip_text(host_runtime, anim, tip_text, should_show_tip, should_debug_log, tip_duration)
  local has_tip = tip_text ~= nil and tip_text ~= ""
  _log_tip_debug(should_debug_log, has_tip, tip_text)
  if should_show_tip and has_tip then
    _enqueue_tip_text(host_runtime, anim, tip_text, tip_duration)
  end
end

-- 播放期 tip 全链:时长定稿 → 文案/展示判定 → 调试日志 → 入队。
function tip_chain.emit(state, anim, host_runtime, duration)
  local tip_duration = _resolve_tip_duration(duration)
  local tip_text, should_show_tip, should_debug_log = _resolve_tip_text(state, anim)
  _emit_tip_text(host_runtime, anim, tip_text, should_show_tip, should_debug_log, tip_duration)
end

return tip_chain

--[[ mutate4lua-manifest
version=4
projectHash=a10b0d6ed1ccef9a
scope.0.id=chunk:src/ui/render/anim/tip_chain.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=115
scope.0.semanticHash=e5baa9e38dcb770a
scope.1.id=function:_should_debug_log
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=21
scope.1.semanticHash=724bcc8e932ae232
scope.2.id=function:_should_show_tip
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=31
scope.2.semanticHash=fbd4c629bb4c2faf
scope.3.id=function:_to_fixed_duration
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=39
scope.3.semanticHash=3bc30e9a355d9a95
scope.4.id=function:_resolve_tip_duration
scope.4.kind=function
scope.4.startLine=41
scope.4.endLine=46
scope.4.semanticHash=c3b3ee16a752c90c
scope.5.id=function:_resolve_tip_text
scope.5.kind=function
scope.5.startLine=48
scope.5.endLine=56
scope.5.semanticHash=767a316d1b335e96
scope.6.id=function:_tip_request_field
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=60
scope.6.semanticHash=cd6b189045fad21d
scope.7.id=function:_anim_kind
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=64
scope.7.semanticHash=616a2ca60599c94f
scope.8.id=function:_tip_source
scope.8.kind=function
scope.8.startLine=67
scope.8.endLine=73
scope.8.semanticHash=f402b68be1f25790
scope.9.id=function:_build_tip_request
scope.9.kind=function
scope.9.startLine=75
scope.9.endLine=84
scope.9.semanticHash=068aab3175918a9c
scope.10.id=function:_enqueue_tip_text
scope.10.kind=function
scope.10.startLine=86
scope.10.endLine=91
scope.10.semanticHash=efda54205b88e7e6
scope.11.id=function:_log_tip_debug
scope.11.kind=function
scope.11.startLine=93
scope.11.endLine=97
scope.11.semanticHash=d7bff9537918846f
scope.12.id=function:_emit_tip_text
scope.12.kind=function
scope.12.startLine=99
scope.12.endLine=105
scope.12.semanticHash=576a92abfe97608d
scope.13.id=function:tip_chain.emit
scope.13.kind=function
scope.13.startLine=108
scope.13.endLine=112
scope.13.semanticHash=066ad8898cdd5a2d
]]
