local dsl = require("packages.acceptance.step_dsl")
local gd = require("packages.acceptance.game_driver")
local td = require("packages.acceptance.turn_driver")
local number_utils = require("src.foundation.number")
local item_ids = require("src.config.gameplay.item_ids")
local event_kinds = require("src.config.gameplay.event_kinds")
local constants = require("src.config.content.constants")
-- 回合流程域（turn_flow.feature + main_turn_buttons.feature）：轮转/扣留/落地
-- 结算/超时/AI 决策全走 turn_driver + game_driver 真实回合机；旧实现越界
-- require 的 src.rules.items.inventory 已消化为 game_driver.give_item。
-- 主回合按钮句族的机器（presenter 刷新 + route_base 意图 +
-- optional_action_completion 完成语义）住在 features/steps/base_screen.lua
-- （#597 按视角重划）；本文件只保留角色身份句的 world 绑定。
local function _ctx(w) return w.driver end
local function _game(w) return w.driver.game end
local function _p(w, i) return w.driver.game.players[i] end
local function _ai(w) return _p(w, 2) end
local function _opp(w) return _p(w, 1) end
local _RENT_TILE_ID = 1
-- 顺次 eq 断言（<实际, 期望, 标签> 三元组），第一处失败即返回。
local function _eqs(...)
  local t = table.pack(...)
  for i = 1, t.n, 3 do
    local ok, msg = dsl.eq(t[i], t[i + 1], t[i + 2])
    if not ok then return nil, msg end
  end
  return true
end
local function _human_game(w, count)
  local names = {}
  for i = 1, count do names[i] = "玩家" .. i end
  w.driver = gd.new_game({ players = names, ai = {} })
end
local function _human4_as(w, seat) _human_game(w, 4); td.set_current_player(_ctx(w), seat); return true end
local function _seat_forward(w, player, index)
  local game, map = _game(w), _game(w).board.map
  game:update_player_position(player, index)
  local tile_id = game.board:get_tile(index).id
  if map.outer_next[tile_id] then
    game:set_player_status(player, "move_dir", map.direction(tile_id, map.outer_next[tile_id]))
  end
end
local function _seat_before_type(w, player, tile_type, back)
  local game, map, idx = _game(w), _game(w).board.map, nil
  for i = 1, _ctx(w).outer_ring_size do
    local tile = game.board:get_tile(i)
    if tile and tile.type == tile_type then idx = i break end
  end
  local id = game.board:get_tile(assert(idx, "no " .. tile_type .. " tile")).id
  for _ = 1, back do id = map.outer_prev[id] end
  _seat_forward(w, player, game.board:index_of_tile_id(id))
end
local function _seat_for_rent(w)
  local p1 = _p(w, 1)
  gd.set_tile_owner(_ctx(w), _RENT_TILE_ID, _p(w, 2).id)
  local tile = _game(w).board:get_tile_by_id(_RENT_TILE_ID)
  tile.price, tile.level = 1000, 0
  gd.seat_before_tile(_ctx(w), p1, _RENT_TILE_ID); gd.set_next_rolls(_ctx(w), { 1 })
  return p1
end
local function _open_market_choice(w)
  gd.set_market_sold_out(_ctx(w)); gd.seat_to_pass_through_market(_ctx(w), _p(w, 1))
  return td.advance_to_choice(_ctx(w))
end
local function _open_normal_choice(w)
  gd.give_item(_ctx(w), _seat_for_rent(w), item_ids.strong)
  return td.advance_to_choice(_ctx(w))
end
local function _rotate_back_to_seat1(w)
  for _ = 1, td.participant_count(_ctx(w)) do
    if td.current_player_index(_ctx(w)) == 1 then break end
    td.play_turn(_ctx(w))
  end
  return dsl.eq(td.current_player_index(_ctx(w)), 1, "轮转回到席位1")
end
local function _rolls_and_moves(w, player)
  local before = player.position
  td.play_turn(_ctx(w))
  return dsl.ne(player.position, before, "回合内移动后的位置")
