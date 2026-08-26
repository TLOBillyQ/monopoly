-- steal.lua 直测:steal_nth_occupied 的缺省序号、自耗、事件契约(blocks_
-- inter_turn/source)、anim 参数与返回值;steal_random_item 的 rng 守卫。
local lu = require("luaunit")
local support = require("test.support.shared_support")

local steal = require("src.rules.items.steal")
local inventory_mod = require("src.rules.items.inventory")
local event_feed = require("src.rules.ports.event_feed")
local action_anim_port = require("src.foundation.ports.action_anim")
local gain_reveal = require("src.rules.items.gain_reveal")

TestSteal = {}

local function _game(captured)
  return {
    rng = {
      next_int = function(_, low, high)
        captured.rng_low = low
        captured.rng_high = high
        return low
      end,
    },
  }
end

-- 真实背包跑完整链路(CONTEXT「道具槽位」 / CONTEXT「道具槽位」「偷窃入包」):手搓
-- 密集数组 stub 会把槽位语义测丢,禁用;只打事件/动画/获得展示端口补丁。
local function _real_player(id, name, item_id_list)
  local inventory_class = require("src.player.actions.inventory")
  local item_ids = require("src.config.gameplay.item_ids")
  local player = { id = id, name = name, inventory = inventory_class:new({ max_slots = 5 }) }
  for _, item_id in ipairs(item_id_list) do
    player.inventory:add({ id = item_ids[item_id] })
  end
  return player
end

local function _with_steal_ports(captured, fn)
  support.with_patches({
    { target = event_feed, key = "publish", value = function(_, payload)
      captured.feed = payload
    end },
    { target = action_anim_port, key = "queue", value = function(_, opts2)
      captured.anim = opts2
      return "a1"
    end },
    { target = gain_reveal, key = "queue", value = function() end },
  }, fn)
end

-- 偷窃者只持偷窃卡;目标持 mine/missile 两张。nth 缺省应落第 1 张占用卡。
local function _drive(nth)
  local captured = {}
  local player = _real_player(1, "P1", { "steal" })
  local target = _real_player(2, "T2", { "mine", "missile" })
  _with_steal_ports(captured, function()
    captured.result = steal.steal_nth_occupied(_game(captured), player, target, nth)
  end)
  captured.player = player
  captured.target = target
  return captured
end

function TestSteal:test_defaults_to_the_first_occupied_card()
  local item_ids = require("src.config.gameplay.item_ids")
  local captured = _drive(nil)
  lu.assertEvalToTrue(captured.result.ok == true, "the steal must succeed")
  lu.assertEvalToTrue(captured.result.stolen.id == item_ids.mine,
    "a nil ordinal must default to the first occupied card")
  lu.assertEvalToTrue(inventory_mod.find_index(captured.player, item_ids.mine) ~= nil,
    "the stolen item must land in the stealer bag")
end

function TestSteal:test_success_event_contract()
  local captured = _drive(1)
  lu.assertEvalToTrue(captured.feed ~= nil, "a success feed must be published")
  lu.assertEvalToTrue(captured.feed.blocks_inter_turn == false, "steal must not block inter-turn")
  lu.assertEvalToTrue(captured.feed.source == "rules.items.steal", "the feed source must be pinned")
end

function TestSteal:test_anim_uses_the_steal_card_identity()
  local captured = _drive(1)
  lu.assertEvalToTrue(captured.anim ~= nil, "an action anim must be queued")
  lu.assertEvalToTrue(captured.anim.kind == "item_target_player", "the anim kind must be pinned")
  lu.assertEvalToTrue(captured.anim.item_name == "偷窃卡", "the item name must be pinned")
  lu.assertEvalToTrue(captured.anim.target_player_id == 2, "the target must be pinned")
end

