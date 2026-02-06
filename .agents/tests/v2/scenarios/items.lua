local t = dofile(".agents/tests/v2/helpers/testkit.lua")

local function _target_land_in_range(state, seat)
  local options = t.services.item.pick_demolish_targets(state, seat, 3)
  return options[1] and tonumber(options[1].id) or nil
end

local function _prepare_enemy_land(state, seat)
  local index, tile_id = t.find_first_land(state)
  local player = state.players[seat]
  player.position = index
  local target_index = index + 1
  if target_index > #state.board.path then
    target_index = 1
  end
  local target_tile_id = state.board.path[target_index]
  if not state.board.tile_defs[target_tile_id] or state.board.tile_defs[target_tile_id].type ~= "land" then
    target_index = index
    target_tile_id = tile_id
  end
  t.set_land_owner(state, target_tile_id, 2, 2)
  return target_index, target_tile_id
end

local function _test_remote_dice_manual_choice()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2002)
  local res = t.services.item.apply_manual_item(state, 1, 2002)
  t.assert_true(res.waiting == true, "遥控骰子应进入等待选择")
  t.assert_eq(res.choice.kind, "remote_dice_value", "应生成点数选择")
end

local function _test_remote_dice_resolve()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2002)
  local res = t.services.item.resolve_remote_dice(state, 1, 5)
  t.assert_true(res.ok == true, "遥控骰子解析应成功")
  t.assert_eq(state.players[1].status.pending_remote_dice.values[1], 5, "应写入待投点数")
end

local function _test_roadblock_place()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2004)
  local options = t.services.item.pick_roadblock_targets(state, 1, 3)
  t.assert_true(#options > 0, "路障卡应有可选目标")
  local index = tonumber(options[1].id)
  local res = t.services.item.resolve_roadblock(state, 1, index)
  t.assert_true(res.ok == true, "放置路障应成功")
  t.assert_true(state.board.overlays.roadblocks[index] == true, "目标位置应有路障")
end

local function _test_monster_demolish()
  local service = t.new_service()
  local state = service:state()
  local _, _ = _prepare_enemy_land(state, 1)
  t.give_item(state, 1, 2008)
  local target_index = _target_land_in_range(state, 1)
  t.assert_true(target_index ~= nil, "怪兽卡应找到可拆目标")
  local target_tile_id = state.board.path[target_index]
  local res = t.services.item.resolve_demolish(state, 1, 2008, target_index)
  t.assert_true(res.ok == true, "怪兽卡释放应成功")
  t.assert_eq(state.board.tile_states[target_tile_id].level, 0, "建筑等级应被清空")
end

local function _test_missile_hits_player_and_overlay()
  local service = t.new_service()
  local state = service:state()
  local target_index, _ = _prepare_enemy_land(state, 1)
  t.give_item(state, 1, 2013)
  state.board.overlays.roadblocks[target_index] = true
  state.board.overlays.mines[target_index] = true
  state.players[2].position = target_index
  local res = t.services.item.resolve_demolish(state, 1, 2013, target_index)
  t.assert_true(res.ok == true, "导弹卡释放应成功")
  t.assert_eq(state.board.overlays.roadblocks[target_index], nil, "导弹后路障应清除")
  t.assert_eq(state.board.overlays.mines[target_index], nil, "导弹后地雷应清除")
  t.assert_true((state.players[2].status.stay_turns or 0) > 0, "目标玩家应被送医停留")
end

local function _test_share_wealth()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2011)
  state.players[1].cash = 10000
  state.players[2].cash = 50000
  local res = t.services.item.resolve_item_target(state, 1, 2011, 2)
  t.assert_true(res.ok == true, "均富卡应成功")
  t.assert_eq(state.players[1].cash, 30000, "均富后现金应平分")
  t.assert_eq(state.players[2].cash, 30000, "均富后现金应平分")
end

local function _test_tax_target()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2014)
  state.players[2].cash = 50000
  local res = t.services.item.resolve_item_target(state, 1, 2014, 2)
  t.assert_true(res.ok == true, "查税卡应成功")
  t.assert_eq(state.players[2].cash, 25000, "目标现金应减半")
end

local function _test_clear_obstacles()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2006)
  state.board.overlays.roadblocks[2] = true
  state.board.overlays.mines[3] = true
  local res = t.services.item.apply_manual_item(state, 1, 2006)
  t.assert_true(res.ok == true, "清障卡应成功")
  t.assert_eq(state.board.overlays.roadblocks[2], nil, "路障应被清除")
  t.assert_eq(state.board.overlays.mines[3], nil, "地雷应被清除")
end

local function _test_steal_item_transfer()
  local service = t.new_service()
  local state = service:state()
  t.give_item(state, 1, 2007)
  t.give_item(state, 2, 2001)
  local owner_before = #state.players[1].inventory.items
  local target_before = #state.players[2].inventory.items
  local res = t.services.item.resolve_steal(state, 1, 2, 1)
  t.assert_true(res.ok == true, "偷窃应成功")
  t.assert_true(#state.players[1].inventory.items >= owner_before, "偷窃后背包不应减少")
  t.assert_true(#state.players[2].inventory.items < target_before, "目标应减少道具")
end

return {
  { name = "item/remote_dice_choice", run = _test_remote_dice_manual_choice },
  { name = "item/remote_dice_resolve", run = _test_remote_dice_resolve },
  { name = "item/roadblock_place", run = _test_roadblock_place },
  { name = "item/monster_demolish", run = _test_monster_demolish },
  { name = "item/missile_demolish", run = _test_missile_hits_player_and_overlay },
  { name = "item/share_wealth", run = _test_share_wealth },
  { name = "item/tax_target", run = _test_tax_target },
  { name = "item/clear_obstacles", run = _test_clear_obstacles },
  { name = "item/steal_transfer", run = _test_steal_item_transfer },
}
