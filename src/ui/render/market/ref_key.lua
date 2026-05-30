local number_utils = require("src.foundation.number")

local M = {}

function M.resolve(refs, key)
  if number_utils.is_numeric(key) then
    return key
  end
  return refs[key]
end

return M

--[[ mutate4lua-manifest
version=2
projectHash=be0dcf2b74d5f55b
scope.0.id=chunk:src/ui/render/market/ref_key.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=13
scope.0.semanticHash=278198e5ec04925a
scope.1.id=function:M.resolve:5
scope.1.kind=function
scope.1.startLine=5
scope.1.endLine=10
scope.1.semanticHash=ec9ecb7939e073ef
]]
