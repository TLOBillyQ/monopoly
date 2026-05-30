---@diagnostic disable: undefined-global
if arg then rawset(arg, 0, "tools/quality/verify_full/spec/verify_full_smoke_spec.lua") end
require("spec.bootstrap").install_package_paths()

local verify_full = require("quality.verify_full")

-- _resolve_lanes(opts) is a pure helper extracted from _main per architect's
-- plan-verify-skill-consolidation. Contract:
--   opts = {
--     smoke?    = boolean,   -- subset for human iteration
--     tooling?  = boolean,   -- include tooling profile parallel
--     coverage? = boolean,   -- default true; false to skip
--     env       = {
--       lua54_bin          = string|nil,
--       busted_bin         = string|nil,
--       luacheck_available = boolean,
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
  }
  for k, v in pairs(over or {}) do
    if v == ABSENT then e[k] = nil else e[k] = v end
  end
  return e
end

describe("verify_full._resolve_lanes — default (parity with pre-cycle)", function()
  it("emits the canonical 8-lane set when env is complete", function()
    local plan = verify_full._resolve_lanes({ env = _env() })
    local labels = _labels(plan.lanes)
    -- Set membership (order is implementation detail).
    for _, expected in ipairs({
      "contract", "guards", "arch", "behavior",
      "crap_collect", "lint", "encoding",
    }) do
      assert.is_true(_has(labels, expected),
        "default profile missing lane: " .. expected)
    end
    -- Coverage runs in default unless --no-coverage flips it.
    assert.is_true(_has(labels, "coverage"),
      "default profile must include coverage lane")
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

  it("skips coverage when lua54_bin missing and reports it", function()
    local plan = verify_full._resolve_lanes({ env = _env({ lua54_bin = ABSENT }) })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    assert.is_true(_has(plan.skipped, "coverage"))
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

  it("excludes coverage when opts.coverage == false", function()
    local plan = verify_full._resolve_lanes({ coverage = false, env = _env() })
    assert.is_false(_has(_labels(plan.lanes), "coverage"))
    -- Not a "skip" — explicit opt-out is silent.
    assert.is_false(_has(plan.skipped, "coverage"))
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
end)
