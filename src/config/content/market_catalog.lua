local market_cfg = require("src.config.content.market")

local market_catalog = {}

local _entries_by_id
local _entries_by_id_len

local function _ensure_entries_by_id()
  local cfg_len = #market_cfg
  if _entries_by_id and _entries_by_id_len == cfg_len then
    return _entries_by_id
  end
  _entries_by_id_len = cfg_len
  _entries_by_id = {}
  local first_index_by_id = {}
  for index, entry in ipairs(market_cfg) do
    local product_id = entry and entry.product_id or nil
    if product_id ~= nil then
      local first_index = first_index_by_id[product_id]
      assert(
        first_index == nil,
        "duplicate market product_id: "
          .. tostring(product_id)
          .. " (first_index="
          .. tostring(first_index)
          .. ", duplicate_index="
          .. tostring(index)
          .. ")"
      )
      first_index_by_id[product_id] = index
      _entries_by_id[product_id] = entry
    end
  end
  return _entries_by_id
end

function market_catalog.entries()
  return market_cfg
end

function market_catalog.entry_by_id(product_id)
  return _ensure_entries_by_id()[product_id]
end

return market_catalog

--[[ mutate4lua-manifest
version=2
projectHash=59c5150df875bd4c
scope.0.id=chunk:src/config/content/market_catalog.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=46
scope.0.semanticHash=77ece784094b3107
scope.0.lastMutatedAt=2026-07-07T03:19:56Z
scope.0.lastMutationLane=behavior
scope.0.lastMutationStatus=passed
scope.0.lastMutationSites=8
scope.0.lastMutationKilled=8
scope.1.id=function:market_catalog.entries:37
scope.1.kind=function
scope.1.startLine=37
scope.1.endLine=39
scope.1.semanticHash=4aba37d7e123f4dc
scope.2.id=function:market_catalog.entry_by_id:41
scope.2.kind=function
scope.2.startLine=41
scope.2.endLine=43
scope.2.semanticHash=7cd7f8a85b79c3be
scope.2.lastMutatedAt=2026-07-07T03:19:56Z
scope.2.lastMutationLane=behavior
scope.2.lastMutationStatus=passed
scope.2.lastMutationSites=1
scope.2.lastMutationKilled=1
]]
