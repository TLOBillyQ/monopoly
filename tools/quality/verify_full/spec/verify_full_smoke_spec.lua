---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/verify_full/spec/verify_full_smoke_spec.lua") end
require("spec.bootstrap").install_package_paths()

local verify_full = require("quality.verify_full")

-- _resolve_lanes(opts) is a pure helper extracted from _main per architect's
-- plan-verify-skill-consolidation. Contract:
--   opts = {
--     smoke?    = boolean,   -- subset for human iteration
--     tooling?  = boolean,   -- include tooling profile parallel
--     coverage? = boolean,   -- default false; true to include
--     crap?     = boolean,   -- default false; true to include
--     full?     = boolean,   -- alias for --coverage --crap
--     env       = {
--       lua54_bin          = string|nil,
--       busted_bin         = string|nil,
--       luacheck_available = boolean,
--       coverage_available = boolean,
--     },
--   }
--   returns { lanes = { {label=..., cmd=...}, ... },
--             skipped  = {labels...},
--             warnings = {strings...} }

local function _labels(lanes)
  local out = {}
  for i, lane in ipairs(lanes) do
    out[i] = lane.label
  end
  return out
end

local function _has(set, label)
  for _, v in ipairs(set) do
    if v == label then return true end
  end
  return false
end

-- Sentinel for "set this env field to nil" — pairs() skips nil values so a
-- table literal {lua54_bin = nil} is indistinguishable from {}, which would
-- silently keep the default.
local ABSENT = {}
local function _env(over)
  local e = {
    lua54_bin = "/opt/homebrew/bin/lua5.4",
    busted_bin = "/opt/homebrew/bin/busted",
    luacheck_available = true,
    coverage_available = true,
  }
  for k, v in pairs(over or {}) do
    if v == ABSENT then e[k] = nil else e[k] = v end
  end
  return e
end

describe("verify_full._resolve_lanes — default (ADR 0006 D6 slim)", function()
  it("emits the canonical 6-lane set when env is complete", function()
    local plan = verify_full._resolve_lanes({ env = _env() })
    local labels = _labels(plan.lanes)
    -- Set membership (order is implementation detail).
    for _, expected in ipairs({
      "contract", "guards", "arch", "behavior", "lint", "encoding",
    }) do
      assert.is_true(_has(labels, expected),
        "default profile missing lane: " .. expected)
    end
    -- Long-running lanes are opt-in (refactorer/architect owns them).
    assert.is_false(_has(labels, "coverage"),
      "default profile must not include coverage lane")
    assert.is_false(_has(labels, "crap_collect"),
      "default profile must not include crap_collect lane")
    -- Tooling is opt-in; never present without --tooling.
    assert.is_false(_has(labels, "tooling"))
    -- behavior-smoke is the SMOKE-only label; default uses "behavior".
    assert.is_false(_has(labels, "behavior-smoke"))
  end)

  it("skips lint when luacheck unavailable and reports it", function()
    local plan = verify_full._resolve_lanes({ env = _env({ luacheck_available = false }) })
    assert.is_false(_has(_labels(plan.lanes), "lint"))
    assert.is_true(_has(plan.skipped, "lint"))
  end)

  it("skips coverage silently by default even when toolchain is available", function()
    local plan = verify_full._resolve_lanes({ env = _env() })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    assert.is_false(_has(plan.skipped, "coverage"))
  end)

  it("includes coverage when explicitly requested and toolchain is available", function()
    local plan = verify_full._resolve_lanes({ coverage = true, env = _env() })
    assert.is_true(_has(_labels(plan.lanes), "coverage"))
  end)

  it("warns and skips coverage when requested but lua54_bin missing", function()
    local plan = verify_full._resolve_lanes({ coverage = true, env = _env({ lua54_bin = ABSENT }) })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    assert.is_true(_has(plan.skipped, "coverage"))
    local found_warning = false
    for _, w in ipairs(plan.warnings or {}) do
      if w:find("coverage toolchain is unavailable", 1, true) then
        found_warning = true
        break
      end
    end
    assert.is_true(found_warning,
      "expected warning about unavailable coverage toolchain, got: "
        .. table.concat(plan.warnings or {}, " | "))
  end)

  it("warns and skips coverage when requested but luacov toolchain is unavailable", function()
    local plan = verify_full._resolve_lanes({ coverage = true, env = _env({ coverage_available = false }) })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    assert.is_true(_has(plan.skipped, "coverage"))
    local found_warning = false
    for _, w in ipairs(plan.warnings or {}) do
      if w:find("coverage toolchain is unavailable", 1, true) then
        found_warning = true
        break
      end
    end
    assert.is_true(found_warning)
  end)

  it("appends tooling lane only when opts.tooling is true", function()
    local plan = verify_full._resolve_lanes({ tooling = true, env = _env() })
    local tooling_lane
    for _, lane in ipairs(plan.lanes) do
      if lane.label == "tooling" then
        tooling_lane = lane
        break
      end
    end
    assert.is_not_nil(tooling_lane)
    assert.is_truthy(tooling_lane.cmd:find("--profile tooling", 1, true))
  end)

  it("passes busted path through --busted-bin instead of shell env assignment", function()
    local plan = verify_full._resolve_lanes({ env = _env({ busted_bin = "custom-busted" }) })
    local contract_lane
    for _, lane in ipairs(plan.lanes) do
      if lane.label == "contract" then
        contract_lane = lane
        break
      end
    end
    assert.is_not_nil(contract_lane)
    assert.is_truthy(contract_lane.cmd:find("--busted-bin", 1, true))
    assert.is_truthy(contract_lane.cmd:find("custom%-busted"))
    assert.is_nil(contract_lane.cmd:find("BUSTED_BIN=", 1, true))
  end)

  it("--no-coverage is a silent no-op (coverage already opt-out by default)", function()
    local plan = verify_full._resolve_lanes({ coverage = false, env = _env() })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    assert.is_false(_has(plan.skipped, "coverage"))
    for _, w in ipairs(plan.warnings or {}) do
      assert.is_false(w:find("coverage", 1, true) ~= nil,
        "--no-coverage must not warn, got: " .. w)
    end
  end)
end)

