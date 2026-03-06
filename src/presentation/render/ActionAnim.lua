local gameplay_rules = require("src.core.config.GameplayRules")
local number_utils = require("src.core.NumberUtils")

local runtime = require("src.presentation.api.UIRuntimePort")
local host_runtime = require("src.presentation.api.HostRuntimePort")
local registry = require("src.presentation.render.ActionAnimRegistry")
local handlers = require("src.presentation.render.ActionAnimHandlers")
local board_feedback = require("src.presentation.render.BoardFeedbackService")
local dice_nodes = require("src.presentation.canvas.dice.nodes")

local action_anim = {}

local durations = {
  missile = 1.2,
  monster = 1.2,
}
local roll_spin_seconds = 1.0
local roll_face_hold_seconds = 1.0

local function _show_tip(text, duration)
  host_runtime.show_tips(text, duration)
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

  if anim.kind ~= "roll" then
    _show_tip(handlers.build_tip(state, anim), tip_duration)
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