function TestSteal:test_empty_target_fails_without_consuming()
  local item_ids = require("src.config.gameplay.item_ids")
  local captured = {}
  local player = _real_player(1, "P1", { "steal" })
  local target = _real_player(2, "T2", {})
  _with_steal_ports(captured, function()
    captured.result = steal.steal_nth_occupied({}, player, target, 1)
  end)
  lu.assertEvalToTrue(captured.result.ok == false, "an empty target must fail")
  lu.assertEvalToTrue(inventory_mod.find_index(player, item_ids.steal) ~= nil,
    "the steal card must not be consumed on failure")
  lu.assertEvalToTrue(captured.feed ~= nil and captured.feed.blocks_inter_turn == false,
    "the failure feed must not block inter-turn")
  lu.assertEvalToTrue(captured.feed ~= nil and captured.feed.source == "rules.items.steal",
    "the failure feed source must be pinned")
end

function TestSteal:test_random_steal_uses_the_rng_range()
  local captured = {}
  local player = _real_player(1, "P1", { "steal" })
  local target = _real_player(2, "T2", { "mine", "missile", "roadblock" })
  _with_steal_ports(captured, function()
    captured.result = steal.steal_random_item(_game(captured), player, target)
  end)
  lu.assertEvalToTrue(captured.rng_low == 1 and captured.rng_high == 3,
    "the rng must draw within the target occupied count")
  lu.assertEvalToTrue(captured.result.ok == true, "a random steal must succeed")
end

-- 稳定槽位集成:钉住双方槽位布局(其余卡不动、战利品填最前洞、被偷者留洞)。
function TestSteal:test_stable_slots_other_cards_unmoved_and_stolen_fills_freed_slot()
  local item_ids = require("src.config.gameplay.item_ids")
  -- 偷窃者:槽1 路障、槽2 偷窃卡、槽3 免费卡;目标:槽1 地雷、槽2 导弹。
  local player = _real_player(1, "P1", { "roadblock", "steal", "free_rent" })
  local target = _real_player(2, "T2", { "mine", "missile" })
  local captured = {}
  _with_steal_ports(captured, function()
    captured.result = steal.steal_nth_occupied({}, player, target, 2)
  end)
  lu.assertEvalToTrue(captured.result.ok == true, "the steal must succeed")
  lu.assertEvalToTrue(captured.result.stolen.id == item_ids.missile, "the second occupied card is stolen")
  local bag = player.inventory.items
  lu.assertEvalToTrue(bag[1].id == item_ids.roadblock, "stealer slot 1 must stay put")
  lu.assertEvalToTrue(bag[2].id == item_ids.missile, "the stolen card fills the slot freed by the steal card")
  lu.assertEvalToTrue(bag[3].id == item_ids.free_rent, "stealer slot 3 must stay put")
  local target_bag = target.inventory.items
  lu.assertEvalToTrue(target_bag[1].id == item_ids.mine, "target slot 1 must stay put")
  lu.assertEvalToTrue(target_bag[2] == false, "the stolen slot becomes a hole on the target side")
end

function TestSteal:test_stolen_card_prefers_an_earlier_hole_over_the_freed_slot()
  local item_ids = require("src.config.gameplay.item_ids")
  -- 偷窃者:槽1 预先成洞、槽2 路障、槽3 偷窃卡 → 战利品填槽1 而非槽3。
  local player = _real_player(1, "P1", { "mine", "roadblock", "steal" })
  player.inventory:remove_by_index(1)
  local target = _real_player(2, "T2", { "missile" })
  local captured = {}
  _with_steal_ports(captured, function()
    captured.result = steal.steal_nth_occupied({}, player, target, 1)
  end)
  lu.assertEvalToTrue(captured.result.ok == true, "the steal must succeed")
  local bag = player.inventory.items
  lu.assertEvalToTrue(bag[1].id == item_ids.missile, "the stolen card fills the earliest hole")
  lu.assertEvalToTrue(bag[2].id == item_ids.roadblock, "stealer slot 2 must stay put")
  lu.assertEvalToTrue(bag[3] == false, "the freed steal-card slot stays a hole")
end

function TestSteal:test_random_steal_guards_missing_rng()
  local player = _real_player(1, "P1", { "steal" })
  local target = _real_player(2, "T2", { "mine" })
  lu.assertErrorMsgContains("missing game.rng for steal", function()
    steal.steal_random_item({}, player, target)
  end)
end

return TestSteal
