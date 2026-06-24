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

--[[ mutate4lua-manifest
version=2
projectHash=1e5e8921b2f5f481
scope.0.id=chunk:src/app/cosmetics/transaction_context.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=100
scope.0.semanticHash=b80d641dbaf0b1fa
scope.0.lastMutatedAt=2026-06-24T16:17:44Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=2
scope.0.lastMutationKilled=2
scope.1.id=function:context.catalog:14
scope.1.kind=function
scope.1.startLine=14
scope.1.endLine=16
scope.1.semanticHash=64aecf12f8f5334b
scope.1.lastMutatedAt=2026-06-24T16:17:44Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=no_sites
scope.1.lastMutationSites=0
scope.1.lastMutationKilled=0
scope.2.id=function:context.has_equip_adapter:18
scope.2.kind=function
scope.2.startLine=18
scope.2.endLine=20
scope.2.semanticHash=2c807a4eff40efc5
scope.2.lastMutatedAt=2026-06-24T16:17:44Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=3
scope.2.lastMutationKilled=3
scope.3.id=function:context.has_unequip_adapter:22
scope.3.kind=function
scope.3.startLine=22
scope.3.endLine=24
scope.3.semanticHash=df3aa3ff3a9730c1
scope.3.lastMutatedAt=2026-06-24T16:17:44Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=3
scope.3.lastMutationKilled=3
scope.4.id=function:context.purchase_adapter:26
scope.4.kind=function
scope.4.startLine=26
scope.4.endLine=28
scope.4.semanticHash=10dc181172a5d94d
scope.4.lastMutatedAt=2026-06-24T16:17:44Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=no_sites
scope.4.lastMutationSites=0
scope.4.lastMutationKilled=0
scope.5.id=function:context.archive_call:30
scope.5.kind=function
scope.5.startLine=30
scope.5.endLine=40
scope.5.semanticHash=8e4df79abece307b
scope.5.lastMutatedAt=2026-06-24T16:17:44Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=8
scope.5.lastMutationKilled=8
scope.6.id=function:context.call_equip_adapter:42
scope.6.kind=function
scope.6.startLine=42
scope.6.endLine=48
scope.6.semanticHash=deeabd090943234c
scope.6.lastMutatedAt=2026-06-24T16:17:44Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=7
scope.6.lastMutationKilled=7
scope.7.id=function:context.call_unequip_adapter:50
scope.7.kind=function
scope.7.startLine=50
scope.7.endLine=63
scope.7.semanticHash=4b59d6df4bc6d129
scope.7.lastMutatedAt=2026-06-24T16:17:44Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=4
scope.7.lastMutationKilled=4
scope.8.id=function:_configure_callback:65
scope.8.kind=function
scope.8.startLine=65
scope.8.endLine=68
scope.8.semanticHash=a10f42a5e8894192
scope.8.lastMutatedAt=2026-06-24T16:17:44Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:context.configure_equip:70
scope.9.kind=function
scope.9.startLine=70
scope.9.endLine=72
scope.9.semanticHash=635ecca3c6c9aa46
scope.9.lastMutatedAt=2026-06-24T16:17:44Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=1
scope.9.lastMutationKilled=1
scope.10.id=function:context.configure_unequip:74
scope.10.kind=function
scope.10.startLine=74
scope.10.endLine=76
scope.10.semanticHash=6846c53868d46133
scope.10.lastMutatedAt=2026-06-24T16:17:44Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=1
scope.10.lastMutationKilled=1
scope.11.id=function:context.configure_purchase:78
scope.11.kind=function
scope.11.startLine=78
scope.11.endLine=80
scope.11.semanticHash=4fd86c2a63012a1f
scope.11.lastMutatedAt=2026-06-24T16:17:44Z
scope.11.lastMutationLane=behavior
scope.11.lastMutationStatus=passed
scope.11.lastMutationSites=1
scope.11.lastMutationKilled=1
scope.12.id=function:context.configure_archive:82
scope.12.kind=function
scope.12.startLine=82
scope.12.endLine=85
scope.12.semanticHash=47602fd59afca76d
scope.12.lastMutatedAt=2026-06-24T16:17:44Z
scope.12.lastMutationLane=behavior
scope.12.lastMutationStatus=passed
scope.12.lastMutationSites=1
scope.12.lastMutationKilled=1
scope.13.id=function:context.configure_catalog_for_tests:87
scope.13.kind=function
scope.13.startLine=87
scope.13.endLine=89
scope.13.semanticHash=bf93fdc5a76e32eb
scope.13.lastMutatedAt=2026-06-24T16:17:44Z
scope.13.lastMutationLane=behavior
scope.13.lastMutationStatus=passed
scope.13.lastMutationSites=1
scope.13.lastMutationKilled=1
scope.14.id=function:context.reset_for_tests:91
scope.14.kind=function
scope.14.startLine=91
scope.14.endLine=97
scope.14.semanticHash=b1a75b1769029133
scope.14.lastMutatedAt=2026-06-24T16:17:44Z
scope.14.lastMutationLane=behavior
scope.14.lastMutationStatus=no_sites
scope.14.lastMutationSites=0
scope.14.lastMutationKilled=0
]]
