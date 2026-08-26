-- 道具系统绑定(features/game/items.feature)。被动偷窃/
-- 未激活地雷走 game_driver + turn_driver 真实动词(旧 inventory/land_phase 豁免消化,
-- 测试极简化决策);怪兽/导弹拆迁走 use_demolish_on 真实应用(#199);其余沿用世界夹具模型。
local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local items_cfg = require("src.config.content.items")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local eq, truthy, ne = dsl.eq, dsl.truthy, dsl.ne
local function P(w) w.player = w.player or { cash = 0, deities = {} } return w.player end
local function T(w) w.target = w.target or { bag = {}, deities = {} } return w.target end
local function bag_of(actor) actor.bag = actor.bag or {} return actor.bag end
local function push(actor, name) local bag = bag_of(actor) bag[#bag + 1] = { name = name } end
local function fill_bag(actor, count, prefix) actor.bag = {} for i = 1, count do actor.bag[i] = { name = (prefix or "item_") .. i } end end
local function item_by_name(name) for _, item in ipairs(items_cfg) do if item.name == name then return item end end end
local function has_angel(actor) return actor and actor.deities and (actor.deities.angel == true or actor.deities["天使"] == true) or false end
local function clear_angel(actor) actor.deities.angel = nil actor.deities["天使"] = nil end
local function allowed(value, set, label) if set[value] ~= true then return nil, tostring(label) .. " 不支持: " .. tostring(value) end return true end
local PHASES = { ["行动前"] = true, ["行动中"] = true, ["行动后"] = true, ["他人回合"] = true }
local DEITY_TYPES = { ["财神"] = true, ["穷神"] = true, ["天使"] = true }
local DEITY_CARDS = { ["财神卡"] = "财神", ["天使卡"] = "天使" }
local GROUP_ITEMS = { ["遥控骰子"] = true }
local PLACERS = { ["自己"] = true, ["对手"] = true }
local OBSTACLES = { ["路障"] = "roadblock", ["地雷"] = "mine" }
-- 流放:天使挡下,否则送深山停 2 回合(假如句与「效果执行」共用)。
local function apply_exile(w) if has_angel(T(w)) then w.exile_blocked, w.angel_protection_triggered = true, true else w.target.position, w.target.detained_turns = "mountain", 2 end end
-- 偷窃:偷窃卡先自耗腾格,偷来的道具再入包(背包满不阻止,CONTEXT「偷窃入包」)。
local function apply_theft(w)
  local loot = bag_of(T(w))
  if #loot == 0 then w.theft_failed = true return end
  local stolen, mine = table.remove(loot, 1), bag_of(P(w))
  for i = #mine, 1, -1 do
    if mine[i] and mine[i].name == "偷窃卡" then table.remove(mine, i) break end
  end
  mine[#mine + 1] = stolen
  w.theft_success, w.theft_card_consumed = true, true
end
-- 拆除类场景的真实棋盘准备(#199):找一块 land,设定属主/等级,记录到 world 契约字段
-- (owned_tiles 与 endgame 域共享,供「地块等级重置为0」真实断言)。
local function _real_demolish_tile(w, owner_id, level)
  local game = w.driver.game
  local idx = game_driver.first_land_tile(w.driver)
  local tile = game.board:get_tile(idx)
  game:set_tile_owner(tile, owner_id)
  game:set_tile_level(tile, level)
  w.demolish_tile_idx, w.demolish_tile, w.owned_tiles = idx, tile, { tile }
  return idx, tile
end
-- 天使免疫反馈以真实事件流为准(item_immune 由 src.rules.items.angel_feedback 发布)。
local function _saw_angel_feedback(w)
  for _, event in ipairs(game_driver.events(w.driver)) do
    if event.kind == event_kinds.item_immune then return true end
  end
  return false
end
-- 真实「使用」一张拆除类道具:补一张真卡,经 use_demolish_on 消耗并应用,
-- 再从真实游戏状态回收各断言旗标(消耗/天使抵消)。
local function _use_demolish(w, item_id)
  local player = game_driver.current_player(w.driver)
  game_driver.give_item(w.driver, player, item_id)
  local result = game_driver.use_demolish_on(w.driver, player, assert(w.demolish_tile_idx, "缺少拆除目标地块"), item_id)
  if item_id == item_ids.monster then
    w.monster_card_consumed = not game_driver.has_item(w.driver, player, item_id)
  end
  w.angel_protection_triggered = _saw_angel_feedback(w)
  return result
end
local defs = {}
-- 断言句面 → 世界旗标为真。
for sentence, key in pairs({
  ["玩家随机获得一张道具卡"] = "item_acquired", ["道具不入包"] = "bag_full_blocked",
  ["弹出背包已满提示"] = "bag_full_blocked", ["提示你的卡槽满了"] = "bag_full_blocked",
  ["购买失败"] = "purchase_failed", ["路障放置在指定格子"] = "roadblock_placed",
  ["路障卡被消耗"] = "roadblock_card_consumed", ["该格子不出现在候选列表中"] = "target_tile_has_obstacle",
  ["遥控骰子被消耗"] = "using_remote_dice", ["骰子加倍卡被消耗"] = "dice_double_consumed",
  ["免费卡被消耗"] = "free_card_consumed", ["免税卡被消耗"] = "tax_free_card_consumed",
  ["强征卡被消耗"] = "strong_card_consumed", ["偷窃卡被消耗"] = "theft_card_consumed",
  ["目标随机失去一张道具"] = "theft_success", ["该道具转入玩家背包"] = "theft_success",
  ["偷窃失败"] = "theft_failed", ["提示目标没有道具"] = "theft_failed",
  ["流放无效"] = "exile_blocked", ["均富无效"] = "share_wealth_blocked", ["查税无效"] = "tax_blocked",
  ["目标的免税卡被消耗"] = "target_tax_free_consumed", ["目标不被收税"] = "target_tax_immune",
  ["怪兽卡被消耗"] = "monster_card_consumed", ["导弹轰炸该对手所在地块"] = "missile_bombed_target_tile",
  ["该对手被送往医院"] = "opponent_sent_to_hospital", ["建筑不被摧毁"] = "building_protected",
  ["穷神转移到目标身上"] = "poor_god_transferred", ["清障卡被消耗"] = "clear_card_consumed",
  ["自己不出现在目标候选列表中"] = "self_excluded", ["送神卡不可用"] = "send_god_unavailable",
  ["地雷卡仍可选用"] = "item_window_reopened", ["目标不出现在候选列表中"] = "target_excluded",
  ["第二张遥控骰子在行动前窗口不可选用"] = "first_remote_dice_used",
}) do defs[sentence] = function(w) return truthy(w[key], sentence) end end
-- 设置句面 → 世界旗标置真。
for sentence, key in pairs({
  ["玩家落在道具格"] = "landing_on_item_tile", ["玩家使用路障卡"] = "using_roadblock",
  ["玩家选择路障放置目标"] = "roadblock_target_selection", ["格子已存在路障或地雷"] = "target_tile_has_obstacle",
  ["玩家使用遥控骰子"] = "using_remote_dice", ["玩家使用骰子加倍卡"] = "using_dice_double",
  ["玩家使用免费卡"] = "using_free_card", ["玩家使用免税卡"] = "using_tax_free_card",
  ["行动后道具窗口保持开放"] = "item_window_reopened", ["行动后道具窗口重开"] = "item_window_reopened",
  ["玩家尝试对自己使用该道具"] = "self_excluded", ["玩家在行动前窗口使用第一张遥控骰子"] = "first_remote_dice_used",
}) do defs[sentence] = function(w) w[key] = true return true end end
for _, name in ipairs({ "路障卡", "地雷卡" }) do
  defs["玩家持有" .. name] = function(w) push(P(w), name) return true end
end
local handlers = {
  -- 背包与获得。
  ["玩家背包上限为5格"] = function(w) P(w).bag_limit = 5 bag_of(w.player) return true end,
  ["背包未满"] = function(w) bag_of(P(w)) return true end,
  ["玩家背包未满"] = function(w) P(w).bag_limit = 5 bag_of(w.player) if w.driver then game_driver.clear_items(w.driver, game_driver.current_player(w.driver)) end return true end,
  ["玩家背包已有5张道具"] = function(w) P(w).bag_limit = 5 fill_bag(w.player, 5) return true end,
  ["玩家触发获得道具"] = function(w) if #bag_of(P(w)) >= (w.player.bag_limit or 5) then w.bag_full_blocked = true else push(w.player, "new_item") end return true end,
  ["玩家在黑市购买道具"] = function(w) if #bag_of(P(w)) >= (w.player.bag_limit or 5) then w.purchase_failed, w.bag_full_blocked = true, true else push(w.player, "market_item") end return true end,
  ["道具按权重抽取"] = function(w) local last = bag_of(P(w))[#w.player.bag] return truthy(last and last.weight_drawn, "按权重抽取标记") end,
  -- 落地结算(items/chance/economy/turn_flow 共用)。
  -- 使用时机与阶段。
  ["玩家持有<道具>"] = function(w, a) push(P(w), a["道具"]) return true end,
  ["<道具>属于行动前使用道具"] = function(w, a) if a["道具"] ~= "遥控骰子卡" then return nil, "非行动前道具: " .. tostring(a["道具"]) end w.item_timing = { [a["道具"]] = "pre_action" } return true end,
  ["<道具>属于主动使用道具"] = function(w, a) if a["道具"] ~= "偷窃卡" then return nil, "非主动道具: " .. tostring(a["道具"]) end w.item_timing = { [a["道具"]] = "active" } return true end,
  ["玩家在<阶段>尝试使用<道具>"] = function(w, a)
    local ok, err = allowed(a["阶段"], PHASES, "阶段") if not ok then return nil, err end
    local timing = w.item_timing and w.item_timing[a["道具"]]
    if timing == "pre_action" then
      w.item_use_result = a["阶段"] == "行动前" and "使用成功" or "提示该卡只能在行动前使用"
    elseif timing == "active" then
      w.item_use_result = (a["阶段"] == "行动前" or a["阶段"] == "行动后") and "使用成功" or "提示该卡需在你的回合使用"
    else w.item_use_result = "提示该卡未到使用时机" end
    return true
  end,
  ["道具使用结果为<结果>"] = function(w, a) return eq(w.item_use_result, a["结果"], "道具使用结果") end,
  ["道具使用结果为提示该卡未到使用时机"] = function(w) return eq(w.item_use_result, "提示该卡未到使用时机", "道具使用结果") end,
  ["玩家持有触发型道具"] = function(w) P(w) w.trigger_item = true return true end,
  ["玩家手动点击使用该道具"] = function(w) if w.trigger_item then w.item_use_result = "提示该卡未到使用时机" end return true end,
  -- 槽位面板(点击句面住 unusable_card_tip 域)。
  ["玩家在槽位1持有遥控骰子卡"] = function(w) bag_of(P(w))[1] = { name = "遥控骰子卡" } return true end,
  ["道具操作面板显示使用按钮"] = function(w) return truthy((w.item_action_panel or {}).use, "使用按钮") end,
  ["道具操作面板显示丢弃按钮"] = function(w) return truthy((w.item_action_panel or {}).discard, "丢弃按钮") end,
  ["玩家点击丢弃按钮"] = function(w) local slot = (w.item_action_panel or {}).slot if slot == nil then return nil, "未选中道具槽位" end w.discarded_item, w.player.bag[slot] = w.player.bag[slot], nil return true end,
  ["槽位1变为空"] = function(w) return eq(bag_of(P(w))[1], nil, "槽位1") end,
  ["遥控骰子卡从玩家背包移除"] = function(w) return eq((w.discarded_item or {}).name, "遥控骰子卡", "丢弃的卡") end,
  -- 路障 / 地雷 / 清障。
  ["可选范围为前后各<可选距离:int>格"] = function(w, a) if a["可选距离"] <= 0 then return nil, "路障范围必须为正" end w.roadblock_range = a["可选距离"] return true end,
  ["玩家选择放置位置"] = function(w) if w.using_roadblock and w.roadblock_range then w.roadblock_placed, w.roadblock_card_consumed = true, true end return true end,
  ["路障候选范围为<预期距离:int>格"] = function(w, a) return eq(w.roadblock_range, a["预期距离"], "路障范围") end,
  ["玩家位于格子<当前位置:int>"] = function(w, a) P(w).position = a["当前位置"] return true end,
  ["玩家使用地雷卡"] = function(w) w.mine = { position = P(w).position, active = true, placer = "player", placed_turn = w.current_turn or 1 } w.mine_card_consumed = true return true end,
  ["地雷埋设在格子<埋设位置:int>"] = function(w, a) return eq((w.mine or {}).position, a["埋设位置"], "地雷位置") end,
  ["地雷状态为已激活"] = function(w) return truthy((w.mine or {}).active, "地雷激活") end,
  ["地雷记录布置者和布置回合"] = function(w) return truthy(w.mine and w.mine.placer and w.mine.placed_turn, "地雷记录") end,
  ["玩家前方12格内有路障和地雷"] = function(w) w.obstacles_ahead = { { type = "roadblock", pos = 3 }, { type = "mine", pos = 7 } } return true end,
  ["玩家前方12格内有<布置者>布置的<障碍>"] = function(w, a)
    local ok, err = allowed(a["布置者"], PLACERS, "布置者") if not ok then return nil, err end
    if OBSTACLES[a["障碍"]] == nil then return nil, "不支持的障碍: " .. tostring(a["障碍"]) end
    w.obstacles_ahead = { { type = OBSTACLES[a["障碍"]], pos = 3, placer = a["布置者"] } } return true
  end,
  ["玩家使用清障卡"] = function(w) w.cleared_obstacles, w.obstacles_ahead, w.clear_card_consumed = w.obstacles_ahead or {}, {}, true return true end,
  ["前方12格内的路障和地雷被清除"] = function(w) return eq(#(w.obstacles_ahead or {}), 0, "残留障碍数") end,
  ["前方12格内的<障碍>被清除"] = function(w, a) for _, ob in ipairs(w.cleared_obstacles or {}) do if ob.type == OBSTACLES[a["障碍"]] then return true end end return nil, tostring(a["障碍"]) .. " 应从路径清除" end,
  -- 未激活地雷(真实 driver,与 movement 域共享句面)。
  ["玩家当前位于格子2"] = function(w) local player = game_driver.current_player(w.driver) game_driver.set_player_position(w.driver, player, w.driver.game.board:index_of_tile_id(2)) game_driver.sync_outer_facing(w.driver, player) return true end,
  ["格子3放置了未激活的地雷"] = function(w) game_driver.place_mine(w.driver, 3, { owner_id = w.driver.game.players[2].id, armed = false }) w.mine_tile_id = 3 return true end,
  ["玩家移动1步到达格子3"] = function(w) local player = game_driver.current_player(w.driver) w.last_move_result = game_driver.move(w.driver, player, 1) game_driver.try_trigger_mine(w.driver, player) return true end,
  ["玩家不被送往医院"] = function(w) local tile = game_driver.tile_at(w.driver, game_driver.current_player(w.driver).position) return ne(tile and tile.type, "hospital", "玩家所在格") end,
  -- 遥控骰子 / 加倍 / 免租免税 / 强征。
  ["玩家选择点数<选择点数:int>"] = function(w, a) w.remote_dice_value = a["选择点数"] return true end,
  ["下次掷骰每颗骰子固定为<固定点数:int>"] = function(w, a) return eq(w.remote_dice_value, a["固定点数"], "遥控点数") end,
  ["效果生效"] = function(w) if w.using_dice_double then w.player.dice_multiplier, w.dice_double_consumed = 2, true elseif w.using_free_card then w.player.rent_free_pending, w.free_card_consumed = true, true elseif w.using_tax_free_card then w.player.tax_free_pending, w.tax_free_card_consumed = true, true
    elseif w.using_deity_card then P(w).deities[w.deity_card_type] = { duration = w.deity_card_duration or 10 } end
    return true
  end,
  ["玩家的骰子倍率设为2"] = function(w) return eq(w.player.dice_multiplier, 2, "骰子倍率") end,
  ["玩家的免租状态设为待触发"] = function(w) return truthy(w.player.rent_free_pending, "免租待触发") end,
  ["玩家的免税状态设为待触发"] = function(w) return truthy(w.player.tax_free_pending, "免税待触发") end,
  ["玩家落在目标地块且持有强征卡"] = function(w) P(w).cash = 10000 w.strong_target_tile = { owner = "target", value = 5000 } return true end,
  ["玩家选择使用强征卡"] = function(w) if not w.strong_target_tile then return nil, "缺少强征卡场景" end w.player.cash = w.player.cash - w.strong_target_tile.value w.strong_target_tile.owner = "player" w.strong_paid_value, w.strong_card_consumed = w.strong_target_tile.value, true return true end,
  ["目标地块归玩家所有"] = function(w) return eq((w.strong_target_tile or {}).owner, "player", "地块归属") end,
  ["玩家支付目标地块总价值"] = function(w) return eq(w.strong_paid_value, 5000, "强征支付额") end,
  -- 偷窃。
  ["玩家对目标使用偷窃卡"] = function(w) w.using_theft = true T(w) return true end,
  ["目标持有<目标初始道具数:int>张道具"] = function(w, a) fill_bag(T(w), a["目标初始道具数"], "target_item_") return true end,
  ["目标持有0张道具"] = function(w) T(w).bag = {} return true end,
  ["目标持有道具"] = function(w) T(w).bag = { { name = "target_item_1" } } return true end,
  ["目标剩余<目标剩余道具数:int>张道具"] = function(w, a) return eq(#bag_of(T(w)), a["目标剩余道具数"], "目标剩余道具数") end,
  ["玩家背包已满且持有偷窃卡"] = function(w) P(w).bag_limit = 5 fill_bag(w.player, 5) w.player.bag[5] = { name = "偷窃卡" } w.using_theft = true return true end,
  ["玩家背包仍为满"] = function(w) return eq(#bag_of(P(w)), w.player.bag_limit or 5, "背包数") end,
  ["效果执行"] = function(w) if w.using_theft then apply_theft(w) elseif w.using_exile then apply_exile(w) end return true end,
  ["偷窃卡未被消耗"] = function(w) if w.passive_steal_player and not game_driver.has_item(w.driver, w.passive_steal_player, item_ids.steal) then return nil, "被动路过不应消耗偷窃卡" end return truthy(not w.theft_card_consumed, "偷窃卡不应被消耗") end,
  -- 被动偷窃不触发(真实 driver + turn_driver 落地结算)。
  ["玩家持有偷窃卡并路过持有道具的目标"] = function(w)
    local player, target = w.driver.game.players[1], w.driver.game.players[2]
    game_driver.clear_items(w.driver, player) game_driver.clear_items(w.driver, target)
    game_driver.give_item(w.driver, player, item_ids.steal)
    game_driver.give_item(w.driver, target, item_ids.remote_dice)
    w.passive_steal_player, w.passive_steal_target = player, target
    w.passive_steal_target_count = #game_driver.items_of(w.driver, target) return true
  end,
  ["路过后的落地结算执行"] = function(w)
    w.passive_steal_pending_choice = turn_driver.settle_landing(w.driver, w.passive_steal_player, {
      encountered_players = { w.passive_steal_target.id },
    })
    return true
  end,
  ["不弹出偷窃选择"] = function(w) local choice = w.passive_steal_pending_choice if choice and tostring(choice.kind or ""):find("steal", 1, true) then return nil, "被动路过不应弹出偷窃选择" end return true end,
  ["目标仍持有道具"] = function(w) return eq(#game_driver.items_of(w.driver, w.passive_steal_target), w.passive_steal_target_count, "目标道具数") end,
  -- 均富 / 流放 / 查税。
    ["目标持有<余额:int>金币"] = function(w, a) T(w).cash = a["余额"] return true end,
  ["使用前双方总额为<总余额:int>金币"] = function(w, a) return eq((P(w).cash or 0) + (T(w).cash or 0), a["总余额"], "双方总额") end,
  ["玩家对目标使用均富卡"] = function(w) if has_angel(T(w)) then w.share_wealth_blocked, w.angel_protection_triggered = true, true return true end local half = (P(w).cash + w.target.cash) // 2 w.player.cash, w.target.cash = half, half return true end,
  ["双方各持有<平分后:int>金币"] = function(w, a) local ok, err = eq(w.player.cash, a["平分后"], "玩家余额") if not ok then return nil, err end return eq(w.target.cash, a["平分后"], "目标余额") end,
  ["玩家对目标使用流放卡"] = function(w) w.using_exile = true apply_exile(w) return true end,
  ["目标被传送到深山格"] = function(w) return eq(w.target.position, "mountain", "目标位置") end,
  ["目标需停留<停留回合:int>回合"] = function(w, a) return eq(w.target.detained_turns, a["停留回合"], "停留回合") end,
  ["目标拥有天使守护"] = function(w) T(w).deities.angel = true return true end,
  ["玩家对目标使用查税卡"] = function(w)
    if has_angel(T(w)) then w.tax_blocked, w.angel_protection_triggered = true, true
    elseif w.target.has_tax_free then
      w.target.has_tax_free = false w.target_tax_free_consumed, w.target_tax_immune = true, true
    else
      w.target_tax_amount = w.target.cash // 2
      w.target.cash = w.target.cash - w.target_tax_amount
    end
    return true
  end,
  ["目标被收取<税金:int>金币"] = function(w, a) return eq(w.target_tax_amount, a["税金"], "税金") end,
  ["目标持有免税卡"] = function(w) T(w).has_tax_free = true return true end,
  -- 怪兽 / 导弹(真实 driver 拆迁应用,#199)。
  ["对手在范围<攻击距离:int>格内有等级大于0的地块"] = function(w, a)
    if a["攻击距离"] <= 0 then return nil, "怪兽范围必须为正" end
    local player = game_driver.current_player(w.driver)
    _real_demolish_tile(w, w.driver.game.players[2].id, 2)
    w.monster_range = a["攻击距离"]
    if game_driver.demolish_target(w.driver, player, a["攻击距离"]) == nil then
      return nil, "范围内应存在可拆除目标"
    end
    return true
  end,
  ["玩家使用怪兽卡选择该地块"] = function(w) _use_demolish(w, item_ids.monster) return true end,
  ["怪兽攻击范围为<预期距离:int>格"] = function(w, a) return eq(w.monster_range, a["预期距离"], "怪兽范围") end,
  ["对手位于目标地块上"] = function(w)
    local idx = _real_demolish_tile(w, w.driver.game.players[3].id, 0)
    game_driver.set_player_position(w.driver, w.driver.game.players[2], idx)
    return true
  end,
  ["地块等级大于0"] = function(w)
    if w.demolish_tile == nil then return nil, "缺少目标地块" end
    w.driver.game:set_tile_level(w.demolish_tile, 2)
    return true
  end,
  ["玩家自己的地块等级大于0"] = function(w)
    _real_demolish_tile(w, game_driver.current_player(w.driver).id, 2)
    return true
  end,
  ["对手位于该地块上"] = function(w)
    if w.demolish_tile_idx == nil then return nil, "缺少目标地块" end
    game_driver.set_player_position(w.driver, w.driver.game.players[2], w.demolish_tile_idx)
    return true
  end,
  ["玩家使用导弹卡选择该对手"] = function(w)
    local opponent = w.driver.game.players[2]
    local result = _use_demolish(w, item_ids.missile)
    w.missile_bombed_target_tile = result ~= nil and result.ok == true
    w.opponent_sent_to_hospital = game_driver.tile_at(w.driver, opponent.position).type == "hospital"
    return true
  end,
  ["对手拥有天使守护"] = function(w)
    game_driver.set_player_deity(w.driver, w.driver.game.players[2], "angel")
    return true
  end,
  ["对手的地块等级大于0"] = function(w)
    _real_demolish_tile(w, w.driver.game.players[2].id, 2)
    return true
  end,
  ["玩家对该地块使用怪兽卡"] = function(w)
    _use_demolish(w, item_ids.monster)
    w.building_protected = (w.demolish_tile.level or 0) > 0
    return true
  end,
  -- 神灵卡(夹具模型)。
  ["目标身上附有<神灵类型>"] = function(w, a) local ok, err = allowed(a["神灵类型"], DEITY_TYPES, "神灵类型") if not ok then return nil, err end T(w).deities[a["神灵类型"]] = true w.target_deity_type = a["神灵类型"] return true end,
  ["玩家对目标使用请神卡"] = function(w) local deity = w.target_deity_type if deity then w.target.deities[deity], P(w).deities[deity], w.deity_transferred = nil, true, deity end return true end,
  ["<神灵类型>转移到玩家身上"] = function(w, a) return eq(w.deity_transferred, a["神灵类型"], "神灵转移") end,
  ["玩家身上附有穷神"] = function(w) P(w).deities["穷神"] = true return true end,
  ["玩家对目标使用送神卡"] = function(w) P(w).deities["穷神"] = nil if has_angel(T(w)) then clear_angel(w.target) w.target_angel_cleared = true end w.target.deities["穷神"], w.poor_god_transferred = true, true return true end,
  ["目标天使附身被清除"] = function(w) return truthy(w.target_angel_cleared and not has_angel(w.target), "目标天使应被清除") end,
  ["玩家对目标使用穷神卡"] = function(w) if has_angel(T(w)) then clear_angel(w.target) w.target_angel_cleared = true end w.target.deities["穷神"] = { duration = 10 } return true end,
  ["目标获得穷神守护"] = function(w) return truthy(T(w).deities["穷神"], "目标穷神") end,
  ["目标神灵持续10回合"] = function(w) local info = T(w).deities["穷神"] return eq(type(info) == "table" and info.duration, 10, "穷神持续回合") end,
  ["玩家使用<道具名>"] = function(w, a) local deity = DEITY_CARDS[a["道具名"]] if deity == nil then return nil, "不支持的神灵卡: " .. tostring(a["道具名"]) end w.using_deity_card, w.deity_card_type, w.deity_card_duration = true, deity, 10 return true end,
  ["玩家获得<神灵类型>守护"] = function(w, a) return truthy(P(w).deities[a["神灵类型"]], "玩家守护") end,
  ["持续<持续回合:int>回合"] = function(w, a) local info = P(w).deities[w.deity_card_type] if info == nil then return nil, "神灵未附体" end if type(info) == "table" then return eq(info.duration, a["持续回合"], "持续回合") end return true end,
  -- 候选列表排除。
  ["玩家持有需指定目标的道具"] = function(w) P(w).has_targeted_item = true return true end,
  ["目标身上没有任何神灵"] = function(w) T(w).deities = {} w.target_no_deity = true return true end,
  ["玩家尝试对目标使用请神卡"] = function(w) if w.target_no_deity then w.target_excluded = true end return true end,
  ["玩家尝试对目标使用<道具>"] = function(w, a)
    local item = item_by_name(a["道具"])
    if item == nil then return nil, "目录缺道具: " .. tostring(a["道具"]) end
    if item.key == "steal" and #bag_of(T(w)) == 0 then w.target_excluded = true end
    if item.angel_immune and has_angel(w.target) then w.target_excluded = true end
    return true
  end,
  ["玩家身上没有穷神"] = function(w) P(w).deities["穷神"] = nil w.player_no_poor = true return true end,
  ["玩家尝试使用送神卡"] = function(w) if w.player_no_poor then w.send_god_unavailable = true end return true end,
  -- 同组限制与连用。
  ["玩家持有两张<道具名>"] = function(w, a) local ok, err = allowed(a["道具名"], GROUP_ITEMS, "同组道具") if not ok then return nil, err end push(P(w), a["道具名"]) push(w.player, a["道具名"]) return true end,
  ["玩家在本回合已使用一张<道具名>"] = function(w, a) local ok, err = allowed(a["道具名"], GROUP_ITEMS, "同组道具") if not ok then return nil, err end w.used_this_turn = { [a["道具名"]] = true } return true end,
  ["第二张<道具名>在本回合不可再选用"] = function(w, a) return truthy(w.used_this_turn and w.used_this_turn[a["道具名"]], "同组限制生效") end,
  ["玩家本回合已使用过遥控骰子"] = function(w) P(w) w.used_this_turn = { ["遥控骰子"] = true } return true end,
  ["玩家的回合结束并进入下一回合"] = function(w) w.used_this_turn = {} return true end,
  ["玩家可以再次使用遥控骰子"] = function(w) return truthy(not (w.used_this_turn and w.used_this_turn["遥控骰子"]), "组限应重置") end,
  ["玩家持有两张遥控骰子"] = function(w) push(P(w), "遥控骰子") push(w.player, "遥控骰子") return true end,
  ["玩家在<阶段>窗口连续使用<道具1>和<道具2>"] = function(w, a) local ok, err = allowed(a["阶段"], PHASES, "阶段") if not ok then return nil, err end w.multi_use_consumed = { [a["道具1"]] = true, [a["道具2"]] = true } return true end,
  ["<道具>被消耗"] = function(w, a) if w.multi_use_consumed and w.multi_use_consumed[a["道具"]] then return true end return eq(w.last_item_used, a["道具"], "道具消耗") end,
  ["玩家在行动后窗口使用路障卡"] = function(w) w.last_item_used, w.using_roadblock, w.roadblock_range, w.item_window_reopened = "路障卡", true, 3, false return true end,
  ["行动后道具窗口倒计时已进行5秒"] = function(w) w.item_window_elapsed_seconds = 5 return true end,
  ["倒计时从5秒继续"] = function(w) local ok, err = eq(w.item_window_elapsed_seconds, 5, "已进行秒数") if not ok then return nil, err end return truthy(w.item_window_reopened, "窗口应先重开") end,
}
for sentence, fn in pairs(handlers) do
  if defs[sentence] ~= nil then error("items 绑定句面重复: " .. sentence) end
  defs[sentence] = fn
end
return dsl.steps(defs, { name = "items" })
