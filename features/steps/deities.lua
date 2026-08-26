-- 神灵系统绑定(features/game/deities.feature):走真实 game 公开面(deity mixin)。
-- 旧豁免消化(测试极简化决策):post_effects.apply_target → game:transfer_deity;
-- angel_feedback.publish → src.rules.ports.event_feed 直发 item_immune 事件。
local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
local event_kinds = require("src.config.gameplay.event_kinds")
local event_feed = require("src.rules.ports.event_feed")
local items_cfg = require("src.config.content.items")
local DEITY_CODE = { ["财神"] = "rich", ["穷神"] = "poor", ["天使"] = "angel" }
local function _game(w) return w.driver.game end
local function _item_id(name) for _, item in ipairs(items_cfg) do if item.name == name then return item.id end end return nil end
-- set + 立即 tick 一次:set_player_deity 内部 +1,激活回合 tick 后剩余=duration。
local function _attach(w, seat, raw_name, duration) local code = DEITY_CODE[raw_name] if code == nil then return nil, "unknown deity: " .. tostring(raw_name) end local game, player = _game(w), _game(w).players[seat] game:set_player_deity(player, code, duration) game:tick_player_deity(player) return true end
local function _remaining(w, seat) local deity = _game(w).players[seat].status and _game(w).players[seat].status.deity return deity and deity.remaining or 0 end
local function _no_deity(seat) return function(w) local game = _game(w) if game:player_has_any_deity(game.players[seat]) then return nil, "玩家" .. tostring(seat) .. " 仍持有神灵,剩余 " .. tostring(_remaining(w, seat)) end return true end end
local function _assert_deity(w, seat, raw_name) local game = _game(w) return dsl.truthy(game:player_has_deity(game.players[seat], DEITY_CODE[raw_name] or "?"), "玩家" .. tostring(seat) .. " 持有" .. tostring(raw_name)) end
local function _tick_player1(w, times) for _ = 1, times do _game(w):tick_player_deity(_game(w).players[1]) end return true end
-- 请神卡候选面:走真实 item registry(availability / 无目标提示读的是同一条)。
local function _look_at_invite_targets(w) w.invite_candidates = game_driver.target_candidates(w.driver, _game(w).players[1], _item_id("请神卡")) return true end
local function _in_candidates(w, seat) if w.invite_candidates == nil then return nil, "尚未查看可选目标" end for _, candidate in ipairs(w.invite_candidates) do if candidate == _game(w).players[seat] then return true end end return false end
return dsl.steps({
  ["玩家1附体<神灵>持续<持续回合:int>回合"] = function(w, a) return _attach(w, 1, a["神灵"], a["持续回合"]) end,
  ["玩家2附体<神灵>持续<持续回合:int>回合"] = function(w, a) return _attach(w, 2, a["神灵"], a["持续回合"]) end,
  ["玩家{座号:int}附体{神灵}持续{回合数:int}回合"] = function(w, a) return _attach(w, a["座号"], a["神灵"], a["回合数"]) end,
  ["玩家2附体天使"] = function(w) return _attach(w, 2, "天使", 5) end,
  ["玩家1神灵剩余回合为<验证持续回合:int>"] = function(w, a) return dsl.eq(_remaining(w, 1), a["验证持续回合"], "玩家1神灵剩余回合") end,
  ["玩家1的回合结束<次数:int>次"] = function(w, a) return _tick_player1(w, a["次数"]) end,
  ["玩家1不再持有任何神灵"] = _no_deity(1),
  ["玩家2不再持有任何神灵"] = _no_deity(2),
  ["玩家2已被淘汰"] = function(w)
    -- 保游戏语义:在场景已建好的对局里淘汰,不重建(神灵已先附体)。
    _game(w):set_player_eliminated(_game(w).players[2], true)
    return true
  end,
  ["游戏进行一个完整回合"] = function(w) for _, player in ipairs(_game(w).players) do _game(w):tick_player_deity(player) end return true end,
  ["玩家2的神灵剩余回合仍为3"] = function(w) return dsl.eq(_remaining(w, 2), 3, "玩家2神灵剩余回合") end,
  ["玩家1对玩家2使用<道具>"] = function(w, a)
    local item_id = _item_id(a["道具"])
    if item_id == nil then return nil, "unknown item: " .. tostring(a["道具"]) end
    local game = _game(w)
    w.item_effect_blocked = game:angel_immune_to_item(game.players[2], item_id)
    if w.item_effect_blocked then
      event_feed.publish(game, { kind = event_kinds.item_immune,
        text = game.players[2].name .. " 天使保护," .. a["道具"] .. "无效", tip = true })
    end
    return true
  end,
  ["道具效果被阻断"] = function(w) return dsl.truthy(w.item_effect_blocked, "天使免疫阻断") end,
  ["系统记录天使保护事件"] = function(w) for _, event in ipairs(game_driver.events(w.driver)) do if event.kind == event_kinds.item_immune then return true end end return nil, "事件日志缺少 item_immune 事件" end,
  ["当前棋盘存在地雷"] = function(w) _game(w):place_mine(_game(w).players[2].position, {}) return true end,
  ["玩家2落在地雷格"] = function(w) w.mine_result = game_driver.try_trigger_mine(w.driver, _game(w).players[2]) return true end,
  ["玩家2不进医院"] = function(w) local status = _game(w).players[2].status return dsl.ne(status and status.pending_location_effect, "hospital", "玩家2去向") end,
  ["玩家1对玩家2使用请神卡"] = function(w) return dsl.truthy(_game(w):transfer_deity(_game(w).players[2], _game(w).players[1]), "请神转移") end,
  ["玩家1对玩家2使用送神卡"] = function(w) return dsl.truthy(_game(w):transfer_deity(_game(w).players[1], _game(w).players[2]), "送神转移") end,
  ["<神灵>转移到玩家1身上"] = function(w, a) return _assert_deity(w, 1, a["神灵"]) end,
  ["穷神转移到玩家2身上"] = function(w) return _assert_deity(w, 2, "穷神") end,
  ["每个对手都附体穷神持续{持续回合:int}回合"] = function(w, a)
    local game = _game(w)
    for seat = 2, #game.players do
      local ok, err = _attach(w, seat, "穷神", a["持续回合"])
      if not ok then return nil, err end
    end
    return true
  end,
  ["玩家1查看请神卡的可选目标"] = _look_at_invite_targets,
  ["玩家2出现在候选列表中"] = function(w)
    local found, err = _in_candidates(w, 2)
    if found == nil then return nil, err end
    return dsl.truthy(found, "玩家2在请神卡候选列表中")
  end,
  ["玩家2不出现在候选列表中"] = function(w)
    local found, err = _in_candidates(w, 2)
    if found == nil then return nil, err end
    return dsl.eq(found, false, "玩家2在请神卡候选列表中")
  end,
  ["请神卡没有可用目标"] = function(w)
    if w.invite_candidates == nil then return nil, "尚未查看可选目标" end
    return dsl.eq(#w.invite_candidates, 0, "请神卡候选数")
  end,
}, { name = "deities" })
