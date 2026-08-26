-- #329:三个刷新实现(board / panel presenter / turn effects)由 opts 注入,
-- support 不再静态 require 下游(拆 ui.render.support ↔ board/widgets 投影环)。
-- 缺实现的刷新分支当场报错,装配遗漏即刻暴露。
local canvas_store = require("src.ui.state.canvas_store")
local runtime_ui = require("src.ui.render.support.runtime_ui")
local ui_touch_policy = require("src.ui.input.touch")

local pipeline = {}
local _panel_opts = {}
local _effects_opts = {}

local function _flag_true(dirty, key)
  return dirty[key] == true
end

local function _has_struct_flags(dirty)
  return _flag_true(dirty, "permanent") or _flag_true(dirty, "base") or _flag_true(dirty, "board")
end

local function _has_model_flags(dirty)
  return _flag_true(dirty, "choice") or _flag_true(dirty, "effects") or _flag_true(dirty, "market")
end

local function _has_full_refresh_flags(dirty)
  return _has_struct_flags(dirty) or _has_model_flags(dirty)
end

local function _is_empty_dirty(dirty)
  if type(dirty) ~= "table" then
    return true
  end
  if _has_full_refresh_flags(dirty) then
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

local function _opt_or(opts, key, fallback)
  return opts and opts[key] or fallback
end

local function _resolve_render_deps(opts)
  local panel = opts and opts.panel
  local board = opts and opts.board
  local effects = opts and opts.effects
  local refresh_item_slots = opts and opts.refresh_item_slots
  local runtime = _opt_or(opts, "runtime", runtime_ui)
  local ui_touch = _opt_or(opts, "ui_touch_policy", ui_touch_policy)
  return panel, board, effects, runtime, refresh_item_slots, ui_touch
end

local function _should_refresh_board(dirty)
  return dirty.any == true or dirty.board == true or dirty.base == true
end

local function _should_refresh_effects(dirty)
  return dirty.any == true or dirty.effects == true or dirty.base == true
end

function pipeline.render(state_ctx, ui_model, log_once, build_log_prefix, opts)
  local dirty = _resolve_dirty(state_ctx, opts)
  if _is_empty_dirty(dirty) then
    dirty.any = true
  end

  local panel, board, effects, runtime, refresh_item_slots, ui_touch = _resolve_render_deps(opts)
  if _should_refresh_panel(dirty) then
    assert(panel ~= nil, "render_pipeline: missing opts.panel implementation")
    _panel_opts.runtime = runtime
    _panel_opts.refresh_item_slots = refresh_item_slots
    _panel_opts.ui_touch_policy = ui_touch
    panel.refresh(state_ctx, ui_model, _panel_opts)
  end
  if _should_refresh_board(dirty) then
    assert(board ~= nil, "render_pipeline: missing opts.board implementation")
    board.refresh(state_ctx, ui_model, log_once, build_log_prefix)
  end
  if _should_refresh_effects(dirty) then
    assert(effects ~= nil, "render_pipeline: missing opts.effects implementation")
    _effects_opts.runtime = runtime
    effects.sync(state_ctx, ui_model, _effects_opts)
  end
end

return pipeline

--[[ mutate4lua-manifest
version=4
projectHash=7265946b48013fcf
scope.0.id=chunk:src/ui/render/support/render_pipeline.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=98
scope.0.semanticHash=a78228132bf056d1
scope.1.id=function:_flag_true
scope.1.kind=function
scope.1.startLine=12
scope.1.endLine=14
scope.1.semanticHash=91b729454cfe2c94
scope.2.id=function:_has_struct_flags
scope.2.kind=function
scope.2.startLine=16
scope.2.endLine=18
scope.2.semanticHash=ac258cdb2b5e1f6d
scope.3.id=function:_has_model_flags
scope.3.kind=function
scope.3.startLine=20
scope.3.endLine=22
scope.3.semanticHash=ac258cdb2b5e1f6d
scope.4.id=function:_has_full_refresh_flags
scope.4.kind=function
scope.4.startLine=24
scope.4.endLine=26
scope.4.semanticHash=2ee715b033a18468
scope.5.id=function:_is_empty_dirty
scope.5.kind=function
scope.5.startLine=28
scope.5.endLine=36
scope.5.semanticHash=68f170a28079da87
scope.6.id=function:_resolve_dirty
scope.6.kind=function
scope.6.startLine=38
scope.6.endLine=44
scope.6.semanticHash=99bcfb7d9783b532
scope.7.id=function:_should_refresh_panel
scope.7.kind=function
scope.7.startLine=46
scope.7.endLine=48
scope.7.semanticHash=4bf1525e23da1aac
scope.8.id=function:_opt_or
scope.8.kind=function
scope.8.startLine=50
scope.8.endLine=52
scope.8.semanticHash=342fa04d54896db7
scope.9.id=function:_resolve_render_deps
scope.9.kind=function
scope.9.startLine=54
scope.9.endLine=62
scope.9.semanticHash=28cf17f3100ae16a
scope.10.id=function:_should_refresh_board
scope.10.kind=function
scope.10.startLine=64
scope.10.endLine=66
scope.10.semanticHash=e2b41969a0d08436
scope.11.id=function:_should_refresh_effects
scope.11.kind=function
scope.11.startLine=68
scope.11.endLine=70
scope.11.semanticHash=e2b41969a0d08436
scope.12.id=function:pipeline.render
scope.12.kind=function
scope.12.startLine=72
scope.12.endLine=95
scope.12.semanticHash=ace048e8404f49f2
]]
