-- 请神卡候选面规约(deities_008/009/010):请神卡只请正面神灵。
-- 走真实 registry:target_candidates —— availability / 无目标提示 / 托管选靶都读这条候选面。
--
-- 原生 LuaUnit 迁移:describe 拍平为文件级 Test* 类,断言词汇从 luassert
-- 兼容层切到 lu.assertXxx,用例数与改写前一一对应(5 例)。
local item_ids = require("src.config.gameplay.item_ids")
local support = require("test.support.shared_support")

local function _candidates(game, user)
  local registry = assert(game.registries and game.registries.items, "missing item registry")
  return registry:target_candidates(game, user, item_ids.invite_deity)
end

local function _two_players(deity_type)
  local game = support.new_game({ players = { "A", "B" }, auto_all = true })
  local user, target = game.players[1], game.players[2]
  if deity_type ~= nil then
    game:set_player_deity(target, deity_type, 3)
  end
  return game, user, target
end

TestItemInviteDeityTarget = {}

function TestItemInviteDeityTarget:test_rich_holder_is_an_invite_candidate()
  local game, user, target = _two_players("rich")
  support.assert_eq(support.list_contains(_candidates(game, user), target), true, "财神持有者应在候选列表中")
end

function TestItemInviteDeityTarget:test_angel_holder_is_an_invite_candidate()
  local game, user, target = _two_players("angel")
  support.assert_eq(support.list_contains(_candidates(game, user), target), true, "天使持有者应在候选列表中")
end

function TestItemInviteDeityTarget:test_poor_holder_is_not_an_invite_candidate()
  local game, user, target = _two_players("poor")
  support.assert_eq(support.list_contains(_candidates(game, user), target), false, "穷神持有者不应在候选列表中")
end

function TestItemInviteDeityTarget:test_deityless_player_is_not_an_invite_candidate()
  local game, user, target = _two_players(nil)
  support.assert_eq(support.list_contains(_candidates(game, user), target), false, "无神灵者不应在候选列表中")
end

function TestItemInviteDeityTarget:test_all_poor_opponents_leave_no_invite_target()
  local game = support.new_game({ players = { "A", "B", "C" }, auto_all = true })
  local user = game.players[1]
  for index = 2, #game.players do
    game:set_player_deity(game.players[index], "poor", 3)
  end
  support.assert_eq(#_candidates(game, user), 0, "对手只剩穷神时请神卡候选数")
end


return TestItemInviteDeityTarget
