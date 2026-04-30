local support = require("support.gameplay_support")
local fixtures = require("support.gameplay_fixtures")
local assert = require("luassert")

local function _prepare_board_scene(state, game)
  local scene = {
    tiles = {},
    buildings = {},
    building_unit_groups = {},
    building_txt = {},
    overlay_units = {
      roadblocks = {},
      mines = {},
    },
    ground = {
      get_position = function()
        return math.Vector3(0, 0, 0)
      end,
    },
  }
  for index, tile in ipairs(game.board.path) do
    local pos = math.Vector3(index, 0, 0)
    scene.tiles[index] = {
      get_position = function()
        return pos
      end,
    }
    scene.buildings[index] = {
      get_position = function()
        return math.Vector3(index, 1, 0)
      end,
    }
    scene.building_txt[index] = {
      set_billboard_text = function() end,
    }
  end
  state.board_scene = scene
  state.tile_units = scene.tiles
  state.tile_positions = nil
end

local function _run_market_modal_race_case(game_opts, expect_open, case_name)
  local game = support.new_game(game_opts)
  local state = fixtures.build_loop_state()
  state.local_actor_role_id = game.players[1].id
  _prepare_board_scene(state, game)
  support.bind_ui_runtime(state)

  support.open_choice(game, {
    kind = "market_buy",
    route_key = "market",
    title = "黑市",
    options = { { id = 1, label = "购买" } },
  })

  local modal = require("src.ui.coord.modal")
  local called = false

  support.with_patches({
    {
      target = require("src.ui.coord.ui_runtime"),
      key = "render",
      value = function()
      end,
    },
    {
      target = modal,
      key = "open_choice_modal",
      value = function(...)
        called = true
      end,
    },
  }, function()
    local ui_model_sync = require("src.ui.ports.ui_sync.model")
    local common = {
      log_once = {},
      build_log_prefix = function()
        return ""
      end,
    }
    ui_model_sync.refresh_from_dirty(game, state, { any = true, ui = true }, common)
  end)

  if expect_open then
    assert.is_true(called, case_name)
  else
    assert.is_false(called, case_name)
  end
end

return {
  name = "auto_player_market_modal_race",
  tests = {
    {
      name = "auto_player_does_not_open_market_modal",
      run = function()
        _run_market_modal_race_case({ players = { "P1", "P2" }, auto_all = true }, false, "modal must NOT open for auto player")
      end,
    },
    {
      name = "ai_player_does_not_open_market_modal",
      run = function()
        _run_market_modal_race_case({ players = { "P1", "P2" }, ai = { [1] = true } }, false, "modal must NOT open for AI player")
      end,
    },
    {
      name = "local_human_player_does_open_market_modal",
      run = function()
        _run_market_modal_race_case({ players = { "P1", "P2" } }, true, "modal MUST open for local human player")
      end,
    },
  },
}
