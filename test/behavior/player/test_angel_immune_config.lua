require("test.bootstrap").install_package_paths()
-- busted injects the extensible assertion object into each file environment.
-- luacheck: ignore 143
local luassert = assert
local deity_ops = require("src.player.actions.deity")
local item_ids = require("src.config.gameplay.item_ids")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  luassert.truthy(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
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

describe("TestAngelImmuneConfig", function()

  before_each(function()
    _config_reset.reset_all()
  end)

  it("test_mine_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), true, "mine should be immune with angel")
  end)

  it("test_mine_is_not_immune_without_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), false, "mine should not be immune without angel")
  end)

  it("test_free_rent_is_not_angel_immune", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.free_rent), false, "free_rent should not be immune")
  end)

  it("test_nil_item_id_errors", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    local ok = pcall(function() deity_ops.angel_immune_to_item(game, player, nil) end)
    _assert_eq(ok, false, "nil item_id should error")
  end)

  it("test_roadblock_is_not_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.roadblock), false, "roadblock should not be immune with angel")
  end)

  it("test_share_wealth_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.share_wealth), true, "share_wealth should be immune with angel")
  end)

  it("test_exile_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.exile), true, "exile should be immune with angel")
  end)

  it("test_steal_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.steal), true, "steal should be immune with angel")
  end)

  it("test_tax_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.tax), true, "tax should be immune with angel")
  end)

  it("test_missile_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.missile), true, "missile should be immune with angel")
  end)

  it("test_monster_is_immune_when_player_has_angel", function()
    local game = _make_game()
    local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
    _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.monster), true, "monster should be immune with angel")
  end)

  it("test_game_exposes_angel_immune_to_item_mixin", function()
    local support = require("test.support.shared_support")
    local game = support.new_game({ players = { "P1" }, auto_all = true })
    luassert.truthy(type(game.angel_immune_to_item) == "function", "Expected angel_immune_to_item mixin")
  end)


end)
