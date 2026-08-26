local actions = require("src.app.cosmetics.transaction_actions")
local transaction_context = require("src.app.cosmetics.transaction_context")

local transaction = {}

local function _sync_catalog()
  transaction.catalog = transaction_context.catalog()
end

function transaction.handle_skin_transaction(state, role_id, request)
  return actions.handle_skin_transaction(state, role_id, request)
end

function transaction.complete_skin_purchase(state, role_id, product_id)
  return actions.complete_skin_purchase(state, role_id, product_id)
end

function transaction.is_slot_equipped(state, slot_index)
  return actions.is_slot_equipped(state, slot_index)
end

function transaction.slot_view_model(state, slot_index)
  return actions.slot_view_model(state, slot_index)
end

function transaction.slot_view_models(state, catalog)
  return actions.slot_view_models(state, catalog)
end

function transaction.equipped_product(state, role_id)
  return actions.equipped_product(state, role_id)
end

function transaction.configure_equip(callback)
  transaction_context.configure_equip(callback)
end

function transaction.configure_unequip(callback)
  transaction_context.configure_unequip(callback)
end

function transaction.configure_transaction_result_applier(callback)
  transaction_context.configure_transaction_result_applier(callback)
end

function transaction.configure_archive(archive)
  transaction_context.configure_archive(archive)
end

function transaction.configure_catalog_for_tests(new_catalog)
  transaction_context.configure_catalog_for_tests(new_catalog)
  _sync_catalog()
end

-- #513：公开重新排序入口，供面板在 open 前刷新 catalog 快照（panel.sync_catalog 调用）。
function transaction.refresh_catalog()
  _sync_catalog()
end

function transaction.reset_for_tests()
  transaction_context.reset_for_tests()
  _sync_catalog()
end

_sync_catalog()

return transaction

--[[ mutate4lua-manifest
version=4
projectHash=935fc247464bf118
scope.0.id=chunk:src/app/cosmetics/transaction.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=68
scope.0.semanticHash=383ebeef839431cb
scope.1.id=function:_sync_catalog
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=c0ced4f451d835b1
scope.2.id=function:transaction.handle_skin_transaction
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=d590c542c8c308c5
scope.3.id=function:transaction.complete_skin_purchase
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=d590c542c8c308c5
scope.4.id=function:transaction.is_slot_equipped
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=20
scope.4.semanticHash=aba9250a8c6b104f
scope.5.id=function:transaction.slot_view_model
scope.5.kind=function
scope.5.startLine=22
scope.5.endLine=24
scope.5.semanticHash=aba9250a8c6b104f
scope.6.id=function:transaction.slot_view_models
scope.6.kind=function
scope.6.startLine=26
scope.6.endLine=28
scope.6.semanticHash=aba9250a8c6b104f
scope.7.id=function:transaction.equipped_product
scope.7.kind=function
scope.7.startLine=30
scope.7.endLine=32
scope.7.semanticHash=aba9250a8c6b104f
scope.8.id=function:transaction.configure_equip
scope.8.kind=function
scope.8.startLine=34
scope.8.endLine=36
scope.8.semanticHash=c772a22f8680e278
scope.9.id=function:transaction.configure_unequip
scope.9.kind=function
scope.9.startLine=38
scope.9.endLine=40
scope.9.semanticHash=c772a22f8680e278
scope.10.id=function:transaction.configure_transaction_result_applier
scope.10.kind=function
scope.10.startLine=42
scope.10.endLine=44
scope.10.semanticHash=c772a22f8680e278
scope.11.id=function:transaction.configure_archive
scope.11.kind=function
scope.11.startLine=46
scope.11.endLine=48
scope.11.semanticHash=c772a22f8680e278
scope.12.id=function:transaction.configure_catalog_for_tests
scope.12.kind=function
scope.12.startLine=50
scope.12.endLine=53
scope.12.semanticHash=e9e6dbe583e29db4
scope.13.id=function:transaction.refresh_catalog
scope.13.kind=function
scope.13.startLine=56
scope.13.endLine=58
scope.13.semanticHash=fa86f4a0c97ffab8
scope.14.id=function:transaction.reset_for_tests
scope.14.kind=function
scope.14.startLine=60
scope.14.endLine=63
scope.14.semanticHash=cc0fc664e9c192f4
]]
