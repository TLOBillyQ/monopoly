local board_runtime = require("src.ui.render.board")
local panel_presenter = require("src.ui.render.widgets.presenter")
local turn_effects = require("src.ui.render.widgets.turn_effects")
local canvas_store = require("src.ui.state.canvas_store")
local runtime_ui = require("src.ui.render.runtime_ui")
local ui_touch_policy = require("src.ui.input.touch")

local pipeline = {}
local _panel_opts = {}
local _effects_opts = {}

local function _is_empty_dirty(dirty)
  if type(dirty) ~= "table" then
    return true
  end
  if dirty.permanent == true or dirty.base == true or dirty.board == true
    or dirty.choice == true or dirty.effects == true or dirty.market == true then
    return false
  end
  return dirty.any ~= true
end

local function _resolve_dirty(state_ctx, opts)
  local dirty = opts and opts.dirty or nil
  if dirty then
    return dirty
  end
  return canvas_store.consume_dirty(state_ctx)
end

local function _should_refresh_panel(dirty)
  return dirty.any == true or dirty.base == true or dirty.permanent == true or dirty.choice == true or dirty.market == true
end

function pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, opts)
  local dirty = _resolve_dirty(state_ctx, opts)
  if _is_empty_dirty(dirty) then
    dirty.any = true
  end

  local refresh_item_slots = opts and opts.refresh_item_slots
  local runtime = opts and opts.runtime or runtime_ui
  local ui_touch = opts and opts.ui_touch_policy or ui_touch_policy
  if _should_refresh_panel(dirty) then
    _panel_opts.runtime = runtime
    _panel_opts.refresh_item_slots = refresh_item_slots
    _panel_opts.ui_touch_policy = ui_touch
    panel_presenter.refresh(state_ctx, ui_model, _panel_opts)
  end
  if dirty.any == true or dirty.board == true or dirty.base == true then
    board_runtime.refresh(state_ctx, ui_model, log_once, build_log_prefix)
  end
  if dirty.any == true or dirty.effects == true or dirty.base == true then
    _effects_opts.runtime = runtime
    turn_effects.sync(state_ctx, ui_model, _effects_opts)
  end
end

return pipeline
