local bootstrap = require("tests.bootstrap")
local catalog = require("tests.catalog")
local harness = require("TestHarness")

local M = {}

local function _resolve_mode()
  local raw = os.getenv("MONO_REGRESSION_MODE")
  local mode = (raw and raw ~= "") and raw or "auto"
  assert(
    mode == "auto" or mode == "dev" or mode == "release_trimmed",
    "invalid MONO_REGRESSION_MODE: " .. tostring(mode) .. " (expected auto|dev|release_trimmed)"
  )
  if mode ~= "auto" then
    return mode
  end

  local vehicles_cfg = require("Config.generated.vehicles")
  local market_cfg = require("Config.generated.market")
  local chance_cfg = require("Config.generated.chance_cards")
  if #vehicles_cfg > 0 then
    return "dev"
  end
  for _, row in ipairs(market_cfg) do
    if row.kind == "vehicle" then
      return "dev"
    end
  end
  for _, card in ipairs(chance_cfg) do
    if card.effect == "set_vehicle" then
      return "dev"
    end
  end
  return "release_trimmed"
end

function M.run(opts)
  bootstrap.install_package_paths()
  local mode = (opts and opts.mode) or _resolve_mode()
  print("[behavior] mode=" .. mode)
  return harness.run_all(catalog.load_behavior_suites(), {
    mode = mode,
    capture_logs = true,
  })
end

function M.main()
  M.run()
end

if ... == nil then
  M.main()
else
  return M
end
