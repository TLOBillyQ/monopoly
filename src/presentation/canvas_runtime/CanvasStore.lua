local canvas_store = {}

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
  local dirty = store.dirty
  dirty.any = true
  if key then
    dirty[key] = true
  end
  store.version = (store.version or 0) + 1
end

function canvas_store.patch_slice(state_or_ui, key, patch)
  assert(key ~= nil, "missing canvas slice key")
  local slice = canvas_store.get_slice(state_or_ui, key)
  if patch == nil then
    canvas_store.mark_dirty(state_or_ui, key)
    return slice
  end
  if type(patch) == "function" then
    patch(slice, _resolve_ui(state_or_ui), state_or_ui)
  elseif type(patch) == "table" then
    for patch_key, patch_value in pairs(patch) do
      slice[patch_key] = patch_value
    end
  else
    error("canvas_store.patch_slice expects table/function patch")
  end
  canvas_store.mark_dirty(state_or_ui, key)
  return slice
end

function canvas_store.consume_dirty(state_or_ui)
  local store = canvas_store.ensure(state_or_ui)
  if not store then
    return { any = false }
  end
  local dirty = store.dirty
  store.dirty = { any = false }
  return dirty
end

return canvas_store
