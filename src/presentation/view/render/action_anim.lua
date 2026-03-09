local gameplay_rules = require("src.core.config.gameplay_rules")
local number_utils = require("src.core.utils.number_utils")
local logger = require("src.core.utils.logger")

local runtime = require("src.presentation.runtime.ui")
local host_runtime = require("src.presentation.runtime.host")
local registry = require("src.presentation.view.render.anim_registry")
local handlers = require("src.presentation.view.render.anim_handlers")
local board_feedback = require("src.presentation.view.render.board_feedback_service")
local dice_nodes = require("src.presentation.view.canvas.dice.nodes")

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

local function _show_tip(text, duration)
  host_runtime.show_tips(text, duration)
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

local function _register_default_handlers()
  if registry.resolve("roll") then
    return
  end
  registry.register("roll", function(state, anim, duration, opts)
    handlers.play_roll_dice_screen(state, anim, roll_spin_seconds, roll_face_hold_seconds, {
      runtime = runtime,
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
  registry.register("upgrade_land", function(state, anim, duration, opts)
    board_feedback.play_tile_cue(state, "upgrade_land_smoke", anim.tile_index, {
      player_id = anim.player_id,
      duration = duration,
    })
    return duration
  end)
  registry.register("cash_receive", function(state, anim, duration, opts)
    board_feedback.play_player_cue(state, "cash_burst", anim.player_id, {
      duration = duration,
      amount = anim.amount,
    })
    return duration
  end)
  registry.register("missile", function(state, anim, duration, opts)
    handlers.play_missile(state, anim, duration, opts)
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

function action_anim.play(state, anim)
  assert(anim ~= nil, "missing anim")
  assert(state ~= nil, "missing state")
  _register_default_handlers()

  local default_duration = gameplay_rules.action_anim_default_seconds or 1.0
  local duration = anim.duration or durations[anim.kind] or default_duration
  if duration <= 0 then
    duration = default_duration
  end

  local handler = registry.resolve(anim.kind)
  local tip_duration = duration
  if number_utils.is_numeric(duration) and math and math.tofixed then
    local ok, as_fixed = pcall(math.tofixed, duration)
    if ok and as_fixed ~= nil then
      tip_duration = as_fixed
    end
  end

  local should_show_tip = _should_show_tip(anim)
  local should_debug_log = gameplay_rules.action_anim_debug_log_enabled == true and anim.kind ~= "roll"
  local tip_text = nil
  if should_show_tip or should_debug_log then
    tip_text = handlers.build_tip(state, anim)
  end

  if should_debug_log and tip_text ~= nil and tip_text ~= "" then
    logger.info("[ActionAnim]", tip_text)
  end

  if should_show_tip and tip_text ~= nil and tip_text ~= "" then
    _show_tip(tip_text, tip_duration)
  end

  if handler then
    return handler(state, anim, duration, {
      show_tip = _show_tip,
      hold_seconds = roll_face_hold_seconds,
      clear_overlay = action_anim.clear_overlay,
    })
  end

  return duration
end

return action_anim
