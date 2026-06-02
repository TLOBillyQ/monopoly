--- e2e profile lane: boot each profile that carries an `expect` into a live
--- Eggy editor, drive its acting player's turn deterministically (seed=1), and
--- assert the observed state matches the profile's design-truth invariant.
---
--- This is an OPERATOR lane, not part of `make verify` / `make acceptance`.
--- Off-Windows or with the editor down it pends in full (it never reports a
--- false green). See spec/e2e/support/profile_driver.lua for the live boundary
--- and the e2e-profile-lane handoff for what still needs on-editor validation.
---
--- All judgment is delegated to the headless-proven reducer:
---   * lane.partition  -> which profiles run vs. are skipped-and-counted
---   * lane.observe     -> distil observed state (run inside the editor)
---   * lane.match       -> per-field comparison with descriptive failures
---   * lane.summarize   -> pass / fail / skip tally
local fixture = require("spec.e2e.support.editor_fixture")
local profile_driver = require("spec.e2e.support.profile_driver")
local lane = require("src.app.testing.e2e_profile_lane")
local resolver = require("src.app.testing.test_profile_resolver")

-- Forwarding closure so `pending` resolves at call-time (see connection_spec).
local hooks = fixture.bind({ pending = function(msg) pending(msg) end })

local function _drive_profile(client, name)
  local expect = resolver.expect_for(name)
  client.exec(profile_driver.boot_source(name))
  client.run_game()
  local ok, observed_or_err = pcall(profile_driver.observe_profile, client, expect, { seed = 1 })
  client.stop_game()
  if not ok then
    return { status = "failed" }, { name .. ": drive error -- " .. tostring(observed_or_err) }
  end
  local res = lane.match(name, observed_or_err, expect)
  return { status = res.ok and "passed" or "failed" }, res.failures
end

describe("e2e: profile lane", function()
  before_each(hooks.clean_logs)

  it("reproduces every expect-bearing profile's invariant on the live editor", function()
    hooks.skip_if_unavailable() -- pends off-Windows or when the editor is down

    local part = lane.partition(resolver)
    local client = hooks.client
    local results = {}
    local failures = {}

    for _, name in ipairs(part.runnable) do
      local result, profile_failures = _drive_profile(client, name)
      result.name = name
      results[#results + 1] = result
      for _, message in ipairs(profile_failures) do
        failures[#failures + 1] = message
      end
    end

    for _, name in ipairs(part.skipped) do
      results[#results + 1] = { name = name, status = "skipped" }
    end

    local counts = lane.summarize(results)

    -- Never let a skipped profile pass silently (the ADR 0015 false-green
    -- lesson): name every profile with no expect yet.
    if #part.skipped > 0 then
      print("# e2e profile lane skipped " .. #part.skipped ..
        " profile(s) with no expect yet: " .. table.concat(part.skipped, ", "))
    end
    print(string.format("# e2e profile lane summary: %d passed, %d failed, %d skipped",
      counts.passed, counts.failed, counts.skipped))

    assert(#failures == 0, "e2e profile lane failures:\n" .. table.concat(failures, "\n"))
    assert(counts.passed >= 1, "phase 1 expects solo_missile to pass; got 0 passing profiles")
  end)
end)
