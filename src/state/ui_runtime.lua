-- state.ui_runtime 切片:UI 模型、pending choice 与 modal 计时。
-- 原 src/state/runtime.lua 的 ui 块;公共面仍由 runtime.lua 门面转发,调用方不变。
local tables = require("src.foundation.tables")

local M = {}

function M.ensure(state)
  assert(type(state) == "table", "missing state")
  local ui_runtime = tables.ensure_table_field(state, "ui_runtime")
  tables.ensure_field(ui_runtime, "ui_dirty", false)
  tables.ensure_field(ui_runtime, "ui_model", nil)
  tables.ensure_field(ui_runtime, "pending_choice", nil)
  tables.ensure_field(ui_runtime, "pending_choice_elapsed", 0)
  tables.ensure_field(ui_runtime, "pending_choice_id", nil)
  tables.ensure_field(ui_runtime, "ui_modal_elapsed", 0)
  tables.ensure_field(ui_runtime, "ui_modal_ref", nil)
  if ui_runtime.item_name_by_id == nil then
    ui_runtime.item_name_by_id = state.item_name_by_id or {}
  end
  return ui_runtime
end

local function _getter(field)
  return function(state)
    return M.ensure(state)[field]
  end
end

local function _setter(field)
  return function(state, value)
    local ui_runtime = M.ensure(state)
    ui_runtime[field] = value
    return value
  end
end

function M.is_ui_dirty(state)
  return M.ensure(state).ui_dirty == true
end

function M.set_ui_dirty(state, dirty)
  local ui_runtime = M.ensure(state)
  ui_runtime.ui_dirty = dirty == true
  return ui_runtime.ui_dirty
end

M.get_ui_model = _getter("ui_model")
M.set_ui_model = _setter("ui_model")
M.get_pending_choice = _getter("pending_choice")
M.get_pending_choice_id = _getter("pending_choice_id")
M.set_pending_choice_id = _setter("pending_choice_id")

M.get_pending_choice_elapsed = _getter("pending_choice_elapsed")

function M.set_pending_choice_elapsed(state, elapsed_seconds)
  local ui_runtime = M.ensure(state)
  local next_elapsed = elapsed_seconds or 0
  ui_runtime.pending_choice_elapsed = next_elapsed
  return next_elapsed
end

function M.set_pending_choice(state, choice, opts)
  local ui_runtime = M.ensure(state)
  opts = opts or {}
  local choice_id = opts.choice_id
  if choice_id == nil and choice ~= nil then
    choice_id = choice.id
  end
  local elapsed_seconds = opts.elapsed_seconds
  if elapsed_seconds == nil then
    elapsed_seconds = 0
  end
  ui_runtime.pending_choice = choice
  ui_runtime.pending_choice_id = choice_id
  ui_runtime.pending_choice_elapsed = elapsed_seconds
  return choice
end

M.get_modal_elapsed = _getter("ui_modal_elapsed")

function M.get_modal_ref(state)
  local ui_runtime = M.ensure(state)
  return ui_runtime.ui_modal_ref
end

function M.set_modal_timer(state, payload)
  local ui_runtime = M.ensure(state)
  payload = payload or {}
  local elapsed_seconds = payload.elapsed_seconds or 0
  local ref = payload.ref
  ui_runtime.ui_modal_elapsed = elapsed_seconds
  ui_runtime.ui_modal_ref = ref
  return ref, elapsed_seconds
end

return M

--[[ mutate4lua-manifest
version=4
projectHash=6d3d0fef72402b21
scope.0.id=chunk:src/state/ui_runtime.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=97
scope.0.semanticHash=17a75207847df783
scope.1.id=function:M.ensure
scope.1.kind=function
scope.1.startLine=7
scope.1.endLine=21
scope.1.semanticHash=48ce751acbcceac7
scope.2.id=function:_getter
scope.2.kind=function
scope.2.startLine=23
scope.2.endLine=27
scope.2.semanticHash=1943198edea1ad94
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=24
scope.3.endLine=26
scope.3.semanticHash=e83acb507c787eab
scope.4.id=function:_setter
scope.4.kind=function
scope.4.startLine=29
scope.4.endLine=35
scope.4.semanticHash=d247a1bf26a33ab4
scope.5.id=function:<anonymous>#2
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=34
scope.5.semanticHash=0a78c051d20e151b
scope.6.id=function:M.is_ui_dirty
scope.6.kind=function
scope.6.startLine=37
scope.6.endLine=39
scope.6.semanticHash=e756512d6899cac6
scope.7.id=function:M.set_ui_dirty
scope.7.kind=function
scope.7.startLine=41
scope.7.endLine=45
scope.7.semanticHash=3f2f163855811e7b
scope.8.id=function:M.set_pending_choice_elapsed
scope.8.kind=function
scope.8.startLine=55
scope.8.endLine=60
scope.8.semanticHash=7d0433e2b6661cee
scope.9.id=function:M.set_pending_choice
scope.9.kind=function
scope.9.startLine=62
scope.9.endLine=77
scope.9.semanticHash=3b2958344d32fedc
scope.10.id=function:M.get_modal_ref
scope.10.kind=function
scope.10.startLine=81
scope.10.endLine=84
scope.10.semanticHash=35942bdcca888874
scope.11.id=function:M.set_modal_timer
scope.11.kind=function
scope.11.startLine=86
scope.11.endLine=94
scope.11.semanticHash=1bead2b15ae5c24b
]]
