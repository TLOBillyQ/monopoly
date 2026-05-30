local base_nodes = require("src.ui.schema.base")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local row_field = require("src.ui.render.widgets.row_field")

local panel_cash_delta = {}

local _cash_delta_names = {}
for _i = 1, 4 do
  _cash_delta_names[_i] = string.format(base_nodes.player_cash_delta, _i)
end

local function _safe_ui_call(ui, method_name, ...)
  if not ui or type(ui[method_name]) ~= "function" then
    return false
  end
  local ok = pcall(ui[method_name], ui, ...)
  return ok
end

local function _set_visible_safe(ui, name, visible)
  return _safe_ui_call(ui, "set_visible", name, visible)
end

local _resolve_integer_field = row_field.to_integer

local function _set_cash_delta_label(ui, index, text, visible)
  local label_name = _cash_delta_names[index]
  local shown = _safe_ui_call(ui, "set_label", label_name, text or "")
  if shown or visible ~= nil then
    _set_visible_safe(ui, label_name, visible == true)
  end
  return shown
end

local function _clear_cash_delta_label(ui, index)
  _set_cash_delta_label(ui, index, "", false)
end

local function _ensure_entry(ui, index)
  local entry = ui.player_cash_delta_state_by_index[index]
  if entry == nil then
    entry = { hide_token = 0, anchor_cash = nil, visible = false }
    ui.player_cash_delta_state_by_index[index] = entry
  end
  return entry
end

local function _bump_token(entry)
  entry.hide_token = (entry.hide_token or 0) + 1
  return entry.hide_token
end

local function _token_is_current(entry, token)
  return entry ~= nil and entry.hide_token == token
end

local function _schedule_hide_cash_delta(ui, index, entry, token)
  runtime_ports.schedule(timing.panel_cash_delta_visible_seconds or 3.0, function()
    if not _token_is_current(entry, token) then
      return
    end
    _clear_cash_delta_label(ui, index)
    entry.visible = false
    entry.anchor_cash = nil
  end)
end

local function _schedule_show_cash_delta(ui, index, text, entry, token)
  local show_delay = timing.panel_cash_delta_show_delay_seconds or 0.0
  local function _do_show()
    if not _token_is_current(entry, token) then
      return
    end
    local shown = _set_cash_delta_label(ui, index, text, true)
    if shown then
      entry.visible = true
      _schedule_hide_cash_delta(ui, index, entry, token)
    end
  end
  if show_delay <= 0 then
    _do_show()
    return
  end
  runtime_ports.schedule(show_delay, _do_show)
end

function panel_cash_delta.ensure_state(ui)
  if type(ui.player_cash_value_cache_by_index) ~= "table" then
    ui.player_cash_value_cache_by_index = {}
  end
  if type(ui.player_cash_delta_state_by_index) ~= "table" then
    ui.player_cash_delta_state_by_index = {}
  end
end

function panel_cash_delta.refresh_cash_delta_label(ui, index, row)
  local cash_value = _resolve_integer_field(row, "cash_value")
  local prev_cash_value = ui.player_cash_value_cache_by_index[index]
  local entry = _ensure_entry(ui, index)

  if cash_value == nil then
    _bump_token(entry)
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = nil
    entry.anchor_cash = nil
    entry.visible = false
    return
  end

  if prev_cash_value == nil then
    _bump_token(entry)
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = cash_value
    entry.anchor_cash = nil
    entry.visible = false
    return
  end

  ui.player_cash_value_cache_by_index[index] = cash_value

  if cash_value == prev_cash_value then
    return
  end

  -- 每次变化独立显示：始终以本次变化前的值为锚点，旧的 hide 回调由 token bump 取消，
  -- 显示窗口内的连续变化不再累加为净额。
  entry.anchor_cash = prev_cash_value
  local display_delta = cash_value - prev_cash_value

  local sign = "+"
  local magnitude = display_delta
  if display_delta < 0 then
    sign = "-"
    magnitude = -display_delta
  end
  local text = sign .. number_utils.format_integer_part(magnitude)
  local token = _bump_token(entry)
  _schedule_show_cash_delta(ui, index, text, entry, token)
end

return panel_cash_delta

--[[ mutate4lua-manifest
version=2
projectHash=2d2b3cea72e49b11
scope.0.id=chunk:src/ui/render/widgets/cash_delta.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=144
scope.0.semanticHash=1396bedfa19f056c
scope.1.id=function:_safe_ui_call:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=20
scope.1.semanticHash=84ff85593a1d9c6f
scope.2.id=function:_set_visible_safe:22
scope.2.kind=function
scope.2.startLine=22
scope.2.endLine=24
scope.2.semanticHash=fcfb46d379c6cbb3
scope.3.id=function:_set_cash_delta_label:28
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=35
scope.3.semanticHash=469cc0b7ad0e7235
scope.4.id=function:_clear_cash_delta_label:37
scope.4.kind=function
scope.4.startLine=37
scope.4.endLine=39
scope.4.semanticHash=af5e4b730ed51726
scope.5.id=function:_ensure_entry:41
scope.5.kind=function
scope.5.startLine=41
scope.5.endLine=48
scope.5.semanticHash=b977d93806a58d0d
scope.6.id=function:_bump_token:50
scope.6.kind=function
scope.6.startLine=50
scope.6.endLine=53
scope.6.semanticHash=5f13588a8dcd992b
scope.7.id=function:_token_is_current:55
scope.7.kind=function
scope.7.startLine=55
scope.7.endLine=57
scope.7.semanticHash=32bb76d121b8ddb1
scope.8.id=function:anonymous@60:60
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=67
scope.8.semanticHash=c22643686e8c6050
scope.9.id=function:_schedule_hide_cash_delta:59
scope.9.kind=function
scope.9.startLine=59
scope.9.endLine=68
scope.9.semanticHash=86042f789a0f7014
scope.10.id=function:_do_show:72
scope.10.kind=function
scope.10.startLine=72
scope.10.endLine=81
scope.10.semanticHash=ef7fe4c638b99669
scope.11.id=function:_schedule_show_cash_delta:70
scope.11.kind=function
scope.11.startLine=70
scope.11.endLine=87
scope.11.semanticHash=52d3b72b54e0f890
scope.12.id=function:panel_cash_delta.ensure_state:89
scope.12.kind=function
scope.12.startLine=89
scope.12.endLine=96
scope.12.semanticHash=654e3698c7f04d68
scope.13.id=function:panel_cash_delta.refresh_cash_delta_label:98
scope.13.kind=function
scope.13.startLine=98
scope.13.endLine=141
scope.13.semanticHash=960c99bd4b3ac9ef
]]
