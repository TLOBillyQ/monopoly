local support = require("spec.support.shared_support")
local movement = require("src.rules.movement")
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")

describe("gameplay_angel_immunity", function()
  local _config_reset = require("spec.support.config_reset")

  before_each(function()
    _config_reset.reset_all()
  end)

  local function _event_texts(game)
    local entries = game.state and game.state.event_log and game.state.event_log.entries or {}
    local texts = {}
    for i, entry in ipairs(entries) do
      texts[i] = entry.text
    end
    return texts
  end

  it("roadblock angel still stops and consumes roadblock", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local player = game.players[1]
    game:set_player_deity(player, "angel")
    game.board:place_roadblock(2)

    local move_result = movement.move(game, player, 3, { branch_parity = 3, skip_market_check = true })

    assert(move_result.stopped_on_roadblock == true, "angel should still stop on roadblock")
    assert(game.board:has_roadblock(2) == false, "roadblock should be consumed for angel")
    assert(player.position == 2, "angel should stop on the roadblock tile")
  end)

  it("roadblock non-angel stops and consumes roadblock", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local player = game.players[1]
    game.board:place_roadblock(2)

    local move_result = movement.move(game, player, 3, { branch_parity = 3, skip_market_check = true })

    assert(move_result.stopped_on_roadblock == true, "non-angel should stop on roadblock")
    assert(game.board:has_roadblock(2) == false, "roadblock should be consumed for non-angel")
    assert(player.position == 2, "non-angel should stop on the roadblock tile")
  end)

  it("share_wealth angel blocks effect and emits immunity event", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    game:set_player_cash(user, 1000)
    game:set_player_cash(target, 3000)
    game:set_player_deity(target, "angel")

    local before_user = game:player_cash(user)
    local before_target = game:player_cash(target)

    local result = post_effects.apply_target(game, user, item_ids.share_wealth, target, {})

    assert(result == true, "share_wealth should still consume the card")
    assert(game:player_cash(user) == before_user, "angel should keep user cash unchanged")
    assert(game:player_cash(target) == before_target, "angel should keep target cash unchanged")

    local texts = _event_texts(game)
    assert(#texts > 0 and texts[#texts] == "P2 天使保护，均富无效", "item_immune event should be emitted")
  end)

  it("share_wealth non-angel shares wealth normally", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    game:set_player_cash(user, 1000)
    game:set_player_cash(target, 3000)

    local result = post_effects.apply_target(game, user, item_ids.share_wealth, target, {})

    assert(result == true, "share_wealth should resolve normally")
    assert(game:player_cash(user) == 2000, "wealth should be equalized")
    assert(game:player_cash(target) == 2000, "wealth should be equalized")

    local texts = _event_texts(game)
    assert(texts[#texts] ~= "P2 天使保护，均富无效", "non-angel should not emit immunity event")
  end)

  it("exile angel blocks effect and emits immunity event", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    local mountain_idx = assert(game.board:find_first_by_type("mountain"), "mountain tile should exist")
    target.position = 1
    game:set_player_deity(target, "angel")

    local before_position = target.position
    local result = post_effects.apply_target(game, user, item_ids.exile, target, {})

    assert(result == true, "exile should still consume the card")
    assert(target.position == before_position, "angel should not be relocated")

    local texts = _event_texts(game)
    assert(#texts > 0 and texts[#texts] == "P2 天使保护，流放无效", "item_immune event should be emitted")
    assert(game.board:find_first_by_type("mountain") == mountain_idx, "mountain tile should remain available")
  end)

  it("exile non-angel relocates normally", function()
    local game = support.new_game({ players = { "P1", "P2" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    local mountain_idx = assert(game.board:find_first_by_type("mountain"), "mountain tile should exist")
    target.position = 1

    local result = post_effects.apply_target(game, user, item_ids.exile, target, {})

    assert(result == true, "exile should resolve normally")
    assert(target.position == mountain_idx, "non-angel should be moved to mountain")
  end)
end)