end
local function _play_turn(w) td.play_turn(_ctx(w)) return true end
local function _detain_seat1(w, turns) _human4_as(w, 1); td.detain(_ctx(w), _p(w, 1), turns); w.detained = _p(w, 1) return true end
local function _arm_elapse(w, s) td.arm_choice_deadline(_ctx(w)); td.elapse_choice_deadline(_ctx(w), s) return true end
local function _give1(w, id) gd.give_item(_ctx(w), _p(w, 1), id) return true end
local function _steal_setup(w)
  _human4_as(w, 1); _give1(w, item_ids.steal); gd.give_item(_ctx(w), _p(w, 2), item_ids.mine)
  return true
end
-- AI 落地共用就位：取首块 land，按需改归属，记录席位/等级/现金基线。
local function _ai_land(w, owner_id)
  local idx, tile_id = gd.first_land_tile(_ctx(w))
  if owner_id then gd.set_tile_owner(_ctx(w), tile_id, owner_id) end
  gd.set_player_position(_ctx(w), _ai(w), idx)
  w.ai_tile_idx, w.ai_level_before = idx, gd.tile_level(_ctx(w), idx)
  w.ai_cash_before = gd.player_cash(_ctx(w), _ai(w))
end
local function _ai_settle_auto(w)
  td.settle_landing(_ctx(w), _ai(w))
  w.ai_landing_option = td.auto_resolve_landing_choice(_ctx(w))
  return true
end
local _AI_CARD_IDS = {
  ["遥控骰子卡"] = item_ids.remote_dice, ["路障卡"] = item_ids.roadblock, ["偷窃卡"] = item_ids.steal,
  ["怪兽卡"] = item_ids.monster, ["均富卡"] = item_ids.share_wealth, ["流放卡"] = item_ids.exile,
  ["导弹卡"] = item_ids.missile, ["查税卡"] = item_ids.tax, ["请神卡"] = item_ids.invite_deity,
  ["送神卡"] = item_ids.send_poor, ["穷神卡"] = item_ids.poor, ["其他卡"] = item_ids.mine,
}
local function _richer_opp(w) _game(w):set_player_cash(_opp(w), 999999) end
local function _item_tile_ahead(w) _seat_before_type(w, _ai(w), "item", 2) end
local _TRIGGER_SETUPS = {
  ["移动范围内存在道具格"] = _item_tile_ahead, ["前方存在道具格"] = _item_tile_ahead,
  ["存在持有道具的其他玩家"] = function(w) gd.give_item(_ctx(w), _opp(w), item_ids.mine) end,
  ["前后3格内存在他人等级最高的建筑"] = function(w)
    local game = _game(w)
    _seat_forward(w, _ai(w), 5)
    local id = game.board.map.outer_next[game.board.map.outer_next[game.board:get_tile(5).id]]
    local tile = game.board:get_tile(game.board:index_of_tile_id(id))
    tile.type = "land"; game:set_tile_owner(tile, _opp(w).id); tile.level = 2
  end,
  ["电脑玩家不是现金最多的角色"] = _richer_opp, ["存在其他现金最多的角色"] = _richer_opp,
  ["其他角色附有天使"] = function(w) _game(w):set_player_deity(_opp(w), "angel", 5) end,
  ["其他角色附有财神且无人附有天使"] = function(w) _game(w):set_player_deity(_opp(w), "rich", 5) end,
  ["电脑玩家附有穷神且存在现金最多对手"] = function(w) _game(w):set_player_deity(_ai(w), "poor", 5); _richer_opp(w) end,
  ["道具当前可用"] = function() end,
}
local _PHASES = { ["开始"] = "start", ["等待行动"] = "wait_action", ["掷骰"] = "roll",
  ["移动"] = "move", ["落地"] = "landing", ["结束"] = "end_turn" }
