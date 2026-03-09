require("tests.bootstrap")

local shared = require("support.shared_support")
local domain_support = require("support.domain_support")
local gameplay_support = require("support.gameplay_support")
local presentation_support = require("support.presentation_support")
local runtime_support = require("support.runtime_support")

local M = {}

for _, module in ipairs({
  domain_support,
  gameplay_support,
  presentation_support,
  runtime_support,
}) do
  for key, value in pairs(module) do
    M[key] = value
  end
end

-- Deprecated: prefer support.ensure_ui_runtime_for_test or
-- support.migrate_legacy_ui_state_for_test from the layer-specific modules.
M.bind_ui_runtime = shared.migrate_legacy_ui_state_for_test
M.ensure_ui_runtime_for_test = shared.ensure_ui_runtime_for_test
M.migrate_legacy_ui_state_for_test = shared.migrate_legacy_ui_state_for_test

return M
