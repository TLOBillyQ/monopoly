-- 原生 LuaUnit(自研 busted → LuaUnit 迁移):describe 拍平为 TestAngelImmuneConfig,
-- before_each → setUp,用例数与改写前一一对应(12 例)。
local lu = require("luaunit")
local deity_ops = require("src.player.actions.deity")
local item_ids = require("src.config.gameplay.item_ids")

local _config_reset = require("test.support.config_reset")

local function _assert_eq(a, b, msg)
  lu.assertEvalToTrue(a == b, tostring(msg) .. ": expected " .. tostring(b) .. " got " .. tostring(a))
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

TestAngelImmuneConfig = {}

function TestAngelImmuneConfig:setUp()
  _config_reset.reset_all()
end

function TestAngelImmuneConfig:test_mine_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), true, "mine should be immune with angel")
end

function TestAngelImmuneConfig:test_mine_is_not_immune_without_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "devil", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.mine), false, "mine should not be immune without angel")
end

function TestAngelImmuneConfig:test_free_rent_is_not_angel_immune()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.free_rent), false, "free_rent should not be immune")
end

function TestAngelImmuneConfig:test_nil_item_id_errors()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  local ok = pcall(function() deity_ops.angel_immune_to_item(game, player, nil) end)
  _assert_eq(ok, false, "nil item_id should error")
end

function TestAngelImmuneConfig:test_roadblock_is_not_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.roadblock), false, "roadblock should not be immune with angel")
end

function TestAngelImmuneConfig:test_share_wealth_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.share_wealth), true, "share_wealth should be immune with angel")
end

function TestAngelImmuneConfig:test_exile_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.exile), true, "exile should be immune with angel")
end

function TestAngelImmuneConfig:test_steal_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.steal), true, "steal should be immune with angel")
end

function TestAngelImmuneConfig:test_tax_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.tax), true, "tax should be immune with angel")
end

function TestAngelImmuneConfig:test_missile_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.missile), true, "missile should be immune with angel")
end

function TestAngelImmuneConfig:test_monster_is_immune_when_player_has_angel()
  local game = _make_game()
  local player = _make_player({ status = { deity = { type = "angel", remaining = 1 } } })
  _assert_eq(deity_ops.angel_immune_to_item(game, player, item_ids.monster), true, "monster should be immune with angel")
end

function TestAngelImmuneConfig:test_game_exposes_angel_immune_to_item_mixin()
  local support = require("test.support.shared_support")
  local game = support.new_game({ players = { "P1" }, auto_all = true })
  lu.assertEvalToTrue(type(game.angel_immune_to_item) == "function", "Expected angel_immune_to_item mixin")
end


return TestAngelImmuneConfig
