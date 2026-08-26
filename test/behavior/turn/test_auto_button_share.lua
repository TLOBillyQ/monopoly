local lu = require("luaunit")
local support = require("test.support.shared_support")
local runtime_ports = require("src.foundation.ports.runtime_ports")
local action_dispatcher = require("src.turn.actions.action_dispatcher")
local control = require("src.player.control")

TestAutoButtonShare = {}

local function _state()
  return {
    gameplay_loop_ports = {
      output = {
        invalidate_ui_model = function() end,
      },
      ui_sync = {
        get_ui_state = function() return nil end,
        resolve_ui_gate = function() return nil end,
      },
      clock = {
        wall_now_seconds = function() return 0 end,
        wall_diff_seconds = function(a, b) return a - b end,
      },
    },
  }
end

local function _toggle(player, role)
  local shown = false
  if role == true then
    role = {
      show_map_share_panel = function()
        shown = true
      end,
    }
  end
  runtime_ports.configure({ resolve_role = function() return role end })
  local game = {
    turn = { phase = "wait_action", current_player_index = 1 },
    players = { player },
    find_player_by_id = function(_, role_id)
      return role_id == player.id and player or nil
    end,
  }
  local result = action_dispatcher.dispatch_action(game, _state(), {
    type = "ui_button",
    id = "auto",
    actor_role_id = player.id,
  })
  return result, shown
end

function TestAutoButtonShare:setUp()
  runtime_ports.reset_for_tests()
end

function TestAutoButtonShare:tearDown()
  support.restore_runtime_services()
end

function TestAutoButtonShare:test_first_auto_on_toggle_shows_and_latches_share_panel()
  local player = { id = 1, auto_share_panel_shown = false }
  control.initialize(player)

  local result, shown = _toggle(player, true)

  lu.assertEquals(result, { status = "applied" })
  lu.assertTrue(control.is_delegated(player))
  lu.assertFalse(control.is_afk_delegated(player))
  lu.assertTrue(shown)
  lu.assertTrue(player.auto_share_panel_shown)
end

function TestAutoButtonShare:test_auto_off_never_shows_or_latches_share_panel()
  local player = { id = 1, auto_share_panel_shown = false }
  control.initialize(player)
  control.toggle_manual_delegation(player)

  local result, shown = _toggle(player, true)

  lu.assertEquals(result, { status = "applied" })
  lu.assertFalse(control.is_delegated(player))
  lu.assertFalse(shown)
  lu.assertFalse(player.auto_share_panel_shown)
end

function TestAutoButtonShare:test_unresolved_role_does_not_latch_share_panel()
  local player = { id = 1, auto_share_panel_shown = false }
  control.initialize(player)

  local result, shown = _toggle(player, nil)

  lu.assertEquals(result, { status = "applied" })
  lu.assertTrue(control.is_delegated(player))
  lu.assertFalse(shown)
  lu.assertFalse(player.auto_share_panel_shown)
end

function TestAutoButtonShare:test_host_error_does_not_escape_or_latch_share_panel()
  local player = { id = 1, auto_share_panel_shown = false }
  control.initialize(player)
  local role = {
    show_map_share_panel = function()
      error("host exploded")
    end,
  }

  local result, shown = _toggle(player, role)

  lu.assertEquals(result, { status = "applied" })
  lu.assertTrue(control.is_delegated(player))
  lu.assertFalse(shown)
  lu.assertFalse(player.auto_share_panel_shown)
end

return TestAutoButtonShare
