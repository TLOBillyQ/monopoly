local debug_flags = require("src.config.gameplay.debug_flags")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local registry = require("src.ui.render.anim.registry")
local handlers = require("src.ui.render.anim.handlers")
local default_handlers = require("src.ui.render.anim.defaults")
local host_runtime_bridge = require("src.ui.host_bridge")
local runtime_ui = require("src.ui.render.runtime_ui")
local effect_track = require("src.ui.render.support.effect_track")

local action_anim = {}

local function _timing_or(value, fallback)
  if value ~= nil then
    return value
  end
  return fallback
end

local durations = {
  missile = 1.2,
  monster = 1.2,
}
local start_delays = {
  missile = _timing_or(timing.demolish_effect_start_delay_seconds, 0.2),
  monster = _timing_or(timing.demolish_effect_start_delay_seconds, 0.2),
}
local user_tip_whitelist = {
  monster = true,
  missile = true,
  item_target_player = true,
  teleport_effect = true,
  clear_obstacles = true,
}

local function _resolve_runtime_bundle(state, opts)
  if opts and opts.runtime_bundle then
    return opts.runtime_bundle
  end
  if state and state.presentation_runtime then
    return state.presentation_runtime
  end
  return {
    runtime = runtime_ui,
    host_runtime = host_runtime_bridge,
    ui_events = {
      show = {},
      hide = {},
      send_to_all = function() end,
    },
  }
end

local function _should_debug_log(anim)
  return anim
    and anim.kind ~= "roll"
    and (logger.is_anim_debug_enabled() or debug_flags.action_anim_debug_log_enabled == true)
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

action_anim.clear_overlay = handlers.clear_overlay

local function _resolve_duration(anim)
  local default_duration = timing.action_anim_default_seconds or 1.0
  local base_duration = anim.duration or durations[anim.kind] or default_duration
  if base_duration <= 0 then
    base_duration = default_duration
  end
  local duration = effect_track.scaled_duration(base_duration)
  local start_delay = start_delays[anim.kind] or 0
  if start_delay > 0 then
    duration = duration + start_delay
  end
  return duration
end

local function _resolve_tip_duration(duration)
  local tip_duration = duration
  if number_utils.is_numeric(duration) and math and math.tofixed then
    local ok, as_fixed = pcall(math.tofixed, duration)
    if ok and as_fixed ~= nil then
      tip_duration = as_fixed
    end
  end
  return tip_duration
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

local function _enqueue_tip_text(host_runtime, anim, tip_text, tip_duration)
  if not host_runtime then
    return
  end
  host_runtime.enqueue_tip({
    text = tip_text,
    duration = tip_duration,
    dedupe_key = anim and anim.dedupe_key or nil,
    blocks_inter_turn = anim and anim.blocks_inter_turn == true or false,
    source = anim and anim.tip_source or ("action_anim." .. tostring(anim and anim.kind or "tip")),
    chain_key = anim and anim.chain_key or nil,
  })
end

local function _emit_tip_text(host_runtime, anim, tip_text, should_show_tip, should_debug_log, tip_duration)
  local has_tip = tip_text ~= nil and tip_text ~= ""
  if should_debug_log and has_tip then
    logger.info_unlimited("[ActionAnim]", tip_text)
  end
  if should_show_tip and has_tip then
    _enqueue_tip_text(host_runtime, anim, tip_text, tip_duration)
  end
end

local function _build_handler_opts(state, runtime_bundle, host_runtime)
  local camera_sync = runtime_bundle and runtime_bundle.camera_sync or nil
  return {
    runtime = runtime_bundle.runtime,
    ui_events = runtime_bundle.ui_events,
    schedule = host_runtime and host_runtime.schedule or nil,
    runtime_bundle = runtime_bundle,
    show_tip = function(text, duration_seconds)
      if host_runtime then
        return host_runtime.enqueue_tip({
          text = text,
          duration = duration_seconds,
          blocks_inter_turn = false,
          source = "action_anim.handler",
        })
      end
    end,
    hold_seconds = default_handlers.roll_face_hold_seconds(),
    clear_overlay = action_anim.clear_overlay,
    pan_camera_to_position = camera_sync and camera_sync.pan_camera_to_position or nil,
    release_target_pan = camera_sync and camera_sync.release_target_pan or nil,
  }
