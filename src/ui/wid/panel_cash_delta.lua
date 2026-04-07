local base_nodes = require("src.ui.schema.base")
local runtime_ports = require("src.core.ports.runtime_ports")
local timing = require("src.config.gameplay.timing")
local number_utils = require("src.core.utils.number_utils")

local panel_cash_delta = {}

local function _safe_ui_call(ui, method_name, ...)
  if not ui or type(ui[method_name]) ~= "function" then
    return false
  end
  local ok = pcall(ui[method_name], ui, ...)
  return ok
end

local function _set_label_safe(ui, name, value)
  return _safe_ui_call(ui, "set_label", name, value)
end

local function _set_visible_safe(ui, name, visible)
  return _safe_ui_call(ui, "set_visible", name, visible)
end

local function _resolve_integer_field(row, key)
  if not row then
    return nil
  end
  return number_utils.to_integer(row[key])
end

local function _set_cash_delta_label(ui, index, text, visible)
  local label_name = string.format(base_nodes.player_cash_delta, index)
  local shown = _set_label_safe(ui, label_name, text or "")
  if shown or visible ~= nil then
    _set_visible_safe(ui, label_name, visible == true)
  end
  return shown
end

local function _clear_cash_delta_label(ui, index)
  _set_cash_delta_label(ui, index, "", false)
end

local function _schedule_hide_cash_delta(ui, index)
  local token = (ui.player_cash_delta_hide_token_by_index[index] or 0) + 1
  ui.player_cash_delta_hide_token_by_index[index] = token
  runtime_ports.schedule(timing.panel_cash_delta_visible_seconds or 3.0, function()
    if not ui.player_cash_delta_hide_token_by_index then
      return
    end
    if ui.player_cash_delta_hide_token_by_index[index] ~= token then
      return
    end
    _clear_cash_delta_label(ui, index)
  end)
end

function panel_cash_delta.ensure_state(ui)
  if type(ui.player_cash_value_cache_by_index) ~= "table" then
    ui.player_cash_value_cache_by_index = {}
  end
  if type(ui.player_cash_delta_hide_token_by_index) ~= "table" then
    ui.player_cash_delta_hide_token_by_index = {}
  end
end

function panel_cash_delta.refresh_cash_delta_label(ui, index, row)
  local cash_value = _resolve_integer_field(row, "cash_value")
  local prev_cash_value = ui.player_cash_value_cache_by_index[index]
  if cash_value == nil then
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = nil
    return
  end
  if prev_cash_value == nil then
    _clear_cash_delta_label(ui, index)
    ui.player_cash_value_cache_by_index[index] = cash_value
    return
  end
  local delta = cash_value - prev_cash_value
  ui.player_cash_value_cache_by_index[index] = cash_value
  if delta == 0 then
    _clear_cash_delta_label(ui, index)
    return
  end
  local sign = "+"
  if delta < 0 then
    sign = "-"
    delta = -delta
  end
  local text = sign .. number_utils.format_integer_part(delta)
  local shown = _set_cash_delta_label(ui, index, text, true)
  if shown then
    _schedule_hide_cash_delta(ui, index)
  end
end

return panel_cash_delta
