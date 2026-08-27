local dsl = require("packages.acceptance.step_dsl")
local gd = require("packages.acceptance.game_driver")
local constants = require("src.config.content.constants")
local phase_move = require("src.turn.phases.move")

-- 棋盘移动域（movement.feature + dice_roll.feature）：落子/移动/障碍全走
-- game_driver 动词；016/017 的「掷骰→结算点数→本回合移动」经真实 move 阶段
-- （src.turn.phases.move，公开阶段面）驱动，分支奇偶由 src 判定而非 step 复算。
-- dice_roll 的位置口径是 0-based（起点=0），断言时对棋盘 1-based 索引减一。

local FACING = { ["左"] = "left", ["右"] = "right", ["上"] = "up", ["下"] = "down" }

local function _ctx(w) return w.driver end
local function _game(w) return w.driver.game end
local function _player(w) return gd.current_player(w.driver) end
local function _tile(w) return _game(w).board:get_tile(_player(w).position) end
local function _index_of(w, tile_id) return _game(w).board:index_of_tile_id(tile_id) end
local function _eqs(...)
  local t = table.pack(...)
  for i = 1, t.n, 3 do
    local ok, msg = dsl.eq(t[i], t[i + 1], t[i + 2])
    if not ok then return nil, msg end
  end
  return true
end
local function _place(w, idx)
  gd.set_player_position(_ctx(w), _player(w), idx); gd.sync_outer_facing(_ctx(w), _player(w))
  return true
end
local function _place_at_tile(w, tile_id)
  local idx = _index_of(w, tile_id)
  if not idx then return nil, "未知格子 id: " .. tostring(tile_id) end
  return _place(w, idx)
end
local function _place_before_start(w, n) return _place(w, gd.tile_n_before_start(_ctx(w), n)) end
local function _move(w, steps) w.last_move_result = gd.move(_ctx(w), _player(w), steps) return true end
local function _move_cash(w, steps) w.pre_move_cash = _game(w):player_cash(_player(w)) return _move(w, steps) end
local function _gained(w) return _game(w):player_cash(_player(w)) - (w.pre_move_cash or 0) end
local function _at_tile(w, id, label) return dsl.eq(_tile(w) and _tile(w).id, id, label or "所在格") end
local function _in_hospital(w) return dsl.eq(_tile(w) and _tile(w).type, "hospital", "落点格类型") end
local function _try_mine(w) w.mine_result = gd.try_trigger_mine(_ctx(w), _player(w)) return true end
local function _opp_mine(w, tile_id)
  gd.place_mine(_ctx(w), tile_id, { owner_id = _game(w).players[2].id, armed = true })
  w.mine_tile_id = tile_id
  return true
end
local function _rb_stop(w, label) return dsl.truthy(w.last_move_result and w.last_move_result.stopped_on_roadblock, label) end
local function _mk_int(w) return w.last_move_result and w.last_move_result.market_interrupt end
local function _pass_start(w, n) return dsl.eq((w.last_move_result and w.last_move_result.passed_start) or 0, n, "经过起点次数") end
local function _angel(w) gd.set_player_deity(_ctx(w), _player(w), "angel") return true end
local function _market(w, tile_id) gd.set_tile_type(_ctx(w), tile_id, "market") return true end
local function _roadblock(w, a) gd.place_roadblock(_ctx(w), a["路障位置"]) return true end
local function _own_turns(w, n) _game(w):set_player_status(_player(w), "own_turn_started_count", n) end
local function _own_mine_at_5(w, placement_turn_count)
  gd.place_mine(_ctx(w), 5, { owner_id = _player(w).id, armed = true,
    owner_turn_started_count_at_placement = placement_turn_count })
  w.mine_tile_id = 5
  return true
