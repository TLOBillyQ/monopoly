local runtime_constants = require("src.config.gameplay.runtime_constants")
local handlers = require("src.ui.render.anim.handlers")
local board_feedback = require("src.ui.render.board_feedback.service")
local dice_nodes = require("src.ui.schema.dice")

local defaults = {}

local function _timing_or(value, fallback)
  if value ~= nil then
    return value
  end
  return fallback
end

local function _timing()
  return require("src.config.gameplay.timing")
end

function defaults.roll_spin_seconds()
  return _timing_or(_timing().dice_spin_seconds, 1.0)
end

function defaults.roll_face_hold_seconds()
  return _timing_or(_timing().dice_face_hold_seconds, 1.0)
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

function defaults.register()
  local registry = require("src.ui.render.anim.registry")
  if registry.resolve("roll") then
    return
  end
  registry.register("roll", function(state, anim, _, opts)
    local roll_spin_seconds = defaults.roll_spin_seconds()
    local roll_face_hold_seconds = defaults.roll_face_hold_seconds()
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

return defaults

--[[ mutate4lua-manifest
version=4
projectHash=5f167245f0765d92
scope.0.id=chunk:src/ui/render/anim/defaults.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=0c7e6d846bf8def3
scope.1.id=function:_timing_or
scope.1.kind=function
scope.1.startLine=8
scope.1.endLine=13
scope.1.semanticHash=5d2dbc03da2169ee
scope.2.id=function:_timing
scope.2.kind=function
scope.2.startLine=15
scope.2.endLine=17
scope.2.semanticHash=361867a8848129cb
scope.3.id=function:defaults.roll_spin_seconds
scope.3.kind=function
scope.3.startLine=19
scope.3.endLine=21
scope.3.semanticHash=0b31edf75d35a118
scope.4.id=function:defaults.roll_face_hold_seconds
scope.4.kind=function
scope.4.startLine=23
scope.4.endLine=25
scope.4.semanticHash=0b31edf75d35a118
scope.5.id=function:_ensure_move_effect_direction
scope.5.kind=function
scope.5.startLine=27
scope.5.endLine=37
scope.5.semanticHash=5a229f053e3f2c49
scope.6.id=function:_void_delegate
scope.6.kind=function
scope.6.startLine=39
scope.6.endLine=44
scope.6.semanticHash=ce95c867a3a1d041
scope.7.id=function:<anonymous>
scope.7.kind=function
scope.7.startLine=40
scope.7.endLine=43
scope.7.semanticHash=17420eda8001e354
scope.8.id=function:_return_delegate
scope.8.kind=function
scope.8.startLine=46
scope.8.endLine=50
scope.8.semanticHash=43a70eede4649510
scope.9.id=function:<anonymous>#2
scope.9.kind=function
scope.9.startLine=47
scope.9.endLine=49
scope.9.semanticHash=360776c78d632b1f
scope.10.id=function:defaults.register
scope.10.kind=function
scope.10.startLine=52
scope.10.endLine=95
scope.10.semanticHash=673d4f1a9e2b2f2a
scope.11.id=function:<anonymous>#3
scope.11.kind=function
scope.11.startLine=57
scope.11.endLine=67
scope.11.semanticHash=2076239c568e4710
scope.12.id=function:<anonymous>#4
scope.12.kind=function
scope.12.startLine=70
scope.12.endLine=72
scope.12.semanticHash=9bb591359f501c45
scope.13.id=function:<anonymous>#5
scope.13.kind=function
scope.13.startLine=77
scope.13.endLine=84
scope.13.semanticHash=17fd511373b12824
scope.14.id=function:<anonymous>#6
scope.14.kind=function
scope.14.startLine=85
scope.14.endLine=91
scope.14.semanticHash=6d6b77610bc1f0ae
]]
