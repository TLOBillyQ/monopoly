local tip_text = require("src.ui.render.anim_tip_text")
local support = require("support.presentation_action_anim_support")

local function _test_anim_tip_text_builds_named_player_and_clear_obstacles_copy()
  local state = support.build_min_state()

  local target_copy = tip_text.build(state, {
    kind = "item_target_player",
    item_name = "导弹卡",
    target_player_id = 1,
  })
  local clear_copy = tip_text.build(state, {
    kind = "clear_obstacles",
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

  assert(target_copy == "目标道具：导弹卡 -> 玩家 测试玩家",
    "item_target_player tip should resolve runtime player name")
  assert(clear_copy == "清障动画：清除数量 2",
    "clear_obstacles tip should count unique obstacle tiles from branch payload")
end

local function _test_anim_tip_text_falls_back_for_unknown_player_and_change_skin()
  local state = support.build_min_state({
    find_player_by_id = function()
      return nil
    end,
  })

  local target_copy = tip_text.build(state, {
    kind = "item_target_player",
    item_id = 2009,
    target_player_id = 99,
  })
  local change_skin_copy = tip_text.build(state, {
    kind = "change_skin",
    player_id = 99,
    skin_name = "海绵宝宝",
  })

  assert(target_copy == "目标道具：2009 -> 玩家 99",
    "item_target_player tip should fall back to raw player id when lookup is missing")
  assert(change_skin_copy == "换肤动画：99 -> 海绵宝宝",
    "change_skin tip should fall back to raw player id when lookup is missing")
end

local function _test_anim_tip_text_covers_roll_tile_and_cash_variants()
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
    from_index = 1,
    to_index = 2,
  })
  local teleport_copy = tip_text.build(state, {
    kind = "teleport_effect",
    from_index = 1,
    to_index = 2,
  })
  local cash_copy = tip_text.build(state, {
    kind = "cash_receive",
    player_id = 1,
    amount = 500,
  })

  assert(focus_copy == "直接使用焦点文案", "focus_text should override kind-specific copy")
  assert(roll_copy == "投骰动画：2,6 => 8", "roll tip should join rolls and total")
  assert(roadblock_copy == "路障动画：放置在 测试地块", "roadblock tip should resolve tile name")
  assert(move_copy == "位移动画：从 测试地块 到 测试地块", "move_effect tip should resolve both tile names")
  assert(teleport_copy == "位移动画：从 测试地块 到 测试地块", "teleport_effect tip should reuse move copy")
  assert(cash_copy == "收钱动画：测试玩家 +500", "cash_receive tip should resolve player name and amount")
end

local function _test_anim_tip_text_covers_chance_item_and_unknown_tile_variants()
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
    tile_index = 999,
  })
  local monster_copy = tip_text.build(state, {
    kind = "monster",
    tile_index = 999,
  })
  local upgrade_copy = tip_text.build(state, {
    kind = "upgrade_land",
    tile_index = 999,
  })
  local missing_copy = tip_text.build(state, {
    kind = "unknown_kind",
  })

  assert(chance_copy == "机会卡展示：全员发钱", "chance tip should prefer card_desc")
  assert(item_use_copy == "道具生效：freeze_card", "item_use tip should fall back to item_id")
  assert(mine_copy == "地雷动画：埋设在 未知地块", "mine tip should fall back to unknown tile name")
  assert(missile_copy == "导弹动画：轰炸 未知地块", "missile tip should fall back to unknown tile name")
  assert(monster_copy == "怪兽动画：破坏 未知地块", "monster tip should fall back to unknown tile name")
  assert(upgrade_copy == "加盖动画：未知地块", "upgrade_land tip should fall back to unknown tile name")
  assert(missing_copy == nil, "unknown kind should not generate tip copy")
end

return {
  name = "presentation.action_anim_tip_text",
  tests = {
    { name = "anim_tip_text_builds_named_player_and_clear_obstacles_copy", run = _test_anim_tip_text_builds_named_player_and_clear_obstacles_copy },
    { name = "anim_tip_text_falls_back_for_unknown_player_and_change_skin", run = _test_anim_tip_text_falls_back_for_unknown_player_and_change_skin },
    { name = "anim_tip_text_covers_roll_tile_and_cash_variants", run = _test_anim_tip_text_covers_roll_tile_and_cash_variants },
    { name = "anim_tip_text_covers_chance_item_and_unknown_tile_variants", run = _test_anim_tip_text_covers_chance_item_and_unknown_tile_variants },
  },
}
