local default_catalog = require("src.config.content.skins")
local logger = require("src.foundation.log")

local context = {}

local state = {
  catalog = default_catalog,
  archive_adapter = nil,
  equip_adapter = nil,
  unequip_adapter = nil,
  transaction_result_applier = nil,
}

local function _price_before(price_a, price_b)
  if price_a == nil then
    return false
  end
  if price_b == nil then
    return true
  end
  return price_a < price_b
end

-- 目录排序真源（#495 裁定）：price 递增为主键（最便宜的皮肤在槽位1），order
-- 字段为同价 tie-break，源下标兜底保证全等键稳定；price 缺失的皮肤排最后。
local function _sorted_by_price(source)
  local decorated = {}
  for index, skin in ipairs(source) do
    decorated[#decorated + 1] = { skin = skin, source_index = index }
  end
  table.sort(decorated, function(a, b)
    local price_a = a.skin.price
    local price_b = b.skin.price
    if price_a ~= price_b then
      return _price_before(price_a, price_b)
    end
    local order_a, order_b = a.skin.order or 0, b.skin.order or 0
    if order_a ~= order_b then
      return order_a < order_b
    end
    return a.source_index < b.source_index
  end)
  local sorted = {}
  for index, entry in ipairs(decorated) do
    sorted[index] = entry.skin
  end
  return sorted
end

function context.catalog()
  return _sorted_by_price(state.catalog)
end

function context.has_equip_adapter()
  return type(state.equip_adapter) == "function"
end

function context.has_unequip_adapter()
  return type(state.unequip_adapter) == "function"
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

function context.configure_transaction_result_applier(callback)
  _configure_callback("transaction_result_applier", callback, "invalid skin transaction result applier")
end

function context.call_transaction_result_applier(root_state, result)
  local applier = state.transaction_result_applier
  if type(applier) ~= "function" then
    return
  end
  local ok, err = pcall(applier, root_state, result)
  if not ok then
    logger.warn(
      "skin_panel: transaction result applier failed",
      tostring(err)
    )
  end
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
  state.transaction_result_applier = nil
end

return context

--[[ mutate4lua-manifest
version=4
projectHash=b18a64af6fc5907c
scope.0.id=chunk:src/app/cosmetics/transaction_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=146
scope.0.semanticHash=423bafe323c82000
scope.1.id=function:_price_before
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=22
scope.1.semanticHash=5e6205230c53c8e6
scope.2.id=function:_sorted_by_price
scope.2.kind=function
scope.2.startLine=26
scope.2.endLine=48
scope.2.semanticHash=ee4b18a8b6e0f441
scope.3.id=function:<anonymous>
scope.3.kind=function
scope.3.startLine=31
scope.3.endLine=42
scope.3.semanticHash=a7efa30ba0f8b605
scope.4.id=function:context.catalog
scope.4.kind=function
scope.4.startLine=50
scope.4.endLine=52
scope.4.semanticHash=92e2925d432737a5
scope.5.id=function:context.has_equip_adapter
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=56
scope.5.semanticHash=796e8c2b566e82be
scope.6.id=function:context.has_unequip_adapter
scope.6.kind=function
scope.6.startLine=58
scope.6.endLine=60
scope.6.semanticHash=796e8c2b566e82be
scope.7.id=function:context.archive_call
scope.7.kind=function
scope.7.startLine=62
scope.7.endLine=72
scope.7.semanticHash=d9dd0ebaf01129c8
scope.8.id=function:context.call_equip_adapter
scope.8.kind=function
scope.8.startLine=74
scope.8.endLine=80
scope.8.semanticHash=1f0b92ce4e334172
scope.9.id=function:context.call_unequip_adapter
scope.9.kind=function
scope.9.startLine=82
scope.9.endLine=95
scope.9.semanticHash=752b1410394940fa
scope.10.id=function:_configure_callback
scope.10.kind=function
scope.10.startLine=97
scope.10.endLine=100
scope.10.semanticHash=c77f6958775ee9c9
scope.11.id=function:context.configure_equip
scope.11.kind=function
scope.11.startLine=102
scope.11.endLine=104
scope.11.semanticHash=ace630a9a4e9c01e
scope.12.id=function:context.configure_unequip
scope.12.kind=function
scope.12.startLine=106
scope.12.endLine=108
scope.12.semanticHash=ace630a9a4e9c01e
scope.13.id=function:context.configure_transaction_result_applier
scope.13.kind=function
scope.13.startLine=110
scope.13.endLine=112
scope.13.semanticHash=ace630a9a4e9c01e
scope.14.id=function:context.call_transaction_result_applier
scope.14.kind=function
scope.14.startLine=114
scope.14.endLine=126
scope.14.semanticHash=55c1751b48f0d734
scope.15.id=function:context.configure_archive
scope.15.kind=function
scope.15.startLine=128
scope.15.endLine=131
scope.15.semanticHash=26b2bf33f62a2b4d
scope.16.id=function:context.configure_catalog_for_tests
scope.16.kind=function
scope.16.startLine=133
scope.16.endLine=135
scope.16.semanticHash=c5f5002820eefcbc
scope.17.id=function:context.reset_for_tests
scope.17.kind=function
scope.17.startLine=137
scope.17.endLine=143
scope.17.semanticHash=5af0a2c12b58eb20
]]
