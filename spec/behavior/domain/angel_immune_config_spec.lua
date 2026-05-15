local deity_ops = require("src.player.actions.deity")
local item_ids = require("src.config.gameplay.item_ids")

local function _assert_eq(a, b, msg)
  assert(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
end

local function _make_game()
  local g = {
    dirty = { any = false, players = false },
  }
  g.player_has_deity = deity_ops.player_has_deity
  return g
end

local function _make_player(opts)
  opts = opts or {}
  return {
    id = opts.id or "p1",
    status = opts.status or nil,
    deity_duration_turns = opts.deity_duration_turns or 3,
  }
end

describe("domain angel immune config", function()
  local _config_reset = require("spec.support.config_reset")
  before_each(function() _config_reset.reset_all() end)

  it("mine is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), true, "mine should be immune with angel")
  end)

  it("mine is not immune without angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), false, "mine should not be immune without angel")
  end)

  it("free_rent is not angel immune", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.free_rent), false, "free_rent should not be immune")
  end)

  it("nil item_id errors", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    local ok = pcall(function() deity_ops.angel_immune_to_item(game, player, nil) end)
    _assert_eq(ok, false, "nil item_id should error")
  end)

  it("roadblock is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.roadblock), true, "roadblock should be immune with angel")
  end)

  it("share_wealth is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.share_wealth), true, "share_wealth should be immune with angel")
  end)

  it("exile is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.exile), true, "exile should be immune with angel")
  end)

  it("steal is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.steal), true, "steal should be immune with angel")
  end)

  it("tax is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.tax), true, "tax should be immune with angel")
  end)

  it("missile is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.missile), true, "missile should be immune with angel")
  end)

  it("monster is immune when player has angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.monster), true, "monster should be immune with angel")
  end)

  it("game exposes angel_immune_to_item mixin", function()
    local support = require("support.domain_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    assert(type(game.angel_immune_to_item) == "function", "Expected angel_immune_to_item mixin")
  end)
end)
