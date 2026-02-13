local gameplay_rules = require("Config.GameplayRules")

local runtime = require("src.presentation.api.UIRuntimePort")
local registry = require("src.presentation.render.ActionAnimRegistry")
local handlers = require("src.presentation.render.ActionAnimHandlers")

local action_anim = {}

local durations = {
  missile = 1.2,
  monster = 1.2,
}

local dice_screen_nodes = {
  screen = "骰子屏",
  spin = "骰子-旋转骰子底图",
  faces = {
    "骰子-骰子点数1",
    "骰子-骰子点数2",
    "骰子-骰子点数3",
    "骰子-骰子点数4",
    "骰子-骰子点数5",
    "骰子-骰子点数6",
  },
}

local function _show_tip(text, duration)
  if GlobalAPI and GlobalAPI.show_tips then
    GlobalAPI.show_tips(text, duration)
  end
end

local function _register_default_handlers()
  if registry.resolve("roll") then
    return
  end
  registry.register("roll", function(state, anim, duration, opts)
    handlers.play_roll_dice_screen(state, anim, duration, opts.hold_seconds or 0.5, {
      runtime = runtime,
      dice_screen_nodes = dice_screen_nodes,
    })
    return duration + (opts.hold_seconds or 0.5)
  end)
  registry.register("roadblock", function(state, anim, duration, opts)
    handlers.play_overlay(state, anim, duration, opts)
    return duration
  end)
  registry.register("mine", function(state, anim, duration, opts)
    handlers.play_overlay(state, anim, duration, opts)
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
  if type(duration) == "number" and math and math.tofixed then
    tip_duration = math.tofixed(duration)
  end

  if anim.kind ~= "roll" then
    _show_tip(handlers.build_tip(state, anim), tip_duration)
  end

  if handler then
    return handler(state, anim, duration, {
      show_tip = _show_tip,
      hold_seconds = 0.5,
      clear_overlay = action_anim.clear_overlay,
    })
  end

  return duration
end

return action_anim
