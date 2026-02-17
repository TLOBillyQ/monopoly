local legacy = require("TestSupport")
local patch = require("support.patch")

local M = {}

for key, value in pairs(legacy) do
  M[key] = value
end

M.with_patches = patch.with_patches

return M
