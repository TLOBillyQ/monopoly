require("test.bootstrap").install_package_paths()
local luassert = assert
local support = require("test.support.shared_support")
local effect_chance = require("src.rules.land.effect_chance")
local _config_reset = require("test.support.config_reset")

local executor = effect_chance.executors.chance_draw_and_resolve

describe("TestChanceExecutor", function()
before_each(function()
  _config_reset.reset_all()
end)

it("test_can_apply_true_for_chance_tile_with_game_and_player", function()
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  local player = game.players[1]
  local _, chance_tile = support.first_tile_by_type(game.board, "chance")
  luassert.is.equal(true, executor.can_apply({ game = game, player = player, tile = chance_tile }),
    "expected true for chance tile")
end)

it("test_can_apply_falsy_for_non_chance_tile", function()
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  local player = game.players[1]
  luassert.falsy(executor.can_apply({ game = game, player = player, tile = { type = "land" } }),
    "expected falsy for land tile")
end)

it("test_can_apply_falsy_when_tile_is_nil", function()
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  local player = game.players[1]
  luassert.falsy(executor.can_apply({ game = game, player = player, tile = nil }),
    "expected falsy when tile is nil")
end)

it("test_can_apply_falsy_when_game_is_nil", function()
  luassert.falsy(executor.can_apply({ game = nil, player = {}, tile = { type = "chance" } }),
    "expected falsy when game is nil")
end)

it("test_can_apply_falsy_when_player_is_nil", function()
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  luassert.falsy(executor.can_apply({ game = game, player = nil, tile = { type = "chance" } }),
    "expected falsy when player is nil")
end)

it("test_apply_publishes_a_chance_card_event_to_the_event_log", function()
  local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
  local player = game.players[1]
  local _, chance_tile = support.first_tile_by_type(game.board, "chance")

  executor.apply({ game = game, player = player, tile = chance_tile, move_result = {} })

  local entries = game.state and game.state.event_log and game.state.event_log.entries or {}
  local found = false
  for _, entry in ipairs(entries) do
    if entry.text and entry.text:find("机会卡", 1, true) then
      found = true
      break
    end
  end
  luassert.truthy(found, "expected chance card event in event log")
end)


end)