describe("verify_full._resolve_lanes — opt-in long lanes", function()
  it("includes crap_collect when opts.crap is true", function()
    local plan = verify_full._resolve_lanes({ crap = true, env = _env() })
    assert.is_true(_has(_labels(plan.lanes), "crap_collect"))
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
  end)

  it("--full restores old default (coverage + crap_collect)", function()
    local plan = verify_full._resolve_lanes({ full = true, env = _env() })
    local labels = _labels(plan.lanes)
    assert.is_true(_has(labels, "coverage"))
    assert.is_true(_has(labels, "crap_collect"))
    assert.is_true(_has(labels, "behavior"))
  end)

  it("--full overrides an explicit --no-coverage", function()
    local plan = verify_full._resolve_lanes({ full = true, coverage = false, env = _env() })
    assert.is_true(_has(_labels(plan.lanes), "coverage"))
  end)
end)

describe("verify_full._resolve_lanes — smoke profile", function()
  it("returns exactly {lint, encoding, guards, arch, behavior-smoke, contract}", function()
    local plan = verify_full._resolve_lanes({ smoke = true, env = _env() })
    local labels = _labels(plan.lanes)
    table.sort(labels)
    assert.are.same(
      { "arch", "behavior-smoke", "contract", "encoding", "guards", "lint" },
      labels
    )
  end)

  it("uses behavior-smoke label, not behavior", function()
    local plan = verify_full._resolve_lanes({ smoke = true, env = _env() })
    local labels = _labels(plan.lanes)
    assert.is_true(_has(labels, "behavior-smoke"))
    assert.is_false(_has(labels, "behavior"))
  end)

  it("excludes crap_collect / coverage / tooling unconditionally", function()
    local plan = verify_full._resolve_lanes({ smoke = true, env = _env() })
    local labels = _labels(plan.lanes)
    for _, banned in ipairs({ "crap_collect", "coverage", "tooling" }) do
      assert.is_false(_has(labels, banned),
        "smoke profile must not include lane: " .. banned)
    end
  end)

  it("skips lint when luacheck unavailable (mirrors default policy)", function()
    local plan = verify_full._resolve_lanes({ smoke = true, env = _env({ luacheck_available = false }) })
    assert.is_false(_has(_labels(plan.lanes), "lint"))
    assert.is_true(_has(plan.skipped, "lint"))
  end)
end)

describe("verify_full._resolve_lanes — conflict-flag rules", function()
  it("--smoke + --tooling: smoke wins, warning emitted, no tooling lane", function()
    local plan = verify_full._resolve_lanes({ smoke = true, tooling = true, env = _env() })
    assert.is_false(_has(_labels(plan.lanes), "tooling"),
      "smoke must override tooling")
    local found_warning = false
    for _, w in ipairs(plan.warnings or {}) do
      if w:find("tooling", 1, true) and w:find("smoke", 1, true) then
        found_warning = true
        break
      end
    end
    assert.is_true(found_warning,
      "expected warning mentioning 'tooling' + 'smoke', got: "
        .. table.concat(plan.warnings or {}, " | "))
  end)

  it("--smoke + --no-coverage: silent no-op, no warning", function()
    local plan = verify_full._resolve_lanes({ smoke = true, coverage = false, env = _env() })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    for _, w in ipairs(plan.warnings or {}) do
      assert.is_false(w:find("coverage", 1, true) ~= nil,
        "smoke + no-coverage must not warn, got: " .. w)
    end
  end)

  it("--smoke + --full: smoke wins, no coverage/crap_collect lanes", function()
    local plan = verify_full._resolve_lanes({ smoke = true, full = true, env = _env() })
    local labels = _labels(plan.lanes)
    assert.is_false(_has(labels, "coverage"))
    assert.is_false(_has(labels, "crap_collect"))
  end)
end)

describe("verify_full module loading", function()
  it("does not require HOME to be set", function()
    local previous_module = package.loaded["quality.verify_full"]
    local original_getenv = os.getenv
    package.loaded["quality.verify_full"] = nil
    -- luacheck: push ignore 122
    os.getenv = function(name)
      if name == "HOME" then
        return nil
      end
      return original_getenv(name)
    end

    local ok, loaded = pcall(require, "quality.verify_full")

    os.getenv = original_getenv
    -- luacheck: pop
    package.loaded["quality.verify_full"] = previous_module
    assert.is_true(ok, tostring(loaded))
  end)
end)
