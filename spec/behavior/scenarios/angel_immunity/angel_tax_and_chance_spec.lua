local support = require("spec.support.shared_support")
local chance_resolver = require("src.rules.chance.resolver")
local chance_cfg = require("src.config.content.chance_cards")

describe("angel_tax_and_chance_immunity", function()
  local _config_reset = require("spec.support.config_reset")

  before_each(function()
    _config_reset.reset_all()
  end)

  it("angel does not block tax office landing effect", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local player = game.players[1]
    local tax_idx = support.first_tile_by_type(game.board, "tax")
    player.position = tax_idx
    game:set_player_cash(player, 10000)
    game:set_player_deity(player, "angel")

    local tile = game.board:get_tile(tax_idx)
    support.resolve_landing(game, player, tile, {})

    assert(game:player_cash(player) < 10000,
      "angel should still pay tax office fee")
  end)

  it("non-angel pays tax normally", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local player = game.players[1]
    local tax_idx = support.first_tile_by_type(game.board, "tax")
    player.position = tax_idx
    game:set_player_cash(player, 10000)

    local tile = game.board:get_tile(tax_idx)
    support.resolve_landing(game, player, tile, {})

    assert(game:player_cash(player) < 10000,
      "non-angel should pay tax")
  end)

  it("resolver blocks negative chance card for angel drawer", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local player = game.players[1]
    game:set_player_deity(player, "angel")

    local card = nil
    for _, c in ipairs(chance_cfg) do
      if c.negative and c.effect == "pay_cash" and c.target == "self" then
        card = c
        break
      end
    end
    assert(card ~= nil, "should find a negative pay_cash self card")

    game:set_player_cash(player, 20000)
    local result = chance_resolver.resolve(game, player, card, {})
    assert(result == nil, "resolver should return nil for angel + negative card")
    assert(game:player_cash(player) == 20000,
      "angel drawer's cash should be unchanged")
  end)

  it("target-all pay_cash skips angel-protected players", function()
    local game = support.new_game({ players = { "P1", "P2", "P3" }, auto_all = true })
    local drawer = game.players[1]
    local angel_player = game.players[2]
    local normal_player = game.players[3]
    game:set_player_cash(drawer, 20000)
    game:set_player_cash(angel_player, 20000)
    game:set_player_cash(normal_player, 20000)
    game:set_player_deity(angel_player, "angel")

    local card = nil
    for _, c in ipairs(chance_cfg) do
      if c.negative and c.effect == "pay_cash" and c.target == "all" then
        card = c
        break
      end
    end
    assert(card ~= nil, "should find a negative pay_cash all card")

    chance_resolver.resolve(game, drawer, card, {})

    assert(game:player_cash(angel_player) == 20000,
      "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
    assert(game:player_cash(normal_player) < 20000,
      "non-angel player should pay")
  end)

  it("target-all percent_pay_cash skips angel-protected players", function()
    local game = support.new_game({ players = { "P1", "P2", "P3" }, auto_all = true })
    local drawer = game.players[1]
    local angel_player = game.players[2]
    local normal_player = game.players[3]
    game:set_player_cash(drawer, 20000)
    game:set_player_cash(angel_player, 20000)
    game:set_player_cash(normal_player, 20000)
    game:set_player_deity(angel_player, "angel")

    local card = nil
    for _, c in ipairs(chance_cfg) do
      if c.negative and c.effect == "percent_pay_cash" and c.target == "all" then
        card = c
        break
      end
    end
    assert(card ~= nil, "should find a negative percent_pay_cash all card")

    chance_resolver.resolve(game, drawer, card, {})

    assert(game:player_cash(angel_player) == 20000,
      "angel player should not pay: expected 20000, got " .. tostring(game:player_cash(angel_player)))
    assert(game:player_cash(normal_player) < 20000,
      "non-angel player should pay percentage")
  end)
end)
