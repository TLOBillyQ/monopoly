local debug_flags = require("src.config.gameplay.debug_flags")
local timing = require("src.config.gameplay.timing")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.foundation.number")
local logger = require("src.foundation.log")
local registry = require("src.ui.render.anim.registry")
local handlers = require("src.ui.render.anim.handlers")
local board_feedback = require("src.ui.render.board_feedback.service")
local dice_nodes = require("src.ui.schema.dice")
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
local roll_spin_seconds = _timing_or(timing.dice_spin_seconds, 1.0)
local roll_face_hold_seconds = _timing_or(timing.dice_face_hold_seconds, 1.0)

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

local function _ensure_move_effect_direction(anim)
  if anim.direction or anim.steps then
    return anim
  end
  local patched = {}
  for key, value in pairs(anim) do
    patched[key] = value
  end
  patched.direction = runtime_constants.v3_left
  return patched
end

local function _void_delegate(method_name)
  return function(state, anim, duration, opts)
    handlers[method_name](state, anim, duration, opts)
    return duration
  end
end

local function _return_delegate(method_name)
  return function(state, anim, duration, opts)
    return handlers[method_name](state, anim, duration, opts)
  end
end

local function _register_default_handlers()
  if registry.resolve("roll") then
    return
  end
  registry.register("roll", function(state, anim, duration, opts)
    handlers.play_roll_dice_screen(state, anim, roll_spin_seconds, roll_face_hold_seconds, {
      runtime = opts and opts.runtime,
      ui_events = opts and opts.ui_events,
      schedule = opts and opts.schedule,
      dice_screen_nodes = dice_nodes,
    })
    return roll_spin_seconds + roll_face_hold_seconds
  end)
  registry.register("roadblock", _void_delegate("play_overlay"))
  registry.register("mine", _void_delegate("play_overlay"))
  registry.register("move_effect", function(state, anim)
    return handlers.play_move_effect(state, _ensure_move_effect_direction(anim))
  end)
  registry.register("teleport_effect", _return_delegate("play_teleport_effect"))
  registry.register("forced_relocation", _return_delegate("play_forced_relocation"))
  registry.register("mine_trigger", _return_delegate("play_mine_trigger"))
  registry.register("roadblock_trigger", _return_delegate("play_roadblock_trigger"))
  registry.register("upgrade_land", function(state, anim, duration, opts)
    board_feedback.play_tile_cue(state, "upgrade_land_smoke", anim.tile_index, {
      player_id = anim.player_id,
      duration = duration,
      use_building_tile_position = true,
    }, opts and opts.runtime_bundle)
    return duration
  end)
  registry.register("cash_receive", function(state, anim, duration, opts)
    board_feedback.play_player_cue(state, "cash_burst", anim.player_id, {
      duration = duration,
      amount = anim.amount,
    }, opts and opts.runtime_bundle)
    return duration
  end)
  registry.register("missile", _void_delegate("play_missile"))
  registry.register("monster", _void_delegate("play_monster"))
  registry.register("clear_obstacles", _void_delegate("play_clear_obstacles"))
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
    hold_seconds = roll_face_hold_seconds,
    clear_overlay = action_anim.clear_overlay,
    pan_camera_to_position = camera_sync and camera_sync.pan_camera_to_position or nil,
    release_target_pan = camera_sync and camera_sync.release_target_pan or nil,
  }
end

