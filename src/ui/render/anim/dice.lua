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
version=2
projectHash=4194189779021826
scope.0.id=chunk:src/ui/render/anim/dice.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=119
scope.0.semanticHash=129f4b7ddf5d12f4
scope.1.id=function:_resolve_face_value:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=12
scope.1.semanticHash=b6804d246d325e0e
scope.2.id=function:_resolve_roll_face:14
scope.2.kind=function
scope.2.startLine=14
scope.2.endLine=25
scope.2.semanticHash=001406078ec9abc3
scope.3.id=function:_set_roll_screen_visible:33
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=37
scope.3.semanticHash=766ac34f1e135c7e
scope.4.id=function:_show_roll_result:39
scope.4.kind=function
scope.4.startLine=39
scope.4.endLine=44
scope.4.semanticHash=55369314ece40279
scope.5.id=function:_cleanup_roll_screen:46
scope.5.kind=function
scope.5.startLine=46
scope.5.endLine=52
scope.5.semanticHash=08a9b31bfeaa62b9
scope.6.id=function:_resolve_roll_screen_opts:54
scope.6.kind=function
scope.6.startLine=54
scope.6.endLine=58
scope.6.semanticHash=14eed6d4ff8e4f78
scope.7.id=function:_resolve_roll_timing:60
scope.7.kind=function
scope.7.startLine=60
scope.7.endLine=62
scope.7.semanticHash=004b8f17df0cd531
scope.8.id=function:_resolve_roll_display_face:64
scope.8.kind=function
scope.8.startLine=64
scope.8.endLine=66
scope.8.semanticHash=79240b647482e9ff
scope.9.id=function:anonymous@84:84
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=86
scope.9.semanticHash=cec5940dcfc11618
scope.10.id=function:anonymous@90:90
scope.10.kind=function
scope.10.startLine=90
scope.10.endLine=93
scope.10.semanticHash=5afde5b81b48fe1e
scope.11.id=function:anonymous@97:97
scope.11.kind=function
scope.11.startLine=97
scope.11.endLine=99
scope.11.semanticHash=d43d97f828bad13c
scope.12.id=function:_play_roll_dice_for_role:80
scope.12.kind=function
scope.12.startLine=80
scope.12.endLine=101
scope.12.semanticHash=c7cfdeca4a6c1204
scope.13.id=function:anonymous@113:113
scope.13.kind=function
scope.13.startLine=113
scope.13.endLine=115
scope.13.semanticHash=09aa826869635e89
scope.14.id=function:dice.play_roll_dice_screen:103
scope.14.kind=function
scope.14.startLine=103
scope.14.endLine=116
scope.14.semanticHash=d9dec85b615ba12f
]]
