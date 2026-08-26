---@diagnostic disable: need-check-nil, different-requires, undefined-field

local lu = require("luaunit")
local tip_text = require("src.ui.render.anim.tip_text")
local support = require("test.support.ui_action_anim_support")

TestActionAnimTipText = {}

function TestActionAnimTipText:test_anim_tip_text_builds_named_player_and_clear_obstacles_copy()
  local state = support.build_min_state()

  local target_copy = tip_text.build(state, {
    kind = "item_target_player",
    player_id = 1,
    item_name = "导弹卡",
    target_player_id = 1,
  })
  local clear_copy = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 1,
    roadblock_cleared = 1,
    mine_cleared = 1,
    branches = {
      {
        { tile_index = 3, has_obstacle = true },
        { tile_index = 4, has_obstacle = false },
      },
      {
        { tile_index = 3, has_obstacle = true },
        { tile_index = 5, has_obstacle = true },
      },
    },
  })

  lu.assertEvalToTrue(target_copy == "测试玩家 对 测试玩家 使用了 导弹卡",
    "item_target_player tip should resolve runtime player name")
  lu.assertEvalToTrue(clear_copy == "测试玩家 的清障机器人出动，清除了 1 个路障、1 个地雷",
    "clear_obstacles tip should list obstacle types from anim payload")
end

function TestActionAnimTipText:test_anim_tip_text_covers_roll_tile_and_cash_variants()
  local state = support.build_min_state()

  local focus_copy = tip_text.build(state, {
    kind = "move_effect",
    focus_text = "直接使用焦点文案",
    from_index = 1,
    to_index = 2,
  })
  local roll_copy = tip_text.build(state, {
    kind = "roll",
    rolls = { 2, 6 },
    total = 8,
  })
  local roadblock_copy = tip_text.build(state, {
    kind = "roadblock",
    tile_index = 1,
  })
  local move_copy = tip_text.build(state, {
    kind = "move_effect",
    player_id = 1,
    from_index = 1,
    to_index = 2,
  })
  local teleport_copy = tip_text.build(state, {
    kind = "teleport_effect",
    player_id = 1,
    from_index = 1,
    to_index = 2,
  })
  local cash_copy = tip_text.build(state, {
    kind = "cash_receive",
    player_id = 1,
    amount = 500.0,
  })

  lu.assertEvalToTrue(focus_copy == "直接使用焦点文案", "focus_text should override kind-specific copy")
  lu.assertEvalToTrue(roll_copy == "投骰动画：2,6 => 8", "roll tip should join rolls and total")
  lu.assertEvalToTrue(roadblock_copy == "路障动画：放置在 测试地块", "roadblock tip should resolve tile name")
  lu.assertEvalToTrue(move_copy == "位移动画：测试玩家 从 测试地块 到 测试地块", "move_effect debug tip should include from and to")
  lu.assertEvalToTrue(teleport_copy == "测试玩家 被传送到 测试地块", "teleport_effect tip should show player-facing format")
  lu.assertEvalToTrue(cash_copy == "收钱动画：测试玩家 +500", "cash_receive tip should resolve player name and amount")
end

function TestActionAnimTipText:test_anim_tip_text_clear_obstacles_lists_only_the_cleared_kinds()
  local state = support.build_min_state()

  local roadblock_only = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 1,
    roadblock_cleared = 2,
  })
  local mine_only = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 1,
    mine_cleared = 3,
  })

  lu.assertEvalToTrue(roadblock_only == "测试玩家 的清障机器人出动，清除了 2 个路障",
    "clearing only roadblocks should not mention mines")
  lu.assertEvalToTrue(mine_only == "测试玩家 的清障机器人出动，清除了 3 个地雷",
    "clearing only mines should not mention roadblocks")
end

function TestActionAnimTipText:test_anim_tip_text_clear_obstacles_reports_an_empty_sweep()
  local state = support.build_min_state()

  local nothing_cleared = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 1,
    roadblock_cleared = 0,
    mine_cleared = 0,
  })
  local no_counts = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 1,
  })

  lu.assertEvalToTrue(nothing_cleared == "测试玩家 的清障机器人出动，前方没有障碍",
    "zero counts should report an empty sweep")
  lu.assertEvalToTrue(no_counts == "测试玩家 的清障机器人出动，前方没有障碍",
    "missing counts should report an empty sweep")
end

function TestActionAnimTipText:test_anim_tip_text_falls_back_to_the_player_id_when_the_player_is_unknown()
  local state = support.build_min_state({
    find_player_by_id = function()
      return nil
    end,
  })

  local copy = tip_text.build(state, {
    kind = "clear_obstacles",
    player_id = 7,
    roadblock_cleared = 1,
  })

  lu.assertEvalToTrue(copy == "7 的清障机器人出动，清除了 1 个路障",
    "an unresolvable player should fall back to the raw player id")
end

