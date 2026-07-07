-- Mutation-closure pins for src/turn/waits/choice_ui_sync.lua.
-- Drives sync_pending_choice_ui and resolve_missing_ui_warning directly with
-- stub ports so the id-change sync guard and the active/should-warn logic are
-- observable without the surrounding tick.
local support = require("spec.support.shared_support")
local _assert_eq = support.assert_eq

local choice_ui_sync = require("src.turn.waits.choice_ui_sync")

describe("waits.choice_ui_sync.sync_pending_choice_ui", function()
  it("does not re-sync when the active choice already matches the pending id", function()
    -- kills L7 get_pending_choice->nil and L8 ~=/==: a matching active choice
    -- must skip sync_pending_choice / on_pending_choice.
    local synced = {}
    local on_pending = {}
    local output_ports = {
      get_pending_choice = function() return { id = 1 } end,
      sync_pending_choice = function(_, choice) synced[#synced + 1] = choice end,
      clear_pending_choice = function() end,
    }
    local game = { turn = { pending_choice = { id = 1 } } }
    local opts = { on_pending_choice = function() on_pending[#on_pending + 1] = true end }
    choice_ui_sync.sync_pending_choice_ui(game, {}, opts, output_ports)
    _assert_eq(#synced, 0, "a matching active choice is not re-synced")
    _assert_eq(#on_pending, 0, "a matching active choice does not re-fire on_pending_choice")
  end)
end)

describe("waits.choice_ui_sync.resolve_missing_ui_warning", function()
  it("reports active with a pending choice but no active choice", function()
    -- kills L18 first ~=/== and or->and: a non-nil pending makes it active.
    -- also kills one L23 and->or arm: should_warn stays falsy without an
    -- active_choice.
    local active, should_warn = choice_ui_sync.resolve_missing_ui_warning(
      {}, {}, {}, { id = 1 }, nil, false)
    assert(active == true, "a pending choice alone marks the frame active")
    assert(not should_warn, "with no active_choice the missing-ui warning stays off")
  end)

  it("reports active with an active choice but no pending", function()
    -- kills L18 second ~=/==: a non-nil active_choice makes it active.
    local active = choice_ui_sync.resolve_missing_ui_warning({}, {}, {}, nil, { id = 1 }, false)
    assert(active == true, "an active choice alone marks the frame active")
  end)

  it("suppresses the warning when the ui already reports the choice active", function()
    -- kills the second L23 and->or arm: with ui_choice_active true the warning
    -- must be off.
    local _, should_warn = choice_ui_sync.resolve_missing_ui_warning(
      {}, {}, {}, { id = 1 }, { id = 1 }, true)
    assert(not should_warn, "an already-active ui suppresses the missing-ui warning")
  end)

  it("warns when a pending choice is active but the ui is not", function()
    -- kills L23 not->removed: the warning must fire when ui_choice_active is false.
    local _, should_warn = choice_ui_sync.resolve_missing_ui_warning(
      {}, {}, {}, { id = 1 }, { id = 1 }, false)
    assert(should_warn == true, "an active choice without ui coverage warns")
  end)
end)
