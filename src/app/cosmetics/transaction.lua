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

function transaction.configure_equip(callback)
  transaction_context.configure_equip(callback)
end

function transaction.configure_unequip(callback)
  transaction_context.configure_unequip(callback)
end

function transaction.configure_purchase(callback)
  transaction_context.configure_purchase(callback)
end

function transaction.configure_archive(archive)
  transaction_context.configure_archive(archive)
end

function transaction.configure_catalog_for_tests(new_catalog)
  transaction_context.configure_catalog_for_tests(new_catalog)
  _sync_catalog()
end

function transaction.reset_for_tests()
  transaction_context.reset_for_tests()
  _sync_catalog()
end

_sync_catalog()

return transaction

--[[ mutate4lua-manifest
version=2
projectHash=af16a8d71026f1af
scope.0.id=chunk:src/app/cosmetics/transaction.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=51
scope.0.semanticHash=3ffb9cd4a5cd90ba
scope.0.lastMutatedAt=2026-06-24T16:19:01Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=3
scope.0.lastMutationKilled=3
scope.1.id=function:_sync_catalog:6
scope.1.kind=function
scope.1.startLine=6
scope.1.endLine=8
scope.1.semanticHash=d2d9117d89eaf70d
scope.1.lastMutatedAt=2026-06-24T16:19:01Z
scope.1.lastMutationLane=behavior
scope.1.lastMutationStatus=passed
scope.1.lastMutationSites=1
scope.1.lastMutationKilled=1
scope.2.id=function:transaction.handle_skin_transaction:10
scope.2.kind=function
scope.2.startLine=10
scope.2.endLine=12
scope.2.semanticHash=769573a523c4baa3
scope.2.lastMutatedAt=2026-06-24T16:19:01Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
scope.3.id=function:transaction.complete_skin_purchase:14
scope.3.kind=function
scope.3.startLine=14
scope.3.endLine=16
scope.3.semanticHash=a75ef4f4730881df
scope.3.lastMutatedAt=2026-06-24T16:19:01Z
scope.3.lastMutationLane=behavior
scope.3.lastMutationStatus=passed
scope.3.lastMutationSites=1
scope.3.lastMutationKilled=1
scope.4.id=function:transaction.is_slot_equipped:18
scope.4.kind=function
scope.4.startLine=18
scope.4.endLine=20
scope.4.semanticHash=9d57ef32b9fe9893
scope.4.lastMutatedAt=2026-06-24T16:19:01Z
scope.4.lastMutationLane=behavior
scope.4.lastMutationStatus=passed
scope.4.lastMutationSites=1
scope.4.lastMutationKilled=1
scope.5.id=function:transaction.configure_equip:22
scope.5.kind=function
scope.5.startLine=22
scope.5.endLine=24
scope.5.semanticHash=416bd6d11846055e
scope.5.lastMutatedAt=2026-06-24T16:19:01Z
scope.5.lastMutationLane=behavior
scope.5.lastMutationStatus=passed
scope.5.lastMutationSites=1
scope.5.lastMutationKilled=1
scope.6.id=function:transaction.configure_unequip:26
scope.6.kind=function
scope.6.startLine=26
scope.6.endLine=28
scope.6.semanticHash=948790c39aff02d0
scope.6.lastMutatedAt=2026-06-24T16:19:01Z
scope.6.lastMutationLane=behavior
scope.6.lastMutationStatus=passed
scope.6.lastMutationSites=1
scope.6.lastMutationKilled=1
scope.7.id=function:transaction.configure_purchase:30
scope.7.kind=function
scope.7.startLine=30
scope.7.endLine=32
scope.7.semanticHash=81fa28af7187d9e4
scope.7.lastMutatedAt=2026-06-24T16:19:01Z
scope.7.lastMutationLane=behavior
scope.7.lastMutationStatus=passed
scope.7.lastMutationSites=1
scope.7.lastMutationKilled=1
scope.8.id=function:transaction.configure_archive:34
scope.8.kind=function
scope.8.startLine=34
scope.8.endLine=36
scope.8.semanticHash=a4b1f5ec2d0f7ce8
scope.8.lastMutatedAt=2026-06-24T16:19:01Z
scope.8.lastMutationLane=behavior
scope.8.lastMutationStatus=passed
scope.8.lastMutationSites=1
scope.8.lastMutationKilled=1
scope.9.id=function:transaction.configure_catalog_for_tests:38
scope.9.kind=function
scope.9.startLine=38
scope.9.endLine=41
scope.9.semanticHash=49e691a1163c1dd5
scope.9.lastMutatedAt=2026-06-24T16:19:01Z
scope.9.lastMutationLane=behavior
scope.9.lastMutationStatus=passed
scope.9.lastMutationSites=2
scope.9.lastMutationKilled=2
scope.10.id=function:transaction.reset_for_tests:43
scope.10.kind=function
scope.10.startLine=43
scope.10.endLine=46
scope.10.semanticHash=617436362b41adf5
scope.10.lastMutatedAt=2026-06-24T16:19:01Z
scope.10.lastMutationLane=behavior
scope.10.lastMutationStatus=passed
scope.10.lastMutationSites=2
scope.10.lastMutationKilled=2
]]