end

function action_anim.play(state, anim, opts)
  assert(anim ~= nil, "missing anim")
  assert(state ~= nil, "missing state")
  default_handlers.register()
  local runtime_bundle = _resolve_runtime_bundle(state, opts)
  local host_runtime = runtime_bundle.host_runtime
  local duration = _resolve_duration(anim)
  local handler = registry.resolve(anim.kind)
  local tip_duration = _resolve_tip_duration(duration)
  local tip_text, should_show_tip, should_debug_log = _resolve_tip_text(state, anim)
  _emit_tip_text(host_runtime, anim, tip_text, should_show_tip, should_debug_log, tip_duration)
  if handler then
    local start_delay = start_delays[anim.kind] or 0
    if start_delay > 0 and host_runtime and type(host_runtime.schedule) == "function" then
      host_runtime.schedule(start_delay, function()
        handler(state, anim, duration, _build_handler_opts(state, runtime_bundle, host_runtime))
      end)
      return duration
    end
    return handler(state, anim, duration, _build_handler_opts(state, runtime_bundle, host_runtime))
  end
  return duration
end

return action_anim

--[[ mutate4lua-manifest
version=2
projectHash=5cebf7a46d9e6586
scope.0.id=chunk:src/ui/render/anim/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=182
scope.0.semanticHash=0cc59b97900116c4
scope.1.id=function:_timing_or:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=19
scope.1.semanticHash=005c2a059dee8dc2
scope.2.id=function:anonymous@50:50
scope.2.kind=function
scope.2.startLine=50
scope.2.endLine=50
scope.2.semanticHash=b53995942fd14a6f
scope.3.id=function:_resolve_runtime_bundle:37
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=53
scope.3.semanticHash=5450ac5ec9bd136a
scope.4.id=function:_should_debug_log:55
scope.4.kind=function
scope.4.startLine=55
scope.4.endLine=60
scope.4.semanticHash=d650d8a1119f5c3e
scope.5.id=function:_should_show_tip:62
scope.5.kind=function
scope.5.startLine=62
scope.5.endLine=70
scope.5.semanticHash=9abd8bc9a1c9ae08
scope.6.id=function:_resolve_duration:74
scope.6.kind=function
scope.6.startLine=74
scope.6.endLine=86
scope.6.semanticHash=8f65913805d0c67f
scope.7.id=function:_resolve_tip_duration:88
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=97
scope.7.semanticHash=7ad5f7827fafd649
scope.8.id=function:_resolve_tip_text:99
scope.8.kind=function
scope.8.startLine=99
scope.8.endLine=107
scope.8.semanticHash=1db1159fb082b81d
scope.9.id=function:_enqueue_tip_text:109
scope.9.kind=function
scope.9.startLine=109
scope.9.endLine=121
scope.9.semanticHash=996554b0a9260508
scope.10.id=function:_emit_tip_text:123
scope.10.kind=function
scope.10.startLine=123
scope.10.endLine=131
scope.10.semanticHash=d4b42609032e4cca
scope.11.id=function:anonymous@140:140
scope.11.kind=function
scope.11.startLine=140
scope.11.endLine=149
scope.11.semanticHash=754086f2b4cc2ffb
scope.12.id=function:_build_handler_opts:133
scope.12.kind=function
scope.12.startLine=133
scope.12.endLine=155
scope.12.semanticHash=55f0cf7b5a909aff
scope.13.id=function:anonymous@171:171
scope.13.kind=function
scope.13.startLine=171
scope.13.endLine=173
scope.13.semanticHash=d5a3111b23d3e96d
scope.14.id=function:action_anim.play:157
scope.14.kind=function
scope.14.startLine=157
scope.14.endLine=179
scope.14.semanticHash=843aceeed0178802
]]
