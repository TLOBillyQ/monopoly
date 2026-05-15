local tip_text = require("src.ui.render.anim.tip_text")
local support = require("spec.support.ui_action_anim_support")

describe("presentation.action_anim_tip_text", function()
  it("anim_tip_text_builds_named_player_and_clear_obstacles_copy", function()
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

    assert(target_copy == "测试玩家 对 测试玩家 使用了 导弹卡",
      "item_target_player tip should resolve runtime player name")
    assert(clear_copy == "测试玩家 的清障机器人出动，清除了 1 个路障、1 个地雷",
      "clear_obstacles tip should list obstacle types from anim payload")
  end)

  it("anim_tip_text_covers_roll_tile_and_cash_variants", function()
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
      amount = 500,
    })

    assert(focus_copy == "直接使用焦点文案", "focus_text should override kind-specific copy")
    assert(roll_copy == "投骰动画：2,6 => 8", "roll tip should join rolls and total")
    assert(roadblock_copy == "路障动画：放置在 测试地块", "roadblock tip should resolve tile name")
    assert(move_copy == "位移动画：测试玩家 从 测试地块 到 测试地块", "move_effect debug tip should include from and to")
    assert(teleport_copy == "测试玩家 被传送到 测试地块", "teleport_effect tip should show player-facing format")
    assert(cash_copy == "收钱动画：测试玩家 +500", "cash_receive tip should resolve player name and amount")
  end)

  it("anim_tip_text_covers_chance_item_and_unknown_tile_variants", function()
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

    assert(chance_copy == "机会卡展示：全员发钱", "chance tip should prefer card_desc")
    assert(item_use_copy == "道具生效：freeze_card", "item_use tip should fall back to item_id")
    assert(mine_copy == "地雷动画：埋设在 未知地块", "mine tip should fall back to unknown tile name")
    assert(missile_copy == "测试玩家 发射导弹轰炸 未知地块", "missile tip should fall back to unknown tile name")
    assert(monster_copy == "测试玩家 释放怪兽攻击 未知地块", "monster tip should fall back to unknown tile name")
    assert(upgrade_copy == "加盖动画：未知地块", "upgrade_land tip should fall back to unknown tile name")
    assert(missing_copy == nil, "unknown kind should not generate tip copy")
  end)
end)
