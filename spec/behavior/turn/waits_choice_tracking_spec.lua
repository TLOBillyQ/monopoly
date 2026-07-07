-- Mutation-closure pins for src/turn/waits/choice_tracking.lua.
-- Drives sync_deadline_for_choice / sync_elapsed_choice_id against the real
-- deadlines service on a plain state so the scope selection, the other-scope
-- cancel, the start-when-inactive guard, and the id-change reset are observable.
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local choice_tracking = require("src.turn.waits.choice_tracking")
local deadlines = require("src.turn.deadlines")

describe("waits.choice_tracking.sync_deadline_for_choice scope", function()
  it("starts the market_buy deadline for a market_buy choice", function()
    -- kills L6 ==/~= and "market_buy"->nil: a market_buy choice must resolve the
    -- market_buy scope, not the default choice scope.
    local state = {}
    choice_tracking.sync_deadline_for_choice(state, { kind = "market_buy" }, 10)
    assert(deadlines.is_active(state, "market_buy") == true, "market_buy choice arms the market_buy scope")
    assert(deadlines.is_active(state, "choice") == false, "market_buy choice does not arm the choice scope")
  end)

  it("starts the choice deadline when the active choice is nil", function()
    -- kills L6 and->or: a nil active_choice must fall through to the choice
    -- scope; an `or` mutant would index nil.kind and error.
    local state = {}
    choice_tracking.sync_deadline_for_choice(state, nil, 10)
    assert(deadlines.is_active(state, "choice") == true, "a nil active choice arms the choice scope")
  end)
end)

describe("waits.choice_tracking.sync_deadline_for_choice other-scope cancel", function()
  it("cancels the market_buy scope while keeping choice for a choice-kind", function()
    -- kills L14 (==, "choice", and, "market_buy", or mutants) and L15
    -- is_active->nil: the non-matching scope must be canceled.
    local state = {}
    deadlines.start(state, "choice", { timeout_seconds = 10, priority = 100 })
    deadlines.start(state, "market_buy", { timeout_seconds = 10, priority = 100 })
    choice_tracking.sync_deadline_for_choice(state, { kind = "normal" }, 10)
    assert(deadlines.is_active(state, "market_buy") == false, "the other scope (market_buy) is canceled")
    assert(deadlines.is_active(state, "choice") == true, "the matching scope (choice) stays armed")
  end)

  it("cancels the choice scope while keeping market_buy for a market_buy-kind", function()
    -- kills L14 second "choice"->nil: with scope=market_buy the other_scope must
    -- resolve "choice" so the choice deadline is canceled.
    local state = {}
    deadlines.start(state, "choice", { timeout_seconds = 10, priority = 100 })
    deadlines.start(state, "market_buy", { timeout_seconds = 10, priority = 100 })
    choice_tracking.sync_deadline_for_choice(state, { kind = "market_buy" }, 10)
    assert(deadlines.is_active(state, "choice") == false, "the other scope (choice) is canceled")
    assert(deadlines.is_active(state, "market_buy") == true, "the matching scope (market_buy) stays armed")
  end)
end)

describe("waits.choice_tracking.sync_deadline_for_choice start guard", function()
  it("arms the deadline when the scope is not already active", function()
    -- kills L18 not->removed: an inactive scope must be started.
    local state = {}
    choice_tracking.sync_deadline_for_choice(state, { kind = "normal" }, 10)
    assert(deadlines.is_active(state, "choice") == true, "an inactive scope is armed")
  end)

  it("does not restart an already active deadline", function()
    -- kills L18 is_active(state, scope)->nil: an already-armed scope must be left
    -- untouched (its original timeout preserved), not restarted with the new one.
    local state = {}
    deadlines.start(state, "choice", { timeout_seconds = 10, priority = 100 })
    choice_tracking.sync_deadline_for_choice(state, { kind = "normal" }, 99)
    local peeked = deadlines.peek(state, "choice")
    _assert_eq(peeked.timeout_seconds, 10, "an active deadline keeps its original timeout (not restarted)")
  end)
end)

describe("waits.choice_tracking.sync_elapsed_choice_id", function()
  it("does not reset tracking when the pending id already matches", function()
    -- kills L38 get_pending_choice_id->nil and ~=/==: matching ids must skip the
    -- reset (no elapsed write, no id write).
    local elapsed_writes = {}
    local id_writes = {}
    local output_ports = {
      get_pending_choice_id = function() return "X" end,
      set_pending_choice_elapsed = function(_, value) elapsed_writes[#elapsed_writes + 1] = value end,
      set_pending_choice_id = function(_, value) id_writes[#id_writes + 1] = value end,
    }
    choice_tracking.sync_elapsed_choice_id({}, output_ports, { id = "X" })
    _assert_eq(#elapsed_writes, 0, "a matching pending id does not reset the elapsed timer")
    _assert_eq(#id_writes, 0, "a matching pending id does not rewrite the pending id")
  end)

  it("resets tracking when the pending id changes", function()
    -- companion positive case: a different active id must trigger the reset,
    -- confirming the guard's true branch is real.
    local elapsed_writes = {}
    local output_ports = {
      get_pending_choice_id = function() return "OLD" end,
      set_pending_choice_elapsed = function(_, value) elapsed_writes[#elapsed_writes + 1] = value end,
      set_pending_choice_id = function() end,
    }
    choice_tracking.sync_elapsed_choice_id({}, output_ports, { id = "NEW" })
    _assert_eq(elapsed_writes[1], 0, "a changed pending id resets the elapsed timer to 0")
  end)
end)
