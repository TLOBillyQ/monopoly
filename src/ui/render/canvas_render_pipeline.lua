local board_runtime = require("src.ui.render.board")
local panel_presenter = require("src.ui.widgets.panel_presenter")
local turn_effects = require("src.ui.widgets.turn_effects")
local canvas_store = require("src.ui.stores.canvas_store")

local pipeline = {}

local function _is_empty_dirty(dirty)
  if type(dirty) ~= "table" then
    return true
  end
  for key, value in pairs(dirty) do
    if key ~= "any" and value == true then
      return false
    end
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
  return dirty.any == true
    or dirty.base == true
    or dirty.always_show == true
    or dirty.choice == true
    or dirty.market == true
end

function pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, opts)
  local dirty = _resolve_dirty(state_ctx, opts)
  if _is_empty_dirty(dirty) then
    dirty.any = true
  end

  local refresh_item_slots = opts and opts.refresh_item_slots
  local runtime = opts and opts.runtime or require("src.ui.render.runtime_ui")
  local ui_touch_policy = opts and opts.ui_touch_policy or require("src.ui.input.touch_policy")
  if _should_refresh_panel(dirty) then
    panel_presenter.refresh(state_ctx, ui_model, {
      runtime = runtime,
      refresh_item_slots = refresh_item_slots,
      ui_touch_policy = ui_touch_policy,
    })
  end
  if dirty.any == true or dirty.board == true or dirty.base == true then
    board_runtime.refresh(state_ctx, ui_model, log_once, build_log_prefix)
  end
  if dirty.any == true or dirty.effects == true or dirty.base == true then
    turn_effects.sync(state_ctx, ui_model, {
      runtime = runtime,
    })
  end
end

return pipeline
