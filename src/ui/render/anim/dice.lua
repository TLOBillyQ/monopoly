local number_utils = require("src.foundation.number")
local effect_timeline = require("src.ui.render.support.effect_timeline")

local dice = {}

local function _resolve_face_value(value)
  local face = number_utils.to_integer(value)
  if face and face >= 1 and face <= 6 then
    return face
  end
  return nil
end

local function _resolve_roll_face(anim)
  if not anim then
    return nil
  end
  local rolls = anim.rolls
  local first = type(rolls) == "table" and rolls[1] or nil
  local first_face = _resolve_face_value(first)
  if first_face then
    return first_face
  end
  return _resolve_face_value(anim.total)
end

local function _set_face_nodes_visibility(face_nodes, face)
  for index, node in ipairs(face_nodes or {}) do
    node.visible = face == index
  end
end

local function _set_roll_screen_visible(nodes, visible)
  nodes.screen.visible = visible
  nodes.spin.visible = visible
  _set_face_nodes_visibility(nodes.faces, nil)
end

local function _show_roll_result(nodes, face)
  nodes.spin.visible = false
  if face then
    _set_face_nodes_visibility(nodes.faces, face)
  end
end

local function _cleanup_roll_screen(nodes, ui_events, dice_nodes)
  local hide_event = ui_events.hide[dice_nodes.canvas]
  if hide_event then
    ui_events.send_to_all(hide_event, {})
  end
  _set_roll_screen_visible(nodes, false)
end

local function _resolve_roll_screen_opts(opts)
  return assert(opts and opts.runtime, "missing runtime"),
    assert(opts and opts.dice_screen_nodes, "missing dice_screen_nodes"),
    assert(opts and opts.ui_events, "missing opts.ui_events")
end

local function _resolve_roll_timing(duration, hold_seconds)
  return duration or 0, hold_seconds or 0
end

local function _resolve_roll_display_face(anim)
  return _resolve_roll_face(anim) or 1
end

local function _query_roll_nodes(runtime, dice_nodes)
  local nodes = {
    screen = runtime.query_node(dice_nodes.canvas),
    spin = runtime.query_node(dice_nodes.spin),
    faces = {},
  }
  for index, name in ipairs(dice_nodes.faces) do
    nodes.faces[index] = runtime.query_node(name)
  end
  return nodes
end

local function _play_roll_dice_for_role(runtime, dice_nodes, ui_events, duration, hold_seconds, face, opts)
  local nodes = _query_roll_nodes(runtime, dice_nodes)
  effect_timeline.play({
    schedule = opts.schedule,
    show = function()
      _set_roll_screen_visible(nodes, true)
    end,
    steps = {
      {
        delay = duration,
        run = function()
          ui_events.send_to_all("重置骰子旋转", {})
          _show_roll_result(nodes, face)
        end,
      },
    },
    cleanup_delay = duration + hold_seconds,
    cleanup = function()
      _cleanup_roll_screen(nodes, ui_events, dice_nodes)
    end,
  })
end

function dice.play_roll_dice_screen(anim, duration, hold_seconds, opts)
  local runtime, dice_nodes, ui_events = _resolve_roll_screen_opts(opts)
  duration, hold_seconds = _resolve_roll_timing(duration, hold_seconds)
  local face = _resolve_roll_display_face(anim)
  local show_event = ui_events.show[dice_nodes.canvas]
  if show_event then
    ui_events.send_to_all(show_event, {})
  end
  ui_events.send_to_all("重置骰子旋转", {})
  ui_events.send_to_all("旋转骰子", {})
  runtime.for_each_role_or_global(function()
    _play_roll_dice_for_role(runtime, dice_nodes, ui_events, duration, hold_seconds, face, opts)
  end)
end

return dice

--[[ mutate4lua-manifest
version=4
projectHash=5ebf77efd4ffa481
scope.0.id=chunk:src/ui/render/anim/dice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=839c419b2156c393
scope.1.id=function:_resolve_face_value
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=cb373fd699c5fe2f
scope.2.id=function:_resolve_roll_face
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=25
scope.2.semanticHash=c453a5a176c3f5f1
scope.3.id=function:_set_face_nodes_visibility
scope.3.kind=function
scope.3.startLine=27
scope.3.endLine=31
scope.3.semanticHash=a40c81011ea656f2
scope.4.id=function:_set_roll_screen_visible
scope.4.kind=function
scope.4.startLine=33
scope.4.endLine=37
scope.4.semanticHash=69f7ca7ba69d7038
scope.5.id=function:_show_roll_result
scope.5.kind=function
scope.5.startLine=39
scope.5.endLine=44
scope.5.semanticHash=8fd64db4329e1c20
scope.6.id=function:_cleanup_roll_screen
scope.6.kind=function
scope.6.startLine=46
scope.6.endLine=52
scope.6.semanticHash=8cf5ac95c963d295
scope.7.id=function:_resolve_roll_screen_opts
scope.7.kind=function
scope.7.startLine=54
scope.7.endLine=58
scope.7.semanticHash=6a467db2fbcd5d91
scope.8.id=function:_resolve_roll_timing
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=62
scope.8.semanticHash=d1154d1ca5fa05e9
scope.9.id=function:_resolve_roll_display_face
scope.9.kind=function
scope.9.startLine=64
scope.9.endLine=66
scope.9.semanticHash=552434c711d2cb11
scope.10.id=function:_query_roll_nodes
scope.10.kind=function
scope.10.startLine=68
scope.10.endLine=78
scope.10.semanticHash=b83580ed2f7d55ba
scope.11.id=function:_play_roll_dice_for_role
scope.11.kind=function
scope.11.startLine=80
scope.11.endLine=101
scope.11.semanticHash=ee9f6fa5bd5a1062
scope.12.id=function:<anonymous>
scope.12.kind=function
scope.12.startLine=84
scope.12.endLine=86
scope.12.semanticHash=f23b771e74e4ed56
scope.13.id=function:<anonymous>#2
scope.13.kind=function
scope.13.startLine=90
scope.13.endLine=93
scope.13.semanticHash=74a72297f9e1d80f
scope.14.id=function:<anonymous>#3
scope.14.kind=function
scope.14.startLine=97
scope.14.endLine=99
scope.14.semanticHash=4ac65c65acb92f3b
scope.15.id=function:dice.play_roll_dice_screen
scope.15.kind=function
scope.15.startLine=103
scope.15.endLine=116
scope.15.semanticHash=c57af4dcc229e207
scope.16.id=function:<anonymous>#4
scope.16.kind=function
scope.16.startLine=113
scope.16.endLine=115
scope.16.semanticHash=ca0f974ecd87792b
]]