function action_anim.play(state, anim, opts)
  assert(anim ~= nil, "missing anim")
  assert(state ~= nil, "missing state")
  _register_default_handlers()
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
projectHash=9f792772b28884e4
scope.0.id=chunk:src/ui/render/anim/init.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=253
scope.0.semanticHash=7e1fa7119c0cb48e
scope.1.id=function:_timing_or:16
scope.1.kind=function
scope.1.startLine=16
scope.1.endLine=21
scope.1.semanticHash=005c2a059dee8dc2
scope.2.id=function:anonymous@54:54
scope.2.kind=function
scope.2.startLine=54
scope.2.endLine=54
scope.2.semanticHash=b53995942fd14a6f
scope.3.id=function:_resolve_runtime_bundle:41
scope.3.kind=function
scope.3.startLine=41
scope.3.endLine=57
scope.3.semanticHash=5450ac5ec9bd136a
scope.4.id=function:_should_debug_log:59
scope.4.kind=function
scope.4.startLine=59
scope.4.endLine=64
scope.4.semanticHash=d650d8a1119f5c3e
scope.5.id=function:_should_show_tip:66
scope.5.kind=function
scope.5.startLine=66
scope.5.endLine=74
scope.5.semanticHash=9abd8bc9a1c9ae08
scope.6.id=function:anonymous@89:89
scope.6.kind=function
scope.6.startLine=89
scope.6.endLine=92
scope.6.semanticHash=09e78a872db0caa2
scope.7.id=function:_void_delegate:88
scope.7.kind=function
scope.7.startLine=88
scope.7.endLine=93
scope.7.semanticHash=63a02df378deb2d0
scope.8.id=function:anonymous@96:96
scope.8.kind=function
scope.8.startLine=96
scope.8.endLine=98
scope.8.semanticHash=6a8aae6a858dfaaa
scope.9.id=function:_return_delegate:95
scope.9.kind=function
scope.9.startLine=95
scope.9.endLine=99
scope.9.semanticHash=3382315e11497906
scope.10.id=function:anonymous@105:105
scope.10.kind=function
scope.10.startLine=105
scope.10.endLine=113
scope.10.semanticHash=1205e2ecfc82740d
scope.11.id=function:anonymous@116:116
scope.11.kind=function
scope.11.startLine=116
scope.11.endLine=118
scope.11.semanticHash=8f6fc0bcddb21ae9
scope.12.id=function:anonymous@123:123
scope.12.kind=function
scope.12.startLine=123
scope.12.endLine=130
scope.12.semanticHash=8691829ee836b289
scope.13.id=function:anonymous@131:131
scope.13.kind=function
scope.13.startLine=131
scope.13.endLine=137
scope.13.semanticHash=058f383d2478b35c
scope.14.id=function:_register_default_handlers:101
scope.14.kind=function
scope.14.startLine=101
scope.14.endLine=141
scope.14.semanticHash=c07978d4b37f52c3
scope.15.id=function:_resolve_duration:145
scope.15.kind=function
scope.15.startLine=145
scope.15.endLine=157
scope.15.semanticHash=8f65913805d0c67f
scope.16.id=function:_resolve_tip_duration:159
scope.16.kind=function
scope.16.startLine=159
scope.16.endLine=168
scope.16.semanticHash=7ad5f7827fafd649
scope.17.id=function:_resolve_tip_text:170
scope.17.kind=function
scope.17.startLine=170
scope.17.endLine=178
scope.17.semanticHash=1db1159fb082b81d
scope.18.id=function:_enqueue_tip_text:180
scope.18.kind=function
scope.18.startLine=180
scope.18.endLine=192
scope.18.semanticHash=996554b0a9260508
scope.19.id=function:_emit_tip_text:194
scope.19.kind=function
scope.19.startLine=194
scope.19.endLine=202
scope.19.semanticHash=d4b42609032e4cca
scope.20.id=function:anonymous@211:211
scope.20.kind=function
scope.20.startLine=211
scope.20.endLine=220
scope.20.semanticHash=754086f2b4cc2ffb
scope.21.id=function:_build_handler_opts:204
scope.21.kind=function
scope.21.startLine=204
scope.21.endLine=226
scope.21.semanticHash=3084320369b5e1d1
scope.22.id=function:anonymous@242:242
scope.22.kind=function
scope.22.startLine=242
scope.22.endLine=244
scope.22.semanticHash=d5a3111b23d3e96d
scope.23.id=function:action_anim.play:228
scope.23.kind=function
scope.23.startLine=228
scope.23.endLine=250
scope.23.semanticHash=6879077a18b1ff46
]]
