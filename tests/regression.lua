-- Quick regression checks (run with: lua .agents/tests/regression.lua)
package.path = package.path
  .. ";./.agents/tests/?.lua;./.agents/tests/suites/?.lua;./.agents/tests/fixtures/?.lua"
  .. ";./tests/?.lua;./tests/suites/?.lua;./tests/fixtures/?.lua"

local suite_manifest = require("suites.manifest")

local function dofile_first(paths)
  for _, path in ipairs(paths) do
    local f = io.open(path, "r")
    if f then
      f:close()
      dofile(path)
      return
    end
  end
  error("missing internal script: " .. table.concat(paths, ", "))
end

local harness = require("TestHarness")

local function _contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function _has_vehicle_generated_content()
  local vehicles_cfg = require("Config.generated.vehicles")
  local market_cfg = require("Config.generated.market")
  local chance_cfg = require("Config.generated.chance_cards")
  if #vehicles_cfg > 0 then
    return true
  end
  for _, row in ipairs(market_cfg) do
    if row.kind == "vehicle" then
      return true
    end
  end
  for _, card in ipairs(chance_cfg) do
    if card.effect == "set_vehicle" then
      return true
    end
  end
  return false
end

local function _resolve_regression_mode()
  local raw = os.getenv("MONO_REGRESSION_MODE")
  local mode = (raw and raw ~= "") and raw or "auto"
  assert(
    mode == "auto" or mode == "dev" or mode == "release_trimmed",
    "invalid MONO_REGRESSION_MODE: " .. tostring(mode) .. " (expected auto|dev|release_trimmed)"
  )
  if mode == "auto" then
    if _has_vehicle_generated_content() then
      mode = "dev"
    else
      mode = "release_trimmed"
    end
  end
  return mode
end

local function _apply_release_trimmed_filters(suites)
  local disabled = {
    chance = {
      "chance_set_vehicle_ignored_when_feature_disabled",
      "chance_set_vehicle_works_when_feature_enabled",
      "chance_set_vehicle_invalid_id_ignored_when_feature_enabled",
    },
    config_sanity = {
      "config_sanity_fails_when_vehicle_reference_is_invalid",
    },
    ["gameplay.loop"] = {
      "_test_turn_move_anim_omits_vehicle_id_when_disabled",
      "_test_action_button_timeout_auto_advances",
    },
    ["presentation_ui.action_status"] = {
      "_test_status3d_priority_single_status",
    },
  }

  print("[regression] release_trimmed mode enabled; temporarily filtering vehicle-trimmed tests:")
  for suite_name, names in pairs(disabled) do
    print("[regression]   " .. suite_name .. ": " .. table.concat(names, ", "))
  end

  for _, suite in ipairs(suites) do
    local blocked = disabled[suite.name]
    if blocked and suite.tests then
      local kept = {}
      for _, test in ipairs(suite.tests) do
        if not _contains(blocked, test.name) then
          kept[#kept + 1] = test
        end
      end
      suite.tests = kept
    end
  end
end

local function load_suites(manifest)
  local suites = {}
  for _, module_name in ipairs(manifest) do
    suites[#suites + 1] = require(module_name)
  end
  return suites
end

local suites = load_suites(suite_manifest)

local mode = _resolve_regression_mode()
print("[regression] mode=" .. mode)
if mode == "release_trimmed" then
  _apply_release_trimmed_filters(suites)
end

harness.run_all(suites)
dofile_first({".agents/tests/internal/dep_rules.lua", "tests/internal/dep_rules.lua"})
dofile_first({
  ".agents/tests/internal/legacy_path_guard.lua",
  "tests/internal/legacy_path_guard.lua",
})
dofile_first({
  ".agents/tests/internal/gameplay_loop_no_ui.lua",
  "tests/internal/gameplay_loop_no_ui.lua",
})
dofile_first({
  ".agents/tests/internal/forbidden_globals.lua",
  "tests/internal/forbidden_globals.lua",
})
dofile_first({
  ".agents/tests/internal/arch_view_guard.lua",
  "tests/internal/arch_view_guard.lua",
})
