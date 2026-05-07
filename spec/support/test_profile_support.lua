local support = require("spec.support.runtime_support")
local bind_ui_runtime = support.bind_ui_runtime
local map_cfg = support.map_cfg
local tiles_cfg = support.tiles_cfg
local build_ui_port = support.build_ui_port
local runtime_state = require("src.state.runtime")
local board_view = require("src.ui.render.board")
local default_ports = require("src.turn.output.default_ports")
local test_profile_bootstrap = require("src.app.testing.test_profile_bootstrap")

local M = {}

local function _inventory_counts_by_id(player)
  local counts = {}
  for _, item in ipairs(player.inventory.items or {}) do
    counts[item.id] = (counts[item.id] or 0) + 1
  end
  return counts
end

function M.new_game()
  return require("src.app.compose_game").new_game(default_ports.resolve_game_opts({
    players = { "P1", "P2", "P3", "P4" },
    ai = { [2] = true, [3] = true, [4] = true },
    auto_all = false,
    map = map_cfg,
    tiles = tiles_cfg,
  }))
end

function M.apply_profile(name)
  local game = M.new_game()
  test_profile_bootstrap.apply(game, name)
  return game
end

function M.assert_inventory_counts(player, expected_counts)
  local actual = _inventory_counts_by_id(player)
  local actual_total = 0
  for _, count in pairs(actual) do
    actual_total = actual_total + count
  end

  local expected_total = 0
  for item_id, count in pairs(expected_counts) do
    expected_total = expected_total + count
    assert(actual[item_id] == count, "item count mismatch for " .. tostring(item_id))
  end
  assert(actual_total == expected_total, "inventory total mismatch")
end

function M.assert_player_on_tile_id(game, player_index, tile_id)
  local expected = assert(game.board:index_of_tile_id(tile_id), "tile id should exist in board path")
  assert(game.players[player_index].position == expected,
    "player " .. tostring(player_index) .. " position should match tile " .. tostring(tile_id))
  return expected
end

local function _new_render_state(game)
  local state = {
    game = game,
    ui = build_ui_port().ui,
    board_scene = {
      tiles = {},
      buildings = {},
      building_txt = {},
      building_unit_groups = {},
      ground = {
        get_position = function()
          return math.Vector3(0, 0, 0)
        end,
      },
    },
    tile_units = {},
    tile_positions = {},
    tile_spacing = 1,
    player_units = {},
    player_units_missing = false,
  }
  bind_ui_runtime(state)
  runtime_state.ensure_all(state)
  for index = 1, #game.board.path do
    local tile_pos = math.Vector3(index, 0, 0)
    state.board_scene.tiles[index] = {
      get_position = function()
        return tile_pos
      end,
    }
    state.tile_units[index] = state.board_scene.tiles[index]
    state.tile_positions[index] = tile_pos
    state.board_scene.buildings[index] = {
      get_position = function()
        return math.Vector3(index, 1, 0)
      end,
    }
    state.board_scene.building_txt[index] = {
      set_billboard_text = function() end,
    }
  end
  for _, player in ipairs(game.players) do
    state.player_units[player.id] = {
      set_position = function() end,
    }
  end
  return state
end

function M.render_profile_startup(game)
  local state = _new_render_state(game)
  local ui_model = {
    board = {
      tiles = {},
      tile_states = game.board.tile_lookup,
      players = game.players,
      tile_count = #game.board.path,
      phase = game.turn and game.turn.phase or "start",
      move_anim = nil,
      move_followup_pending = false,
    },
  }
  for index, tile in ipairs(game.board.path) do
    ui_model.board.tiles[index] = {
      id = tile.id,
      type = tile.type,
    }
  end
  local board_runtime = runtime_state.ensure_board_runtime(state)
  for _, player in ipairs(game.players) do
    board_runtime.board_last_positions[player.id] = tostring(player.position) .. ":" .. tostring(player.eliminated and 1 or 0)
  end
  board_view.refresh(state, ui_model, function() end, function() return "test_profiles" end)
  return state
end

M.with_patches = support.with_patches
M.tile_state = support.tile_state
M.map_cfg = map_cfg
M.tiles_cfg = tiles_cfg
M.movement = support.movement

return M
