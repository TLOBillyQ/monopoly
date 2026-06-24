local default_catalog = require("src.config.content.skins")
local logger = require("src.foundation.log")

local context = {}

local state = {
  catalog = default_catalog,
  archive_adapter = nil,
  equip_adapter = nil,
  unequip_adapter = nil,
  purchase_adapter = nil,
}

function context.catalog()
  return state.catalog
end

function context.has_equip_adapter()
  return type(state.equip_adapter) == "function"
end

function context.has_unequip_adapter()
  return type(state.unequip_adapter) == "function"
end

function context.purchase_adapter()
  return state.purchase_adapter
end

function context.archive_call(method, role_id, product_id)
  local adapter = state.archive_adapter
  if type(adapter) ~= "table" or type(adapter[method]) ~= "function" then
    return nil
  end
  local ok, result = pcall(adapter[method], role_id, product_id)
  if ok then
    return result
  end
  return nil
end

function context.call_equip_adapter(role_id, skin)
  if not context.has_equip_adapter() then
    return false
  end
  local ok, result = pcall(state.equip_adapter, role_id, skin)
  return ok and result == true
end

function context.call_unequip_adapter(role_id)
  if not context.has_unequip_adapter() then
    return
  end
  local ok, err = pcall(state.unequip_adapter, role_id)
  if ok then
    return
  end
  logger.warn(
    "skin_panel: unequip callback failed",
    "role_id=" .. tostring(role_id),
    tostring(err)
  )
end

local function _configure_callback(field, callback, message)
  assert(callback == nil or type(callback) == "function", message)
  state[field] = callback
end

function context.configure_equip(callback)
  _configure_callback("equip_adapter", callback, "invalid skin equip callback")
end

function context.configure_unequip(callback)
  _configure_callback("unequip_adapter", callback, "invalid skin unequip callback")
end

function context.configure_purchase(callback)
  _configure_callback("purchase_adapter", callback, "invalid skin purchase callback")
end

function context.configure_archive(archive)
  assert(archive == nil or type(archive) == "table", "invalid skin archive")
  state.archive_adapter = archive
end

function context.configure_catalog_for_tests(new_catalog)
  state.catalog = new_catalog or default_catalog
end

function context.reset_for_tests()
  state.catalog = default_catalog
  state.archive_adapter = nil
  state.equip_adapter = nil
  state.unequip_adapter = nil
  state.purchase_adapter = nil
end

return context