function TestActionAnimTipText:test_anim_tip_text_covers_chance_item_and_unknown_tile_variants()
  local state = support.build_min_state({
    tile_getter = function(_, tile_index)
      if tile_index == 999 then
        return nil
      end
      return { name = "测试地块" }
    end,
  })

  local chance_copy = tip_text.build(state, {
    kind = "chance",
    card_desc = "全员发钱",
  })
  local item_use_copy = tip_text.build(state, {
    kind = "item_use",
    item_id = "freeze_card",
  })
  local mine_copy = tip_text.build(state, {
    kind = "mine",
    tile_index = 999,
  })
  local missile_copy = tip_text.build(state, {
    kind = "missile",
    player_id = 1,
    tile_index = 999,
  })
  local monster_copy = tip_text.build(state, {
    kind = "monster",
    player_id = 1,
    tile_index = 999,
  })
  local upgrade_copy = tip_text.build(state, {
    kind = "upgrade_land",
    tile_index = 999,
  })
  local missing_copy = tip_text.build(state, {
    kind = "unknown_kind",
  })

  lu.assertEvalToTrue(chance_copy == "机会卡展示：全员发钱", "chance tip should prefer card_desc")
  lu.assertEvalToTrue(item_use_copy == "道具生效：freeze_card", "item_use tip should fall back to item_id")
  lu.assertEvalToTrue(mine_copy == "地雷动画：埋设在 未知地块", "mine tip should fall back to unknown tile name")
  lu.assertEvalToTrue(missile_copy == "测试玩家 发射导弹轰炸 未知地块", "missile tip should fall back to unknown tile name")
  lu.assertEvalToTrue(monster_copy == "测试玩家 释放怪兽攻击 未知地块", "monster tip should fall back to unknown tile name")
  lu.assertEvalToTrue(upgrade_copy == "加盖动画：未知地块", "upgrade_land tip should fall back to unknown tile name")
  lu.assertEvalToTrue(missing_copy == nil, "unknown kind should not generate tip copy")
end

function TestActionAnimTipText:test_roll_tip_falls_back_to_question_mark_without_rolls_or_total()
  -- L60/L61 两处 "?" 兜底换 nil:rolls/total 缺省时必须落到 ?。
  local state = support.build_min_state()
  local copy = tip_text.build(state, { kind = "roll" })
  lu.assertEvalToTrue(copy == "投骰动画：? => ?",
    "missing rolls and total should both fall back to question marks")
end

function TestActionAnimTipText:test_item_use_tip_falls_back_to_question_mark_without_name_or_id()
  -- L56 兜底 "?" 换 nil:item_name/item_id 全缺时必须落到 ?。
  local state = support.build_min_state()
  local copy = tip_text.build(state, { kind = "item_use" })
  lu.assertEvalToTrue(copy == "道具生效：?", "missing item identity should fall back to a question mark")
end

function TestActionAnimTipText:test_chance_tip_falls_back_to_card_id_then_question_mark()
  -- L100 第二处 or->and 与 "?" 兜底:card_desc 缺省时用 card_id,再缺才落 ?。
  local state = support.build_min_state()
  local id_copy = tip_text.build(state, { kind = "chance", card_id = "card_7" })
  lu.assertEvalToTrue(id_copy == "机会卡展示：card_7", "card_id should backfill a missing card_desc")
  local missing_copy = tip_text.build(state, { kind = "chance" })
  lu.assertEvalToTrue(missing_copy == "机会卡展示：?", "fully missing chance text should fall back to a question mark")
end

function TestActionAnimTipText:test_cash_receive_tip_falls_back_to_question_mark_without_amount()
  -- L135 兜底 "?" 换 nil:amount 缺省时必须落到 ?。
  local state = support.build_min_state()
  local copy = tip_text.build(state, { kind = "cash_receive", player_id = 1 })
  lu.assertEvalToTrue(copy == "收钱动画：测试玩家 +?", "missing cash amount should fall back to a question mark")
end

function TestActionAnimTipText:test_mine_trigger_tip_builds_full_copy()
  -- L126-L130 六连:mine_trigger 文案必须带玩家名与 from/to 地块名。
  local state = support.build_min_state()
  local copy = tip_text.build(state, {
    kind = "mine_trigger",
    player_id = 1,
    from_index = 1,
    to_index = 2,
  })
  lu.assertEvalToTrue(copy == "地雷触发：测试玩家 从 测试地块 到 测试地块",
    "mine_trigger tip should include player and both tile names")
end

function TestActionAnimTipText:test_roadblock_trigger_tip_builds_full_copy()
  -- L153 两连(builder 调用换 nil / 前缀串换 nil):roadblock_trigger 必须带地块名。
  local state = support.build_min_state()
  local copy = tip_text.build(state, { kind = "roadblock_trigger", tile_index = 1 })
  lu.assertEvalToTrue(copy == "路障触发：测试地块",
    "roadblock_trigger tip should include the tile name")
end

function TestActionAnimTipText:test_focus_text_empty_string_falls_through_to_builder()
  -- L159 `focus_text ~= ""` 的 "" 换 nil:空串 focus_text 必须回落到 kind 文案,
  -- 不能原样返回空串。
  local state = support.build_min_state()
  local copy = tip_text.build(state, { kind = "roll", focus_text = "", rolls = { 3 }, total = 3 })
  lu.assertEvalToTrue(copy == "投骰动画：3 => 3",
    "empty focus_text must fall through to the kind builder")
end

function TestActionAnimTipText:test_tile_text_tolerates_a_board_without_get_tile()
  -- L15 `board and board.get_tile` 的 and->or:board 无 get_tile 方法时必须
  -- 回退未知地块,不能把 board 当方法调用报错。
  local state = support.build_min_state({
    mutate = function(s)
      s.game.board = {}
    end,
  })
  local copy = tip_text.build(state, { kind = "roadblock", tile_index = 1 })
  lu.assertEvalToTrue(copy == "路障动画：放置在 未知地块",
    "a board without get_tile should fall back to the unknown tile name")
end


return TestActionAnimTipText
