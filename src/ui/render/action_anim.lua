local gameplay_rules = require("src.config.gameplay.gameplay_rules")
local runtime_constants = require("src.config.gameplay.runtime_constants")
local number_utils = require("src.core.utils.number_utils")
local logger = require("src.core.utils.logger")
local registry = require("src.ui.render.anim_registry")
local handlers = require("src.ui.render.anim_handlers")
local board_feedback = require("src.ui.render.board_feedback_service")
local dice_nodes = require("src.ui.schema.dice_nodes")
local host_runtime_bridge = require("src.ui.runtime.host_bridge")
local runtime_ui = require("src.ui.render.runtime_ui")

local action_anim = {}

local durations = {
  missile = 1.2,
  monster = 1.2,
}
local user_tip_whitelist = {
  change_skin = true,
}
local roll_spin_seconds = 1.0
local roll_face_hold_seconds = 1.0

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
    and (logger.is_anim_debug_enabled() or gameplay_rules.action_anim_debug_log_enabled == true)
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
  registry.register("roadblock", function(state, anim, duration, opts)
    handlers.play_overlay(state, anim, duration, opts)
    return duration
  end)
  registry.register("mine", function(state, anim, duration, opts)
    handlers.play_overlay(state, anim, duration, opts)
    return duration
  end)
  registry.register("move_effect", function(state, anim)
    return handlers.play_move_effect(state, _ensure_move_effect_direction(anim))
  end)
  registry.register("teleport_effect", function(state, anim)
    return handlers.play_teleport_effect(state, anim)
  end)
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
  registry.register("missile", function(state, anim, duration, opts)
    handlers.play_missile(state, anim, duration, opts)
    return duration
  end)
  registry.register("monster", function(state, anim, duration, opts)
    handlers.play_monster(state, anim, duration, opts)
    return duration
  end)
  registry.register("clear_obstacles", function(state, anim, duration, opts)
    handlers.play_clear_obstacles(state, anim, duration, opts)
    return duration
  end)
end

function action_anim.clear_overlay(state, kind, tile_index)
  handlers.clear_overlay(state, kind, tile_index)
end

local function _resolve_duration(anim)
  local default_duration = gameplay_rules.action_anim_default_seconds or 1.0
  local duration = anim.duration or durations[anim.kind] or default_duration
  if duration <= 0 then
    duration = default_duration
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

local function _emit_tip_text(host_runtime, tip_text, should_show_tip, should_debug_log, tip_duration)
  if should_debug_log and tip_text ~= nil and tip_text ~= "" then
    logger.info_unlimited("[ActionAnim]", tip_text)
  end
  if should_show_tip and tip_text ~= nil and tip_text ~= "" then
    if host_runtime and type(host_runtime.show_tips) == "function" then
      host_runtime.show_tips(tip_text, tip_duration)
    end
  end
end

local function _build_handler_opts(state, runtime_bundle, host_runtime)
  return {
    runtime = runtime_bundle.runtime,
    ui_events = runtime_bundle.ui_events,
    schedule = host_runtime and host_runtime.schedule or nil,
    runtime_bundle = runtime_bundle,
    show_tip = function(text, duration_seconds)
      if host_runtime and type(host_runtime.show_tips) == "function" then
        host_runtime.show_tips(text, duration_seconds)
      end
    end,
    hold_seconds = roll_face_hold_seconds,
    clear_overlay = action_anim.clear_overlay,
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
  _emit_tip_text(host_runtime, tip_text, should_show_tip, should_debug_log, tip_duration)
  if handler then
    return handler(state, anim, duration, _build_handler_opts(state, runtime_bundle, host_runtime))
  end
  return duration
end

return action_anim
