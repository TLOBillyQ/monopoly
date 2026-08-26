-- 不可用道具卡点击提示绑定(features/v103/unusable_card_tip.feature)。
-- 全部场景走**同一条**真实链路:真实背包(driver 道具动词)+ 真实道具阶段窗
-- (回合机开窗 / driver.open_item_phase)→ 真 route_item_slots.build_intent(带点击者 role)
-- → 真 turn 派发 → item_slot_click 单一裁定 → 提示经 tip_output_port 捕获。
-- 「阶段内 / 阶段外」不再是两条代码路径:UI 不判阶段,裁定只有一处,所以验收
-- 也只该有一条路径——早先分叉的桩正是「他人回合」被测成「自己回合」的假绿来源。
-- 「玩家点击道具槽位1」为共享句面:items.feature 的槽位面板夹具分支也住这里。
local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local turn_driver = require("packages.acceptance.turn_driver")
local turn_dispatch = require("src.turn.actions.action_dispatcher")
local control = require("src.player.control")
local items_cfg = require("src.config.content.items")
local route_item_slots = require("src.ui.input.route_item_slots")
local eq, truthy = dsl.eq, dsl.truthy
local FILLER_CANDIDATES_BY_PHASE = {
  pre_action = { "遥控骰子卡", "路障卡" },
  post_action = { "查税卡", "路障卡" },
}
-- 阶段外时段 → 当前回合玩家的角色ID(本地玩家恒为背景声明的 1)。「他人回合」
-- 必须真的把回合交给别人:裁定读的是 game.turn.current_player_index。
local LOCAL_ROLE_ID = 1
local IDLE_PERIODS = { ["自己回合的行动等待阶段"] = LOCAL_ROLE_ID, ["他人回合"] = 2 }
local SLOT_NODES = { "基础_道具1", "基础_道具2", "基础_道具3", "基础_道具4", "基础_道具5" }
local function _role(role_id) return { get_roleid = function() return role_id end } end
local function _game(w) return w.driver.game end
local function _player(w) return _game(w).players[1] end
local function _cfg(name) for _, item in ipairs(items_cfg) do if item.name == name then return item end end return nil end
-- 道具 offer 窗口阶段:优先行动前,其次行动后,触发型卡兜底行动前(必然拒 offer)。
local function _pick_phase(cfg) local phases = type(cfg.offer_in_phases) == "table" and cfg.offer_in_phases or {} for _, want in ipairs({ "pre_action", "post_action" }) do for _, phase in ipairs(phases) do if phase == want then return want end end end return "pre_action" end
local function _capture_tips(w) w.pi_tips = {} _game(w).tip_output_port = { enqueue = function(_, intent) w.pi_tips[#w.pi_tips + 1] = intent return true end, } end
local function _idle(w) w.uct_idle = w.uct_idle or {} return w.uct_idle end
local function _hold_idle(w, name) local cfg = _cfg(name) if cfg == nil then return nil, "unknown item: " .. tostring(name) end game_driver.clear_items(w.driver, _player(w)) game_driver.give_item(w.driver, _player(w), cfg.id) _capture_tips(w) _idle(w) return true end
local function _set_period(w, period) local current = IDLE_PERIODS[period] if current == nil then return nil, "unknown 阶段外时段: " .. tostring(period) end _game(w).turn.current_player_index = current return true end
local function _tip_shown(w, expected) if w.pi_tips == nil then return nil, "无提示捕获;持卡步骤应先执行" end for _, tip in ipairs(w.pi_tips) do if tip.text == expected then return true end end return nil, "缺少预期提示: " .. expected end
-- 点击的展示态只需要「有哪些槽位节点」与「有没有弹层遮挡」——槽位 → 道具由 turn
-- 层直读行动者背包,验收不再需要任何 UI 槽位镜像(那正是老设计的口径分叉处)。
local function _click_slot(w, slot_index)
  local overlay_role_id = (w.uct_idle or {}).overlay_role_id
  local state = { ui = { item_slots = SLOT_NODES,
    -- 弹层归属逐席位:operator_role_id 就是「这块屏幕上盖着弹层」的那个席位。
    popup_active = overlay_role_id ~= nil, current_action_role_id = overlay_role_id } }
  local spec = route_item_slots.build(state)[slot_index]
  if spec == nil then return nil, "槽位" .. tostring(slot_index) .. "未建出 route spec" end
  local intent = spec.build_intent({ role = _role(LOCAL_ROLE_ID) })
  if intent == nil then
    w.uct_click_result = { status = "occluded" }
    return true
  end
  w.uct_click_result = turn_dispatch.dispatch_action(_game(w), {}, intent, nil)
  return true
end
-- 目标卡开窗即不可 offer 时,补一张同阶段可 offer 的填充卡让窗口能开(快照语义下
-- 窗口只装可 offer 项,ADR 0038)。填充候选按序取第一张;局面先铺时首选填充可能同样
-- 死于该局面(如全天使下的查税卡),回退次选(路障不挑玩家目标,局面免疫)。
local function _give_filler(w, player, item_id, phase)
  for _, name in ipairs(assert(FILLER_CANDIDATES_BY_PHASE[phase], "missing filler candidates")) do
    local filler = assert(_cfg(name), "missing filler item cfg")
    if filler.id ~= item_id and game_driver.item_offer_allowed(w.driver, player, filler.id, phase) then
      game_driver.give_item(w.driver, player, filler.id)
      return true
    end
  end
  return nil, "阶段 " .. tostring(phase) .. " 无可用填充道具"
end
-- 场景 011(#341/#601)专用点击:匿名点击(事件不携带身份)必须按无主处理静默。
-- 「上一次点击者缓存」已整体退役,跨点击共享 state 的前提随之消失。
-- role_data 可带 .role(点击者身份);fresh_tips 时重装提示捕获,断言只量本次点击。
local function _click_slot_as(w, slot_index, role_data, fresh_tips)
  if fresh_tips then _capture_tips(w) end
  local overlay_role_id = (w.uct_idle or {}).overlay_role_id
  local state = { ui = {
    item_slots = SLOT_NODES,
    popup_active = overlay_role_id ~= nil,
    current_action_role_id = overlay_role_id,
  } }
  local spec = route_item_slots.build(state)[slot_index]
  if spec == nil then return nil, "槽位" .. tostring(slot_index) .. "未建出 route spec" end
  local intent = spec.build_intent(role_data or {})
  if intent == nil then
    w.uct_click_result = { status = "occluded" }
    return true
  end
  w.uct_click_result = turn_dispatch.dispatch_action(_game(w), {}, intent, nil)
  return true
end

local function _open_phase(w, player, item_id, phase)
  if game_driver.item_offer_allowed(w.driver, player, item_id, phase) then
    -- 正向局面(卡可 offer):让真实回合机自己开窗——手工 open_item_phase 的窗会被
    -- 回合协程首次 step 时自开的新窗顶掉,choice_id 失配后点击被静默丢弃,
    -- 「进入使用流程」断言测的是从未发生的事(与 base_screen 域同款假阳性,已修)。
    local window = turn_driver.advance_to_item_window(w.driver)
    return truthy(window ~= nil and (window.meta and window.meta.phase) == phase,
      "道具阶段窗未由回合机开出: " .. tostring(item_id) .. " @" .. phase)
  end
  -- 负向局面(卡不可 offer):补填充卡手工开窗即可——不可用卡在 item_slot_click
  -- 裁定的 availability 分支就被拒并弹提示,不进回合机,choice_id 失配无从发生。
  local ok, err = _give_filler(w, player, item_id, phase)
  if not ok then return nil, err end
  local spec = game_driver.open_item_phase(w.driver, player, phase, { next_state = "wait_action" })
  return truthy(spec, "道具阶段 choice 未建成: " .. tostring(item_id) .. " @" .. phase)
end
local _situations = {
  ["所有对手都没有神灵"] = function(w, game, opponents) for _, opp in ipairs(opponents) do game:clear_player_deity(opp) end return true end,
  ["所有对手都有天使守护"] = function(w, game, opponents) for _, opp in ipairs(opponents) do game:set_player_deity(opp, "angel") end return true end,
  -- 请神卡只请正面神灵:对手只剩穷神即无候选(deities_009/010)。
  ["所有对手都只有穷神"] = function(_, game, opponents) for _, opp in ipairs(opponents) do game:set_player_deity(opp, "poor") end return true end,
  ["自己没有穷神附身"] = function(w, game) game:clear_player_deity(_player(w)) return truthy(not game:player_has_deity(_player(w), "poor"), "不应有穷神") end,
  ["所有对手都没有道具"] = function(w, _, opponents) for _, opp in ipairs(opponents) do game_driver.clear_items(w.driver, opp) end return true end,
  ["所有对手都已出局"] = function(_, game, opponents) for _, opp in ipairs(opponents) do game:set_player_eliminated(opp, true) end return true end,
  -- 路障对托管玩家走 auto_candidates(带障碍过滤):候选格全压上路障即无候选。
  ["前后三格内没有可放置的格子"] = function(w, game)
    local player = _player(w)
    control.toggle_manual_delegation(player)
    for _ = 1, 16 do
      local candidates = game_driver.roadblock_candidates(w.driver, player, 3)
      if #candidates == 0 then return true end
      for _, cand in ipairs(candidates) do game:place_roadblock(cand.idx) end
    end
    return nil, "3 格内路障候选应可耗尽"
  end,
  ["附近没有可拆除的建筑"] = function(w, game)
    local player = _player(w)
    for _, idx in ipairs(game_driver.tile_indices_in_range(w.driver, player.position, 3)) do
      local tile = game.board:get_tile(idx)
      if tile and tile.type == "land" then
        tile.owner_id, tile.level = nil, 0
      end
    end
    return eq(game_driver.demolish_target(w.driver, player, 3), nil, "3 格内拆除目标")
  end,
  -- 强征/免费卡的无目标上下文:玩家不站在任何对手地上(默认起点非 land,
  -- 若站上 land 则清为无主,租金响应上下文不成立)。
  ["自己不站在对手地上"] = function(w, game)
    local tile = game.board:get_tile(_player(w).position)
    if tile and tile.type == "land" then
      tile.owner_id = nil
    end
    return true
  end,
}
return dsl.steps({
  -- 背景字面量(与 base_screen 域的参数化句面同义,字面句 shape 匹配不上,补精确 key)。
  ["当前轮到角色ID为1"] = function(w) w.base_screen_action_role_id, w.base_screen_action_role_unset = 1, false return true end,
  ["玩家处于包含道具槽位的可选行动阶段"] = function(w) w.base_screen_optional_action = "道具槽位" return true end,
  ["玩家在槽位1持有<道具>"] = function(w, a)
    local name = tostring(a["道具"] or "")
    -- 未声明可选行动阶段(阶段外大纲)走 idle 持有:不开道具阶段 choice。
    if w.base_screen_optional_action == nil then return _hold_idle(w, name) end
    local cfg = _cfg(name)
    if cfg == nil then return nil, "unknown item: " .. name end
    local player = _player(w)
    game_driver.clear_items(w.driver, player)
    game_driver.give_item(w.driver, player, cfg.id)
    local phase = _pick_phase(cfg)
    local ok, err = _open_phase(w, player, cfg.id, phase)
    if not ok then return nil, err end
    _capture_tips(w)
    local pending = _game(w).turn.pending_choice
    w.uct = { item_id = cfg.id, phase = phase, choice_id = pending and pending.id or nil }
    w.uct_real_click = true
    return true
  end,
  ["玩家在槽位1持有请神卡"] = function(w) return _hold_idle(w, "请神卡") end,
  -- 大纲字面步骤 <无目标局面>:按例子列值分发到局面实现。
  ["<无目标局面>"] = function(w, a)
    local situation = _situations[tostring(a["无目标局面"] or "")]
    if situation == nil then return nil, "unknown 无目标局面: " .. tostring(a["无目标局面"]) end
    local game = _game(w)
    local opponents = {}
    for i = 2, #game.players do opponents[#opponents + 1] = game.players[i] end
    return situation(w, game, opponents)
  end,
  -- 共享句面:本域走真实链路,items.feature 的槽位面板夹具分支保留。
  ["玩家点击道具槽位1"] = function(w)
    if w.uct_idle ~= nil or w.uct_real_click == true then return _click_slot(w, 1) end
    if not (w.player and w.player.bag and w.player.bag[1]) then return nil, "槽位1应有道具" end
    w.item_action_panel = { use = true, discard = true, slot = 1 }
    return true
  end,
  -- 场景 011(#341/#601):匿名点击按无主处理静默——提示断言只量本次点击,
  -- 点击前重装提示捕获。
  ["点击事件未携带身份的玩家点击道具槽位1"] = function(w) return _click_slot_as(w, 1, {}, true) end,
  ['提示"{提示文案}"已显示'] = function(w, a) return _tip_shown(w, tostring(a["提示文案"] or "")) end,
  ['提示"{提示文案}"未显示'] = function(w, a)
    if w.pi_tips == nil then return nil, "无提示捕获;持卡/空槽步骤应先执行" end
    local expected = tostring(a["提示文案"] or "")
    for _, tip in ipairs(w.pi_tips) do if tip.text == expected then return nil, "该提示不应显示: " .. expected end end
    return true
  end,
  -- #205:强征卡余额上下文与效果组已用,全部落真实游戏状态。
  ["自己站在对手地上且现金不足以支付强征费用"] = function(w)
    local game, p1 = _game(w), _player(w)
    local idx = game_driver.first_land_tile(w.driver)
    local tile = game.board:get_tile(idx)
    game:set_tile_owner(tile, game.players[2].id)
    game:set_tile_level(tile, 2)
    game_driver.set_player_position(w.driver, p1, idx)
    game:set_player_cash(p1, 0)
    return true
  end,
  ["本回合已使用过<道具>"] = function(w, a)
    local cfg = _cfg(tostring(a["道具"] or ""))
    if cfg == nil then return nil, "unknown item: " .. tostring(a["道具"]) end
    if cfg.effect_group == nil then return nil, cfg.name .. " 不属于任何效果组" end
    local game = _game(w)
    game.turn.used_effect_groups = game.turn.used_effect_groups or {}
    game.turn.used_effect_groups[cfg.effect_group] = true
    return true
  end,
  ["当前处于<阶段外时段>"] = function(w, a) return _set_period(w, tostring(a["阶段外时段"] or "")) end,
  ["当前处于自己回合的行动等待阶段"] = function(w) return _set_period(w, "自己回合的行动等待阶段") end,
  ["当前处于他人回合"] = function(w) return _set_period(w, "他人回合") end,
  ["玩家托管状态为开启"] = function(w) control.toggle_manual_delegation(_player(w)) return true end,
  ["自己屏幕上有弹层正在显示"] = function(w) _idle(w).overlay_role_id = LOCAL_ROLE_ID return true end,
  ["对手屏幕上有弹层正在显示"] = function(w) _idle(w).overlay_role_id = 2 return true end,
  ["玩家道具槽位1为空"] = function(w) game_driver.clear_items(w.driver, _player(w)) _capture_tips(w) _idle(w) return true end,
  ["<道具>当前可用"] = function(w, a)
    local cfg = _cfg(tostring(a["道具"] or ""))
    if cfg == nil then return nil, "unknown item: " .. tostring(a["道具"]) end
    local ok, reason = game_driver.item_offer_allowed(w.driver, _player(w), cfg.id, (w.uct or {}).phase)
    if not ok then return nil, cfg.name .. " 应可用,拒因: " .. tostring(reason) end
    return true
  end,
  ["道具操作面板未弹出"] = function(w) return eq(w.item_action_panel, nil, "道具操作面板") end,
  ["槽位1仍持有<道具>"] = function(w, a) local cfg = _cfg(tostring(a["道具"] or "")) if cfg == nil then return nil, "unknown item: " .. tostring(a["道具"]) end local held = game_driver.items_of(w.driver, _player(w))[1] return eq(held and held.id, cfg.id, "槽位1持有") end,
  -- 「进入使用流程」的唯一可信凭据是 followup choice 真实打开(rules 装饰的
  -- meta.passive_origin/item_id);「pending.id 变了」不算数——回合机自开新窗
  -- 也会换 id(修复前的假阳性口径)。
  ["玩家进入<道具>的使用流程"] = function(w, a)
    local result = w.uct_click_result
    if not (result and result.status == "applied") then
      return nil, "槽位点击应 applied,实际: " .. tostring(result and result.status)
    end
    local pending = _game(w).turn.pending_choice
    if not (pending and pending.meta and pending.meta.passive_origin == true) then
      return nil, "使用 " .. tostring(a["道具"]) .. " 应打开后续选择,实际 pending: "
        .. tostring(pending and pending.kind)
    end
    return eq(pending.meta.item_id, w.uct and w.uct.item_id, "后续选择归属道具")
  end,
}, { name = "unusable_card_tip" })
