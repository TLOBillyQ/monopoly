local support = require("spec.support.gameplay_support")
local fixtures = require("spec.support.gameplay_fixtures")
local assert = require("luassert")

local function _build_landing_choice(game)
  local owner_id = game.players[1].id
  return support.open_choice(game, {
    kind = "landing_optional_effect",
    route_key = "secondary_confirm",
    requires_confirm = true,
    title = "买地",
    body_lines = { "买地" },
    options = { { id = "buy_land", label = "买地" } },
    owner_role_id = owner_id,
    meta = {
      effect_ids = { "buy_land" },
      player_id = owner_id,
    },
  })
end

local function _run_event_path_case(game_opts, expect_open, case_name)
  local game = support.new_game(game_opts)
  local state = fixtures.build_loop_state()
  state.local_actor_role_id = game.players[1].id
  support.bind_ui_runtime(state)
  state.game = game

  local choice = _build_landing_choice(game)
  local modal = require("src.ui.coord.modal")
  local opened = false

  support.with_patches({
    {
      target = modal,
      key = "open_choice_modal",
      value = function() opened = true end,
    },
  }, function()
    local runtime_event_ports = require("src.ui.ports.events")
    runtime_event_ports.on_need_choice(state, function() return game end, { choice = choice })
  end)

  if expect_open then
    assert.is_true(opened, case_name)
  else
    assert.is_false(opened, case_name)
  end
end

describe("auto_player_landing_choice_event_path", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("auto_player_does_not_open_landing_modal_via_event", function()
    _run_event_path_case(
      { players = { "P1", "P2" }, auto_all = true, ai = {} },
      false,
      "modal must NOT open via on_need_choice for auto/托管 owner"
    )
  end)

  it("ai_player_does_not_open_landing_modal_via_event", function()
    _run_event_path_case(
      { players = { "P1", "P2" }, ai = { [1] = true } },
      false,
      "modal must NOT open via on_need_choice for AI owner"
    )
  end)

  it("local_human_player_opens_landing_modal_via_event", function()
    _run_event_path_case(
      { players = { "P1", "P2" }, ai = {} },
      true,
      "modal MUST open via on_need_choice for local human owner"
    )
  end)
end)
