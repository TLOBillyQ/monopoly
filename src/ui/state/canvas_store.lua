local canvas_store = {}
local _allowed_dirty_keys = {
  permanent = true,
  base = true,
  board = true,
  choice = true,
  effects = true,
  market = true,
}

local function _assert_valid_dirty_key(key)
  if key == nil then
    return
  end
  assert(_allowed_dirty_keys[key] == true, "unsupported canvas dirty key: " .. tostring(key))
end

local function _resolve_ui(state_or_ui)
  if type(state_or_ui) ~= "table" then
    return nil
  end
  if type(state_or_ui.ui) == "table" then
    return state_or_ui.ui
  end
  return state_or_ui
end

local function _init_store(ui)
  local store = ui.__canvas_store
  if type(store) == "table" then
    return store
  end
  store = {
    slices = ui.canvas_state or {},
    dirty = { any = true },
    version = 1,
  }
  ui.__canvas_store = store
  ui.canvas_store = store
  return store
end

function canvas_store.ensure(state_or_ui)
  local ui = _resolve_ui(state_or_ui)
  if not ui then
    return nil
  end
  return _init_store(ui)
end

function canvas_store.get_slice(state_or_ui, key)
  local store = canvas_store.ensure(state_or_ui)
  if not store or not key then
    return nil
  end
  _assert_valid_dirty_key(key)
  local slices = store.slices
  if type(slices[key]) ~= "table" then
    slices[key] = {}
  end
  return slices[key]
end

function canvas_store.mark_dirty(state_or_ui, key)
  local store = canvas_store.ensure(state_or_ui)
  if not store then
    return
  end
  _assert_valid_dirty_key(key)
  local dirty = store.dirty
  dirty.any = true
  if key then
    dirty[key] = true
  end
  store.version = (store.version or 0) + 1
end

-- 函数 patch 拿到 (slice, ui, state_or_ui) 自行改写；表 patch 直接浅合并。
local function _apply_patch(slice, patch, state_or_ui)
  if type(patch) == "function" then
    patch(slice, _resolve_ui(state_or_ui), state_or_ui)
    return
  end
  if type(patch) ~= "table" then
    error("canvas_store.patch_slice expects table/function patch")
  end
  for patch_key, patch_value in pairs(patch) do
    slice[patch_key] = patch_value
  end
end

function canvas_store.patch_slice(state_or_ui, key, patch)
  assert(key ~= nil, "missing canvas slice key")
  _assert_valid_dirty_key(key)
  local slice = canvas_store.get_slice(state_or_ui, key)
  if patch == nil then
    canvas_store.mark_dirty(state_or_ui, key)
    return slice
  end
  _apply_patch(slice, patch, state_or_ui)
  canvas_store.mark_dirty(state_or_ui, key)
  return slice
end

function canvas_store.consume_dirty(state_or_ui)
  local store = canvas_store.ensure(state_or_ui)
  if not store then
    return { any = false }
  end
  local dirty = store.dirty
  local spare = store._dirty_spare
  if spare ~= nil then
    spare.any = false
    spare.permanent = nil
    spare.base = nil
    spare.board = nil
    spare.choice = nil
    spare.effects = nil
    spare.market = nil
  else
    spare = { any = false }
  end
  store.dirty = spare
  store._dirty_spare = dirty
  return dirty
end

return canvas_store

--[[ mutate4lua-manifest
version=4
projectHash=929abf128b24046b
scope.0.id=chunk:src/ui/state/canvas_store.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=129
scope.0.semanticHash=f429cc838165fdb0
scope.1.id=function:_assert_valid_dirty_key
scope.1.kind=function
scope.1.startLine=11
scope.1.endLine=16
scope.1.semanticHash=6a21348f22970b54
scope.2.id=function:_resolve_ui
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=26
scope.2.semanticHash=21e55e52d7c37bab
scope.3.id=function:_init_store
scope.3.kind=function
scope.3.startLine=28
scope.3.endLine=41
scope.3.semanticHash=27441490a647f259
scope.4.id=function:canvas_store.ensure
scope.4.kind=function
scope.4.startLine=43
scope.4.endLine=49
scope.4.semanticHash=691b1068788fc42a
scope.5.id=function:canvas_store.get_slice
scope.5.kind=function
scope.5.startLine=51
scope.5.endLine=62
scope.5.semanticHash=cb00a29fce283391
scope.6.id=function:canvas_store.mark_dirty
scope.6.kind=function
scope.6.startLine=64
scope.6.endLine=76
scope.6.semanticHash=58eb8e709ad41ad2
scope.7.id=function:_apply_patch
scope.7.kind=function
scope.7.startLine=79
scope.7.endLine=90
scope.7.semanticHash=d9837b398b2ededa
scope.8.id=function:canvas_store.patch_slice
scope.8.kind=function
scope.8.startLine=92
scope.8.endLine=103
scope.8.semanticHash=7bc26dffd77260b8
scope.9.id=function:canvas_store.consume_dirty
scope.9.kind=function
scope.9.startLine=105
scope.9.endLine=126
scope.9.semanticHash=84a7de3d0f131a2b
]]
