local support = require("spec.support.shared_support")
local effect_chance = require("src.rules.land.effect_chance")

local executor = effect_chance.executors.chance_draw_and_resolve

describe("chance_draw_and_resolve executor", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("can_apply true for chance tile with game and player", function()
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    local player = game.players[1]
    local _, chance_tile = support.first_tile_by_type(game.board, "chance")
    assert(executor.can_apply({ game = game, player = player, tile = chance_tile }) == true,
      "expected true for chance tile")
  end)

  it("can_apply falsy for non-chance tile", function()
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    local player = game.players[1]
    assert(not executor.can_apply({ game = game, player = player, tile = { type = "land" } }),
      "expected falsy for land tile")
  end)

  it("can_apply falsy when tile is nil", function()
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    local player = game.players[1]
    assert(not executor.can_apply({ game = game, player = player, tile = nil }),
      "expected falsy when tile is nil")
  end)

  it("can_apply falsy when game is nil", function()
    assert(not executor.can_apply({ game = nil, player = {}, tile = { type = "chance" } }),
      "expected falsy when game is nil")
  end)

  it("can_apply falsy when player is nil", function()
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    assert(not executor.can_apply({ game = game, player = nil, tile = { type = "chance" } }),
      "expected falsy when player is nil")
  end)

  it("apply publishes a chance card event to the event log", function()
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
    assert(found, "expected chance card event in event log")
  end)

end)
