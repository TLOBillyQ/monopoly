-- Pins the real turn-start pre-action item phase against the main turn buttons.
--
-- The specifier flagged that the real runtime opens a pre_action item_phase_passive
-- choice at turn start (start.lua -> item_phase.run), which used to render the 结束
-- button instead of 行动 while a pre-action card was still in the bag. The legacy
-- acceptance sim cannot catch this (it never builds a real pre_action pending choice), so this
-- spec drives the real choice data through the same UI slice the runtime uses.

local lu = require("luaunit")
local support = require("test.support.shared_support")
local _assert_eq = support.assert_eq
local compose_game = require("src.app.compose_game")
local default_ports = require("src.turn.output.default_ports")
local item_phase = require("src.rules.items.phase")
local item_ids = require("src.config.gameplay.item_ids")
local choice_builder = require("src.ui.view.choice_builder")
local panel_controls = require("src.ui.render.widgets.panel_controls")
local route_base = require("src.ui.input.route_base")
local base_nodes = require("src.ui.schema.base")

local map_cfg = require("src.config.content.default_map")
local tiles_cfg = require("src.config.content.tiles")

local function _new_game()
  return compose_game.new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2" },
    ai = {},
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
end

local function _open_pre_action_choice()
  local g = _new_game()
  local player = g:current_player()
  player.inventory:add({ id = item_ids.remote_dice })

  local phase_res = item_phase.run({ game = g }, "pre_action", {
    player = player,
    next_state = "roll",
    next_args = { player = player },
  })
  lu.assertEvalToTrue(type(phase_res) == "table" and phase_res.waiting == true,
    "pre_action passive should wait on the item choice")
  local pending = assert(g.turn.pending_choice, "pre_action passive should open a pending choice")
  return g, pending
end

TestMainTurnPreActionButton = {}

function TestMainTurnPreActionButton:test_real_pre_action_pending_choice_tags_the_pre_action_phase()
  local _, pending = _open_pre_action_choice()

  _assert_eq(pending.kind, "item_phase_passive", "pre_action choice should be an item phase passive choice")
  lu.assertEvalToTrue(type(pending.meta) == "table" and pending.meta.phase == "pre_action",
    "pre_action pending choice should carry meta.phase == pre_action")
end

function TestMainTurnPreActionButton:test_real_pre_action_pending_choice_shows_the_action_button_not_the_end_button()
  local g, pending = _open_pre_action_choice()
  local view = choice_builder.build_choice_view(pending, { game = g })

  local visible = {}
  local touch = {}
  local ui = {
    set_visible = function(_, name, value)
      visible[name] = value
    end,
    set_touch_enabled = function(_, name, value)
      touch[name] = value
    end,
  }

  panel_controls.apply_base_action_controls(ui, { choice = view }, true)

  _assert_eq(visible[base_nodes.action_button], true,
    "行动 should precede the roll while a pre-action card is held")
  _assert_eq(touch[base_nodes.action_button], true, "行动 button should be touchable before the roll")
  _assert_eq(visible[base_nodes.end_button], false, "结束 should stay hidden before the roll")
  _assert_eq(visible[base_nodes.cancel_button], false, "取消 should stay hidden before the roll")
end

function TestMainTurnPreActionButton:test_real_pre_action_action_button_routes_through_the_skip_and_roll_intent()
  local g, pending = _open_pre_action_choice()
  local view = choice_builder.build_choice_view(pending, { game = g })
  local state = { ui_runtime = { ui_model = { choice = view } } }

  local action_intent = nil
  for _, spec in ipairs(route_base.build(state)) do
    if spec.name == base_nodes.action_button then
      action_intent = spec.build_intent()
      break
    end
  end

  lu.assertEvalToTrue(action_intent ~= nil, "行动 button should build an intent while a pre-action card is held")
  _assert_eq(action_intent.type, "complete_optional_action_phase",
    "行动 should skip the pre-action items and advance to the roll")
end


return TestMainTurnPreActionButton