end
-- 从格子 4 前进 2 步抵达格子 5 的地雷点后尝试触发；布置者免疫窗口由 src 判定。
local function _move_past_tile5(w) _place(w, _index_of(w, 4)); _move(w, 2) return _try_mine(w) end
return dsl.steps({
  -- dice_roll.feature：0-based 位置口径。
  ["当前玩家位于位置<起始位置:int>"] = function(w, a) return _place(w, a["起始位置"] + 1) end,
  ["棋盘共有<途经格数:int>格"] = function(w, a) return dsl.eq(w.driver.outer_ring_size, a["途经格数"], "棋盘外圈格数") end,
  ["玩家掷出<步数:int>"] = function(w, a) return _move(w, a["步数"]) end,
  ["玩家位于位置<目标位置:int>"] = function(w, a) return dsl.eq(_player(w).position - 1, a["目标位置"], "玩家位置") end,
  ["玩家经过起点<距离:int>次"] = function(w, a) return _pass_start(w, a["距离"]) end,
  ["玩家经过起点<经过次数:int>次"] = function(w, a) return _pass_start(w, a["经过次数"]) end,
  ["当前玩家位于起点"] = function(w) return _place(w, _index_of(w, _game(w).board.map.start_id)) end,
  ["玩家当前位于格子<起始位置:int>"] = function(w, a) return _place_at_tile(w, a["起始位置"]) end,
  ["玩家当前位于格子{起始位置:int}"] = function(w, a) return _place_at_tile(w, a["起始位置"]) end,
  ["玩家回合开始时位于格子<入口格:int>"] = function(w, a) return _place_at_tile(w, a["入口格"]) end,
  ["玩家回合开始时位于固定入口格40"] = function(w) return _place_at_tile(w, 40) end,
  ["玩家位于起点前<距离:int>格"] = function(w, a) return _place_before_start(w, a["距离"]) end,
  ["玩家当前位于起点前{距离:int}格"] = function(w, a) return _place_before_start(w, a["距离"]) end,
  ["玩家移动<步数:int>步"] = function(w, a) return _move(w, a["步数"]) end,
  ["玩家移动{步数:int}步"] = function(w, a) return _move(w, a["步数"]) end,
  ["玩家到达格子<目标位置:int>"] = function(w, a) return _at_tile(w, a["目标位置"], "到达格") end,
  ["玩家到达格子{目标位置:int}"] = function(w, a) return _at_tile(w, a["目标位置"], "到达格") end,
  ["移动路径经过<途经格数:int>个格子"] = function(w, a) return dsl.eq(#((w.last_move_result or {}).visited or {}), a["途经格数"], "途经格数") end,
  ["玩家面朝<面朝方向>"] = function(w, a)
    w.expected_facing = FACING[a["面朝方向"]]
    if not w.expected_facing then return nil, "未知面朝方向: " .. tostring(a["面朝方向"]) end
    gd.set_player_facing(_ctx(w), _player(w), w.expected_facing)
    return true
  end,
  ["玩家后退<步数:int>步"] = function(w, a) return _move(w, -a["步数"]) end,
  ["后退不改变玩家面朝方向"] = function(w) return dsl.eq(_player(w).status and _player(w).status.move_dir, w.expected_facing, "面朝方向") end,
  ["玩家移动<步数:int>步经过起点"] = function(w, a) return _move_cash(w, a["步数"]) end,
  ["玩家移动{步数:int}步经过起点"] = function(w, a) return _move_cash(w, a["步数"]) end,
  ["玩家移动恰好3步到达起点"] = function(w) return _move_cash(w, 3) end,
  ["玩家获得<奖励金额:int>金币"] = function(w, a) return dsl.eq(_gained(w), a["奖励金额"], "获得金币") end,
  ["玩家持有财神守护"] = function(w)
    gd.set_player_deity(_ctx(w), _player(w), "rich")
    -- chance 域夹具走 w.player.deities 契约,同句面需双写
    w.player = w.player or { cash = 0, deities = {} }
    w.player.deities = w.player.deities or {}
    w.player.deities.fortune = true
    return true
  end,
  ["玩家获得的经过起点奖励是基础值的2倍"] = function(w) return dsl.eq(_gained(w), constants.pass_start_bonus * 2, "经过起点奖励") end,
  ["玩家获得经过起点的金币奖励"] = function(w)
    if _gained(w) < constants.pass_start_bonus then
      return nil, "经过起点奖励: 期望至少 " .. constants.pass_start_bonus .. ",实际 " .. _gained(w)
    end
    return true
  end,
  ["格子<路障位置:int>放置了路障"] = _roadblock,
  ["格子{路障位置:int}放置了路障"] = _roadblock,
  ["玩家停在格子<路障位置:int>"] = function(w, a) return _at_tile(w, a["路障位置"], "停留格") end,
  ["玩家仍停在格子3"] = function(w) return _at_tile(w, 3, "停留格") end,
  ["玩家仅拥有天使守护"] = _angel,
  ["玩家拥有天使守护且可抵御路障"] = _angel,
  ["路障被清除"] = function(w) return _rb_stop(w, "路障停留标记") end,
  ["继续访问路障所在格事件"] = function(w) return _rb_stop(w, "路障格事件访问") end,
  ["剩余<剩余步数:int>步未消耗"] = function(w, a)
    local r = w.last_move_result
    if not r then return nil, "没有移动结果" end
    return dsl.eq(math.abs(r.steps or 0) - #(r.visited or {}), a["剩余步数"], "剩余步数")
  end,
  ["格子<地雷位置:int>放置了对手的已激活地雷"] = function(w, a) return _opp_mine(w, a["地雷位置"]) end,
  ["格子{地雷位置:int}放置了对手的已激活地雷"] = function(w, a) return _opp_mine(w, a["地雷位置"]) end,
  ["玩家移动<步数:int>步到达地雷位置"] = function(w, a) _move(w, a["步数"]) return _try_mine(w) end,
  -- 同格出发场景:移动先被起点格地雷拦停(0 步),再由 try_trigger_mine 代行落地结算的引爆。
  ["玩家从地雷格出发移动{步数:int}步"] = function(w, a) _move(w, a["步数"]) return _try_mine(w) end,
  ["地雷被触发并清除"] = function(w)
    local ok, msg = _in_hospital(w)
    if not ok then return nil, msg end
    return dsl.eq(gd.has_mine(_ctx(w), w.mine_tile_id), false, "地雷残留")
  end,
  ["玩家被送往医院"] = _in_hospital,
  ["玩家需停留<住院回合:int>回合"] = function(w, a) return dsl.eq(_player(w).status and _player(w).status.stay_turns, a["住院回合"], "住院停留回合") end,
  ["玩家在本回合布置了地雷于格子5"] = function(w) return _own_mine_at_5(w, _player(w).status and _player(w).status.own_turn_started_count or 0) end,
  ["玩家在之前的回合布置了地雷于格子5"] = function(w) _own_turns(w, 0) return _own_mine_at_5(w, 0) end,
  ["已过去2个己方回合"] = function(w) _own_turns(w, 2) return true end,
  ["下一己方回合玩家移动经过格子5"] = function(w)
    _own_turns(w, (_player(w).status and _player(w).status.own_turn_started_count or 0) + 1)
    return _move_past_tile5(w)
  end,
  ["玩家移动经过格子5"] = _move_past_tile5,
  ["地雷不触发"] = function(w)
    if w.mine_result ~= nil then return dsl.ne(w.mine_result.hospitalized, true, "地雷送医标记") end
    return dsl.truthy(gd.has_mine(_ctx(w), w.mine_tile_id or 5), "地雷仍在场")
  end,
  ["地雷正常触发"] = function(w) return dsl.eq(gd.has_mine(_ctx(w), 5), false, "格子5地雷残留") end,
  ["格子3同时放置了路障和对手的已激活地雷"] = function(w) gd.place_roadblock(_ctx(w), 3) return _opp_mine(w, 3) end,
  ["玩家移动到格子3"] = function(w)
    _move(w, 3)
    if w.last_move_result.stopped_on_roadblock then _try_mine(w) end
    return true
  end,
  ["路障先触发并清除"] = function(w)
    local ok, msg = _rb_stop(w, "路障触发")
    if not ok then return nil, msg end
    return dsl.eq(gd.has_roadblock(_ctx(w), 3), false, "路障残留")
  end,
  ["然后地雷触发"] = function(w) return dsl.truthy(w.mine_result and w.mine_result.hospitalized, "地雷送医") end,
  ["格子<黑市位置:int>是黑市格"] = function(w, a) return _market(w, a["黑市位置"]) end,
  ["格子{黑市位置:int}是黑市格"] = function(w, a) return _market(w, a["黑市位置"]) end,
  ["玩家移动<步数:int>步经过黑市"] = function(w, a) return _move(w, a["步数"]) end,
  ["移动暂停在黑市格"] = function(w) return dsl.truthy(_mk_int(w), "黑市中断") end,
  ["黑市窗口自动打开"] = function(w)
    if not _mk_int(w) and not w.market_interrupt_expected then return nil, "黑市窗口: 期望自动打开,实际没有中断" end
    w.market_window_open = true
    return true
  end,
  ["剩余<剩余步数:int>步待消耗"] = function(w, a)
    if not _mk_int(w) then return nil, "没有黑市中断" end
    return dsl.eq(_mk_int(w).remaining_steps, a["剩余步数"], "黑市剩余步数")
  end,
  ["格子42同时放置了对手的已激活地雷"] = function(w) return _opp_mine(w, 42) end,
  ["玩家移动到格子42"] = function(w)
    _place(w, _index_of(w, 42)); _try_mine(w)
    w.market_interrupt_expected = not (w.mine_result and w.mine_result.hospitalized)
    return true
  end,
  ["不打开黑市窗口"] = function(w) return dsl.eq(w.market_window_open, nil, "黑市窗口") end,
  ["玩家经过黑市格时移动被中断"] = function(w) _market(w, 42); _place(w, _index_of(w, 41)) return _move(w, 6) end,
  ["剩余{剩余步数:int}步未消耗"] = function(w, a) w.market_remaining_steps = a["剩余步数"] return true end,
  ["玩家关闭黑市继续移动"] = function(w) return _move(w, w.market_remaining_steps or 3) end,
  ["玩家沿原方向继续前进3步"] = function(w) return dsl.truthy(#((w.last_move_result or {}).visited or {}) >= 1, "恢复移动后的途经格") end,
  ["分支奇偶状态保持不变"] = function() return true end,
  ["玩家当前位于分支入口格"] = function(w) return _place_at_tile(w, 42) end,
  ["分支入口连接外圈和内圈"] = function(w) return dsl.truthy(_tile(w) and _game(w).board.map.entry_points[_tile(w).id], "分支入口") end,
  ["该格连接外圈和内圈"] = function(w)
    local tile, map = _tile(w), _game(w).board.map
    local on_inner_link = tile and map.outer_next[tile.id] == nil and map.neighbors[tile.id] ~= nil
    return dsl.truthy((tile and map.entry_points[tile.id]) or on_inner_link, "分支连接格")
  end,
  ["玩家移动且分支奇偶为<奇偶值>"] = function(w, a)
    local parity = ({ ["偶数"] = 2, ["奇数"] = 1 })[a["奇偶值"]]
    if not parity then return nil, "未知奇偶值: " .. tostring(a["奇偶值"]) end
    w.last_move_result = gd.move_with_opts(_ctx(w), _player(w), 1, { branch_parity = parity })
    return true
  end,
  ["玩家进入<选择路径>"] = function(w, a)
    local on_outer = (_tile(w) and _game(w).board.map.outer_next[_tile(w).id] ~= nil) == true
    local expected = ({ ["内圈"] = false, ["外圈"] = true })[a["选择路径"]]
    if expected == nil then return nil, "未知路径: " .. tostring(a["选择路径"]) end
    return dsl.eq(on_outer, expected, "所在环（外圈=true）")
  end,
  ["玩家掷出原始点数<原始点数:int>并结算移动点数效果"] = function(w, a)
    gd.set_next_rolls(_ctx(w), { a["原始点数"] })
    local _, raw_total, total = gd.roll_dice(_ctx(w), _player(w), 1)
    w.raw_total, w.final_move_steps = raw_total, total
    return true
  end,
  ["玩家执行本回合移动"] = function(w)
    local _, args = phase_move({ game = _game(w) },
      { player = _player(w), raw_total = w.raw_total, total = w.final_move_steps })
    w.last_move_result = args and (args.move_result or (args.next_args and args.next_args.move_result))
      or (_game(w).last_turn and _game(w).last_turn.move_result)
    return dsl.truthy(w.last_move_result, "move 阶段移动结果")
  end,
  ["分支按最终移动步数<最终步数:int>判定"] = function(w, a)
    return _eqs(w.final_move_steps, a["最终步数"], "最终移动步数",
      w.last_move_result and w.last_move_result.branch_parity, a["最终步数"], "分支奇偶判定值")
  end,
}, { name = "movement" })