local _WARN_LEVELS = { ["警告"] = "warn_5s", ["紧急"] = "warn_3s" }
local _CHOICE_KINDS = { ["普通选择"] = "rent_card_prompt", ["黑市购买"] = "market_buy",
  ["道具目标选择"] = "item_target_player" }
local function _set_cur(w, a) td.set_current_player(_ctx(w), a["当前玩家"]) return true end
return dsl.steps({
  ["游戏有<玩家人数:int>名玩家参与"] = function(w, a) _human_game(w, a["玩家人数"]) return true end,
  ["游戏当前玩家数为<验证玩家人数:int>名"] = function(w, a) return dsl.eq(td.participant_count(_ctx(w)), a["验证玩家人数"], "参与玩家数") end,
  ["当前是玩家<当前玩家:int>的回合"] = _set_cur, ["当前是玩家{当前玩家:int}的回合"] = _set_cur,
  ["回合结束"] = _play_turn, ["玩家1的回合结束"] = _play_turn,
  ["下一回合轮到玩家<下一玩家:int>"] = function(w, a) return dsl.eq(td.current_player_index(_ctx(w)), a["下一玩家"], "下一回合玩家") end,
  ["四人human局中玩家2已被淘汰"] = function(w) _human_game(w, 4); td.eliminate(_ctx(w), _p(w, 2)) return true end,
  ["跳过玩家2直接轮到玩家3"] = function(w) return dsl.eq(td.current_player_index(_ctx(w)), 3, "跳过淘汰席后的当前玩家") end,
  ["玩家需停留<剩余回合:int>回合"] = function(w, a) _detain_seat1(w, a["剩余回合"]); w.position_before = w.detained.position return true end,
  ["该玩家的回合开始"] = function(w) w.detain_seq = td.observe_turn_phases(_ctx(w)) return true end,
  ["玩家无法掷骰和移动"] = function(w)
    for _, phase in ipairs(w.detain_seq or {}) do
      if phase == "roll" or phase == "move" then return nil, "被扣留却进入了阶段 " .. phase end
    end
    return dsl.eq(w.detained.position, w.position_before, "被扣留玩家位置")
  end,
  ["剩余停留回合变为<减后回合:int>"] = function(w, a) return dsl.eq(td.stay_turns(_ctx(w), w.detained), a["减后回合"], "剩余停留回合") end,
  ["回合直接结束"] = function(w)
    local saw = {}
    for _, phase in ipairs(w.detain_seq or {}) do saw[phase] = true end
    return dsl.truthy(saw.start and saw.end_turn, "扣留回合的 start→end_turn")
  end,
  ["玩家剩余停留回合为1"] = function(w) return _detain_seat1(w, 1) end,
  ["该玩家的扣留回合结束"] = _play_turn,
  ["下一次轮到该玩家"] = _rotate_back_to_seat1,
  ["玩家可以正常掷骰"] = function(w)
    local ok, msg = dsl.eq(td.stay_turns(_ctx(w), w.detained), 0, "扣留残留回合")
    if not ok then return nil, msg end
    return _rolls_and_moves(w, w.detained)
  end,
  ["玩家落在医院被扣留"] = function(w) return _detain_seat1(w, constants.hospital_stay_turns) end,
  ["进入第<扣留回合序号:int>个扣留回合"] = function(w, a)
    -- 锚定被扣留席位自己的 detained 事件条数（#255）：旧口径靠 play_turn 前采样
    -- current_player_index==1 计数，但被扣留席位在 start 阶段 yield detained_wait、
    -- 永不 park 在 wait_action，其扣留回合会被吞进某个起始于旁座的多席位连驱内部，
    -- 采样点上 current==1 永不出现 → 该轮漏计（旁座 RNG 落医院触发扣留时漂移）。
    -- 每个扣留回合起始恰发一条本席位的 detained 提示（start.lua 的
    -- _configure_detained_wait），事件条数 == 已历经的扣留回合数；数到第 N 条即
    -- 稳定推进到 seat-1 第 N 个扣留回合起始，脱离连驱边界的隐式口径。前缀锚定与
    -- 姊妹步骤「扣留提示显示剩余回合为…」一致（名字后带「 被扣留」区分 玩家1/玩家1x）。
    local prefix = w.detained.name .. " 被扣留"
    local function detained_turns()
      local n = 0
      for _, event in ipairs(gd.events(_ctx(w))) do
        if event.kind == event_kinds.detained and tostring(event.text):sub(1, #prefix) == prefix then
          n = n + 1
        end
      end
      return n
    end
    local guard = 0
    while detained_turns() < a["扣留回合序号"] do
      td.play_turn(_ctx(w))
      guard = guard + 1
      if guard > 400 then return nil, "驱动超预算仍未达到第 " .. a["扣留回合序号"] .. " 个扣留回合" end
    end
    return true
  end,
  ["扣留提示显示剩余回合为<显示剩余回合:int>"] = function(w, a)
    -- 只认被扣留玩家自己的扣留提示（#254）：全序跑时别的玩家 RNG 落医院同样发扣留
    -- 提示，取全局最后一条会读到旁人的剩余回合。前缀带上「 被扣留」（名字与词之间
    -- 的空格）把 玩家1 与 玩家1x 区分开，锚定到本例被扣留席位。
    local prefix = w.detained.name .. " 被扣留"
    local latest
    for _, event in ipairs(gd.events(_ctx(w))) do
      if event.kind == event_kinds.detained and tostring(event.text):sub(1, #prefix) == prefix then
        latest = event
      end
    end
    if latest == nil then return nil, "没有发布被扣留提示" end
    local shown = number_utils.to_integer(tostring(latest.text):match("剩余回合[:：]%s*(%d+)"))
    return dsl.eq(shown, a["显示剩余回合"], "扣留提示剩余回合（" .. tostring(latest.text) .. "）")
  end,
  ["玩家本回合使用了遥控骰子"] = function(w) _human4_as(w, 1); gd.apply_remote_dice(_ctx(w), _p(w, 1), 1, 1) return true end,
  ["玩家本回合触发了骰子加倍卡"] = function(w) gd.set_dice_multiplier(_ctx(w), _p(w, 1), 2) return true end,
  ["玩家的回合结束"] = _play_turn,
  ["遥控骰子效果被清除"] = function(w) return dsl.eq(td.pending_remote_dice(_ctx(w), _p(w, 1)), nil, "遥控骰子残留") end,
  ["骰子加倍倍率重置为1"] = function(w) return dsl.eq(td.dice_multiplier(_ctx(w), _p(w, 1)), 1, "骰子加倍倍率") end,
  ["玩家未被扣留且未被淘汰"] = function(w) return _human4_as(w, 1) end,
  ["玩家的回合开始"] = function(w) w.phase_seq = td.observe_turn_phases(_ctx(w)) return true end,
  ["依次经过阶段<阶段序列>"] = function(w, a)
    local tokens = {}
    for name in tostring(a["阶段序列"]):gmatch("[^→]+") do
      local token = _PHASES[name:match("^%s*(.-)%s*$")]
      if token == nil then return nil, "未知阶段名: " .. tostring(name) end
      tokens[#tokens + 1] = token
    end
    local cursor = 1
    for _, observed in ipairs(w.phase_seq or {}) do
      if observed == tokens[cursor] then cursor = cursor + 1 end
      if cursor > #tokens then return true end
    end
    return nil, "真实阶段序未按序包含期望里程碑"
  end,
  ["玩家落在黑市格"] = function(w) _human4_as(w, 1); w.market_id = gd.seat_to_land_on_market(_ctx(w), _p(w, 1)) return true end,
  ["黑市所有商品已售罄"] = function(w) gd.set_market_sold_out(_ctx(w)) return true end,
  ["回合落地结算执行"] = function(w)
    w.p1_cash_before = gd.player_cash(_ctx(w), _p(w, 1)); w.landing_choice = td.advance_to_choice(_ctx(w))
    return true
  end,
  ["不弹出购买选择"] = function(w) return dsl.eq(w.landing_choice, nil, "售罄黑市的购买选择") end,
  ["回合直接进入结束阶段"] = function(w)
    local landed = _game(w).board:get_tile(_p(w, 1).position)
    return _eqs(td.pending_choice(_ctx(w)), nil, "滞留的待处理选择", landed and landed.id, w.market_id, "落地格")
  end,
  ["玩家本回合落在对手拥有的地块"] = function(w) _human4_as(w, 1); _seat_for_rent(w) return true end,
  ["玩家持有免租卡"] = function(w) return _give1(w, item_ids.free_rent) end,
  ["免租卡被自动消耗"] = function(w) return dsl.eq(gd.has_item(_ctx(w), _p(w, 1), item_ids.free_rent), false, "免租卡残留") end,
  ["不需要玩家手动选择"] = function(w) return dsl.eq(w.landing_choice, nil, "免租的手动选择") end,
  ["玩家不支付租金"] = function(w) return dsl.eq(gd.player_cash(_ctx(w), _p(w, 1)), w.p1_cash_before, "结算后现金") end,
  ["玩家同时持有强夺卡和免租卡"] = function(w) _give1(w, item_ids.strong) return _give1(w, item_ids.free_rent) end,
  ["先弹出强夺卡使用提示"] = function(w)
    local c = w.landing_choice
    return dsl.truthy(c and c.kind == "rent_card_prompt" and c.meta and c.meta.card_kind == "strong", "强夺卡优先提示")
  end,
  ["若玩家拒绝强夺则自动消耗免租卡"] = function(w)
    td.resolve_choice(_ctx(w), "skip")
    return _eqs(gd.has_item(_ctx(w), _p(w, 1), item_ids.strong), true, "强夺卡保留",
      gd.has_item(_ctx(w), _p(w, 1), item_ids.free_rent), false, "免租卡消耗")
  end,
  ["玩家面临<选择类型>选择"] = function(w, a)
    w.is_target_select = false
    local label = a["选择类型"]
    if label == "普通选择" then _human4_as(w, 1); w.opened_choice = _open_normal_choice(w)
    elseif label == "黑市购买" then _human4_as(w, 1); w.opened_choice = _open_market_choice(w)
    elseif label == "道具目标选择" then
      _steal_setup(w)
      w.opened_choice = td.open_target_item_choice(_ctx(w), _p(w, 1), item_ids.steal)
      w.is_target_select = true
    else return nil, "未知选择类型: " .. tostring(label) end
    return true
  end,
  ["当前选择类型为<验证选择类型>"] = function(w, a)
    local choice = td.pending_choice(_ctx(w))
    return dsl.eq(choice and choice.kind, _CHOICE_KINDS[a["验证选择类型"]], "待处理选择类型")
  end,
  ["超时时间为<超时秒数:int>秒"] = function(w, a) w.expected_timeout = a["超时秒数"] return true end,
  ["选择超时配置为<验证超时秒数:int>秒"] = function(w, a) return dsl.eq(td.choice_timeout_seconds(_ctx(w)), a["验证超时秒数"], "选择超时配置") end,
  ["玩家在超时时间内未操作"] = function(w)
    local timeout = w.expected_timeout or td.choice_timeout_seconds(_ctx(w))
    w.original_choice_kind = td.pending_choice(_ctx(w)).kind
    local arm = w.is_target_select and td.arm_target_select_deadline or td.arm_choice_deadline
    local elapse = w.is_target_select and td.elapse_target_select_deadline or td.elapse_choice_deadline
    local level = w.is_target_select and td.target_select_deadline_level or td.choice_deadline_level
    arm(_ctx(w)); elapse(_ctx(w), timeout - 5); w.warn_level = level(_ctx(w)); elapse(_ctx(w), 6)
    return true
  end,
  ["系统在剩余<警告秒数:int>秒时发出警告"] = function(w, a) return _eqs(a["警告秒数"], 5, "警告阈值口径", w.warn_level, "warn_5s", "警告级别") end,
  ["超时后自动执行默认选项"] = function(w)
    local choice = td.pending_choice(_ctx(w))
    return dsl.ne(choice and choice.kind, w.original_choice_kind, "超时后残留的原选择")
  end,
  ["回合间等待时间已配置"] = function(w) return _human4_as(w, 1) end,
  ["当前玩家的回合结束"] = function(w) td.advance_to_inter_turn_wait(_ctx(w)) return true end,
  ["经过等待间隔后下一玩家回合才开始"] = function(w)
    local seconds = td.inter_turn_wait_seconds(_ctx(w))
    if not (seconds and seconds > 0) then return nil, "回合间隔未配置为正数" end
    local ok, msg = dsl.eq(td.current_player_index(_ctx(w)), 1, "间隔内的当前玩家")
    if not ok then return nil, msg end
    td.elapse_inter_turn_wait(_ctx(w), seconds)
    return dsl.eq(td.current_player_index(_ctx(w)), 2, "间隔后交棒")
  end,
  ["玩家本回合因路障停止移动"] = function(w)
    _human4_as(w, 1)
    local map = _game(w).board.map
    gd.place_roadblock(_ctx(w), map.outer_next[map.outer_next[_game(w).board:get_tile(_p(w, 1).position).id]])
    gd.set_next_rolls(_ctx(w), { 5 })
    return _play_turn(w)
  end,
  ["下一回合轮到该玩家"] = _rotate_back_to_seat1,
  ["玩家可以正常掷骰和移动"] = function(w)
    local ok, msg = dsl.eq(td.stay_turns(_ctx(w), _p(w, 1)), 0, "路障后的扣留回合")
    if not ok then return nil, msg end
    return _rolls_and_moves(w, _p(w, 1))
  end,
  ["不会被额外扣留"] = function(w) return dsl.eq(td.stay_turns(_ctx(w), _p(w, 1)), 0, "额外扣留回合") end,
  ["玩家面临黑市购买选择"] = function(w) _human4_as(w, 1); w.opened_choice = _open_market_choice(w) return true end,
  ["玩家当前金币为5000"] = function(w) _game(w):set_player_cash(_p(w, 1), 5000) return true end,
  ["超时未操作系统自动跳过"] = function(w) return _arm_elapse(w, 61) end,
  ["玩家金币仍为5000"] = function(w) return dsl.eq(gd.player_cash(_ctx(w), _p(w, 1)), 5000, "超时跳过后的金币") end,
  ["玩家持有一张需指定目标的道具"] = _steal_setup,
  ["玩家已发起使用但尚未选定目标"] = function(w)
    local choice = td.open_target_item_choice(_ctx(w), _p(w, 1), item_ids.steal)
    return _eqs(choice and choice.kind, "item_target_player", "目标选择弹出",
      gd.has_item(_ctx(w), _p(w, 1), item_ids.steal), true, "道具预消耗")
  end,
  ["目标选择超时系统自动取消"] = function(w) td.arm_target_select_deadline(_ctx(w)); td.elapse_target_select_deadline(_ctx(w), 16) return true end,
  ["该道具未被消耗仍在玩家背包"] = function(w) return dsl.eq(gd.has_item(_ctx(w), _p(w, 1), item_ids.steal), true, "超时后道具在包") end,
  ["玩家面临选择且超时时间为<超时秒数:int>秒"] = function(w, a)
    _human4_as(w, 1); w.expected_timeout = a["超时秒数"]; w.opened_choice = _open_normal_choice(w)
    return true
  end,
  ["剩余时间降至<警告阈值:int>秒"] = function(w, a)
    local timeout = w.expected_timeout or td.choice_timeout_seconds(_ctx(w))
    td.arm_choice_deadline(_ctx(w)); w.threshold = a["警告阈值"]
    if w.threshold > 0 then
      td.elapse_choice_deadline(_ctx(w), timeout - w.threshold)
      w.warn_level = td.choice_deadline_level(_ctx(w))
    else
      w.original_kind = td.pending_choice(_ctx(w)).kind
      td.elapse_choice_deadline(_ctx(w), timeout + 1)
      local choice = td.pending_choice(_ctx(w))
      w.expired = (choice == nil) or (choice.kind ~= w.original_kind)
    end
    return true
  end,
  ["倒计时状态变为<警告级别>"] = function(w, a)
    if a["警告级别"] == "到期" then return dsl.truthy(w.expired, "到期自动结算") end
    local expected = _WARN_LEVELS[a["警告级别"]]
    if expected == nil then return nil, "未知警告级别: " .. tostring(a["警告级别"]) end
    return dsl.eq(w.warn_level, expected, "警告级别")
  end,
  ["每个警告级别仅触发一次"] = function(w)
    if w.threshold == 0 then
      td.elapse_choice_deadline(_ctx(w), 5)
      return dsl.truthy(w.expired, "到期结果保持已结算")
    end
    return dsl.eq(td.choice_deadline_level(_ctx(w)), w.warn_level, "级别重读稳定")
  end,
  ["玩家面临选择且弹窗已打开"] = function(w) _human4_as(w, 1); w.opened_choice = _open_normal_choice(w) return dsl.truthy(w.opened_choice, "选择弹窗") end,
  ["选择超时系统自动决定"] = function(w) return _arm_elapse(w, 16) end,
  ["选择弹窗被关闭"] = function(w) return dsl.eq(td.pending_choice(_ctx(w)), nil, "超时后弹窗") end,
  ["待处理选择指示被清除"] = function(w) return dsl.eq(td.pending_choice(_ctx(w)), nil, "待处理选择指示") end,
  ["玩家路过黑市且黑市窗口打开"] = function(w)
    _human4_as(w, 1); w.opened_choice = _open_market_choice(w)
    local ok, msg = dsl.eq(w.opened_choice and w.opened_choice.kind, "market_buy", "黑市购买窗口")
    if not ok then return nil, msg end
    td.arm_choice_deadline(_ctx(w)); w.remaining_before = td.choice_deadline_remaining(_ctx(w))
    return true
  end,
  ["行动计时器运行中"] = function(w) return dsl.truthy(w.remaining_before and w.remaining_before > 0, "行动计时器") end,
  ["计时器继续倒计时不暂停"] = function(w)
    td.elapse_choice_deadline(_ctx(w), 5)
    local now = td.choice_deadline_remaining(_ctx(w))
    return dsl.truthy(now and now < w.remaining_before, "倒计时递减")
  end,
  ["当前玩家的回合已结束"] = function(w) _human4_as(w, 1); td.reset_tips(_ctx(w)); td.advance_to_inter_turn_wait(_ctx(w)) return true end,
  ["正在显示阻断性游戏提示"] = function(w) td.hold_inter_turn_with_blocking_tip(_ctx(w)) return true end,
  ["回合间等待时间到期"] = function(w) td.elapse_inter_turn_wait(_ctx(w), 5) return true end,
  ["等待提示显示完毕后才切换到下一玩家回合"] = function(w)
    local ok, msg = dsl.eq(td.current_player_index(_ctx(w)), 1, "阻断提示期间的当前玩家")
    if not ok then return nil, msg end
    td.reset_tips(_ctx(w)); td.elapse_inter_turn_wait(_ctx(w), 5)
    return dsl.eq(td.current_player_index(_ctx(w)), 2, "提示清除后交棒")
  end,
  ["本回合行动玩家是电脑"] = function(w)
    w.driver = gd.new_game(); td.set_current_player(_ctx(w), 2)
    return dsl.truthy(td.is_computer_controlled(_ctx(w), _ai(w)), "席位2为电脑")
  end,
  ["电脑玩家持有充足金币"] = function(w) w.ai_cash_before = gd.player_cash(_ctx(w), _ai(w)) return true end,
  ["电脑玩家落在无主地块"] = function(w) _ai_land(w) return _ai_settle_auto(w) end,
  ["系统自动执行购买"] = function(w)
    local ok, msg = _eqs(w.ai_landing_option, "buy_land", "AI 落地决策",
      gd.tile_owner(_ctx(w), w.ai_tile_idx), _ai(w).id, "地块归属")
    if not ok then return nil, msg end
    return dsl.truthy(gd.player_cash(_ctx(w), _ai(w)) < w.ai_cash_before, "购地扣款")
  end,
  ["电脑玩家落在自有可升级地块"] = function(w) _ai_land(w, _ai(w).id) return _ai_settle_auto(w) end,
  ["系统自动执行升级"] = function(w)
    local ok, msg = dsl.eq(w.ai_landing_option, "upgrade_land", "AI 落地决策")
    if not ok then return nil, msg end
    ok, msg = dsl.truthy(gd.tile_level(_ctx(w), w.ai_tile_idx) > w.ai_level_before, "地块升级")
    if not ok then return nil, msg end
    return dsl.truthy(gd.player_cash(_ctx(w), _ai(w)) < w.ai_cash_before, "升级扣款")
  end,
  ["电脑玩家持有免租卡"] = function(w) gd.give_item(_ctx(w), _ai(w), item_ids.free_rent) return true end,
  ["电脑玩家落在需付租金的对手地块"] = function(w) _ai_land(w, _opp(w).id); w.ai_landing_choice = td.settle_landing(_ctx(w), _ai(w)) return true end,
  ["系统自动消耗免租卡"] = function(w)
    return _eqs(gd.has_item(_ctx(w), _ai(w), item_ids.free_rent), false, "免租卡残留",
      w.ai_landing_choice, nil, "免租的手动选择",
      gd.player_cash(_ctx(w), _ai(w)), w.ai_cash_before, "免租后现金")
  end,
  ["电脑玩家背包中持有满足触发条件的主动道具"] = function(w)
    gd.give_item(_ctx(w), _ai(w), item_ids.clear_obstacles); gd.seat_with_obstacle_ahead(_ctx(w), _ai(w))
    w.ai_card_id = item_ids.clear_obstacles
    return true
  end,
  ["电脑玩家背包中持有<道具>"] = function(w, a)
    w.ai_card_id = _AI_CARD_IDS[a["道具"]]
    if w.ai_card_id == nil then return nil, "未知 AI 卡牌: " .. tostring(a["道具"]) end
    gd.give_item(_ctx(w), _ai(w), w.ai_card_id)
    return true
  end,
  ["棋盘状态满足<触发条件>"] = function(w, a)
    local setup = _TRIGGER_SETUPS[a["触发条件"]]
    if setup == nil then return nil, "未知触发条件: " .. tostring(a["触发条件"]) end
    setup(w)
    return true
  end,
  ["电脑玩家的道具使用阶段执行"] = function(w)
    td.run_ai_item_phase(_ctx(w), _ai(w), "pre_action")
    if gd.has_item(_ctx(w), _ai(w), w.ai_card_id) then td.run_ai_item_phase(_ctx(w), _ai(w), "post_action") end
    return true
  end,
  ["该道具被自动消耗"] = function(w) return dsl.eq(gd.has_item(_ctx(w), _ai(w), w.ai_card_id), false, "触发道具残留") end,
  ["该<道具>被消耗"] = function(w, a) return dsl.eq(gd.has_item(_ctx(w), _ai(w), _AI_CARD_IDS[a["道具"]]), false, a["道具"] .. "残留") end,
  -- 主回合按钮（main_turn_buttons，基础屏微驱动）。
  ["玩家角色ID为<观察角色ID:int>"] = function(w, a) w.ui_role_id = a["观察角色ID"] return true end,
  ["当前轮到角色ID为<角色ID:int>"] = function(w, a) w.bs_action_role_id, w.bs_action_role_unset = a["角色ID"], false return true end,
}, { name = "turn_flow" })
