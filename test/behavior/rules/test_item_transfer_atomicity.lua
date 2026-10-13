require("test.bootstrap").install_package_paths()
local luassert = assert(require("test.support.luassert_loader").load())
-- 原生 LuaUnit(busted → LuaUnit 迁移):两个无钩子 describe 各拍平成一个 Test*
-- 类(invite_deity 4 例 + send_poor 4 例),describe 级 local _send_poor_apply 留在
-- 对应 do 块内,用例数与改写前一一对应。
local post_effects = require("src.rules.items.post_effects")
local item_ids = require("src.config.gameplay.item_ids")
local support = require("test.support.shared_support")
local constants = require("src.config.content.constants")

-- 候选面走真实 registry:availability / 无目标提示 / 托管选靶都读这条,手搓过滤
-- 循环会漏掉 registry 的 angel_immune / require_user 两道闸,在测试里复刻一份不
-- 完整的生产过滤逻辑正是失真的来源。
local function _invite_deity_candidates(game, user)
  local registry = luassert.truthy(game.registries and game.registries.items, "missing item registry")
  return registry:target_candidates(game, user, item_ids.invite_deity)
end

TestItemTransferAtomicity = {}

function TestItemTransferAtomicity:test_invite_deity_rejects_empty_placeholder()
  local game = support.new_game({ players = { "A", "B" }, auto_all = true })
  local a = game.players[1]
  local b = game.players[2]

  b.status.deity = { type = "", remaining = 0 }

  luassert.is.equal(false, support.list_contains(_invite_deity_candidates(game, a), b), "empty placeholder should not be a candidate")
end

function TestItemTransferAtomicity:test_invite_deity_filter_rejects_no_deity()
  local game = support.new_game({ players = { "A", "B" }, auto_all = true })
  local a = game.players[1]
  local b = game.players[2]

  b.status = nil

  luassert.is.equal(false, support.list_contains(_invite_deity_candidates(game, a), b), "no-deity player should not be a candidate")
end

function TestItemTransferAtomicity:test_chain_send_invite()
  local game = support.new_game({ players = { "A", "B", "C" }, auto_all = true })
  local a = game.players[1]
  local b = game.players[2]
  local c = game.players[3]

  a.status.deity = { type = "poor", remaining = 3 }
  luassert.is.equal(true, post_effects.apply_target(game, a, item_ids.send_poor, b, {}), "send_poor should apply")

  luassert.is.equal("", a.status.deity.type, "sender deity type should be cleared")
  luassert.is.equal(0, a.status.deity.remaining, "sender deity remaining should be cleared")
  luassert.is.equal(false, support.list_contains(_invite_deity_candidates(game, c), a), "cleared sender should not be an invite candidate")
end

function TestItemTransferAtomicity:test_invite_deity_same_deity_resets_remaining_to_full()
  -- 请到与自身相同的神=续神:剩余回合重置满时长,不照抄对方残余
  -- (否则我剩 9 对方剩 3,请神后反而缩成 3)。
  local game = support.new_game({ players = { "A", "B" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  game:set_player_deity(user, "rich", 8)
  game:set_player_deity(target, "rich", 2)

  luassert.is.equal(true, post_effects.apply_target(game, user, item_ids.invite_deity, target, {}), "invite_deity should apply")
  luassert.is.equal("rich", user.status.deity.type, "user keeps rich deity")
  luassert.is.equal(constants.deity_duration_turns + 1, user.status.deity.remaining, "remaining resets to full duration(+1 内部约定)")
  luassert.is.equal("", target.status.deity.type, "target deity cleared")
end

function TestItemTransferAtomicity:test_invite_deity_to_deityless_user_resets_remaining_to_full()
  -- #529:自身无神请神同样重置满时长,不照抄对方残余——转移即续神,
  -- 不分同神/异神/无神。
  local game = support.new_game({ players = { "A", "B" }, auto_all = true })
  local user = game.players[1]
  local target = game.players[2]
  game:set_player_deity(target, "rich", 2)

  luassert.is.equal(true, post_effects.apply_target(game, user, item_ids.invite_deity, target, {}), "invite_deity should apply")
  luassert.is.equal("rich", user.status.deity.type, "user receives rich deity")
  luassert.is.equal(constants.deity_duration_turns + 1, user.status.deity.remaining, "remaining resets to full duration(+1 内部约定)")
  luassert.is.equal("", target.status.deity.type, "target deity cleared")
end

TestItemTransferAtomicitySendPoor = {}

do
  local function _send_poor_apply()
    return luassert.truthy(post_effects.get_target_spec(item_ids.send_poor)).apply
  end

  function TestItemTransferAtomicitySendPoor:test_send_poor_rejects_rich_user()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "rich", remaining = 3 }

    luassert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end

  function TestItemTransferAtomicitySendPoor:test_send_poor_rejects_angel_user()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "angel", remaining = 3 }

    luassert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end

  function TestItemTransferAtomicitySendPoor:test_send_poor_rejects_expired_poor()
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    user.status.deity = { type = "poor", remaining = 0 }

    luassert.has_error(function()
      _send_poor_apply()(game, user, target, {})
    end, "send_poor.apply: user must have effective poor deity")
  end

  function TestItemTransferAtomicitySendPoor:test_send_poor_to_poor_target_resets_remaining()
    -- 送神卡送给已有穷神的目标同属同神转移:目标剩余回合重置满时长。
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    game:set_player_deity(user, "poor", 3)
    game:set_player_deity(target, "poor", 5)

    luassert.is.equal(true, _send_poor_apply()(game, user, target, {}), "send_poor should apply")
    luassert.is.equal("poor", target.status.deity.type, "target keeps poor deity")
    luassert.is.equal(constants.deity_duration_turns + 1, target.status.deity.remaining, "target remaining resets to full duration(+1 内部约定)")
    luassert.is.equal("", user.status.deity.type, "user deity cleared")
  end

  function TestItemTransferAtomicitySendPoor:test_send_poor_to_deityless_target_resets_remaining()
    -- #529:送给无神目标同样重置满时长,不照抄自己残余。
    local game = support.new_game({ players = { "A", "B" }, auto_all = true })
    local user = game.players[1]
    local target = game.players[2]
    game:set_player_deity(user, "poor", 3)

    luassert.is.equal(true, _send_poor_apply()(game, user, target, {}), "send_poor should apply")
    luassert.is.equal("poor", target.status.deity.type, "target receives poor deity")
    luassert.is.equal(constants.deity_duration_turns + 1, target.status.deity.remaining, "target remaining resets to full duration(+1 内部约定)")
    luassert.is.equal("", user.status.deity.type, "user deity cleared")
  end
end


-- mutate 车道统一返回全部类（#283 多类文件 return 首类假幸存方向）：
-- 正常车道扫 _G 收全部 Test* 类，但 mutate 内建 runner 只跑 return 的表，
-- 只 return 首个类会让其余类的用例在变异车道完全不执行。合并全部类，
-- 每个 test* 方法跑所属类 setUp/tearDown（见 multi_class_return）。
return require("test.support.multi_class_return").merge(
  TestItemTransferAtomicity,
  TestItemTransferAtomicitySendPoor
)
