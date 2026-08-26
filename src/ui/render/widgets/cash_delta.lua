local base_nodes = require("src.ui.schema.base")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.foundation.number")
local row_field = require("src.ui.render.widgets.row_field")
local tables = require("src.foundation.tables")

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
  tables.ensure_table_field(ui, "player_cash_value_cache_by_index")
  tables.ensure_table_field(ui, "player_cash_delta_state_by_index")
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
version=4
projectHash=47dab6518dfd3703
scope.0.id=chunk:src/ui/render/widgets/cash_delta.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=141
scope.0.semanticHash=0cd64575be580ee4
scope.1.id=function:_safe_ui_call
scope.1.kind=function
scope.1.startLine=15
scope.1.endLine=21
scope.1.semanticHash=d90f9c4e24cde35e
scope.2.id=function:_set_visible_safe
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=25
scope.2.semanticHash=7c75d9437e0a07d7
scope.3.id=function:_set_cash_delta_label
scope.3.kind=function
scope.3.startLine=29
scope.3.endLine=36
scope.3.semanticHash=2a6cdfef836240ae
scope.4.id=function:_clear_cash_delta_label
scope.4.kind=function
scope.4.startLine=38
scope.4.endLine=40
scope.4.semanticHash=7d2c48a5a8c8e051
scope.5.id=function:_ensure_entry
scope.5.kind=function
scope.5.startLine=42
scope.5.endLine=49
scope.5.semanticHash=4a40d0d19678aceb
scope.6.id=function:_bump_token
scope.6.kind=function
scope.6.startLine=51
scope.6.endLine=54
scope.6.semanticHash=6f38e77f4006025e
scope.7.id=function:_token_is_current
scope.7.kind=function
scope.7.startLine=56
scope.7.endLine=58
scope.7.semanticHash=0baa4b967654ed3a
scope.8.id=function:_schedule_hide_cash_delta
scope.8.kind=function
scope.8.startLine=60
scope.8.endLine=69
scope.8.semanticHash=0093ee97d89aa234
scope.9.id=function:<anonymous>
scope.9.kind=function
scope.9.startLine=61
scope.9.endLine=68
scope.9.semanticHash=eb9cc9d8ac961f0f
scope.10.id=function:_schedule_show_cash_delta
scope.10.kind=function
scope.10.startLine=71
scope.10.endLine=88
scope.10.semanticHash=eb3081b2b7af60e6
scope.11.id=function:_do_show
scope.11.kind=function
scope.11.startLine=73
scope.11.endLine=82
scope.11.semanticHash=129c72f6eb749f11
scope.12.id=function:panel_cash_delta.ensure_state
scope.12.kind=function
scope.12.startLine=90
scope.12.endLine=93
scope.12.semanticHash=b98c437249f994a5
scope.13.id=function:panel_cash_delta.refresh_cash_delta_label
scope.13.kind=function
scope.13.startLine=95
scope.13.endLine=138
scope.13.semanticHash=7ca9928bd7327892
]]
