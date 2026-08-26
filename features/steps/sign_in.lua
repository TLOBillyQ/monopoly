local dsl = require("packages.acceptance.step_dsl")
local sign_in = require("src.app.host_integrations.sign_in")
-- 签到域绑定（#192 簇 B）：真实 sign_in.grant/claim 跑在最小 game/player 上。
-- 「玩家当前金币为<X>」同形合并：领奖前为设值,领奖后为断言。
local function _si(w)
  w.si = w.si or {
    player = { id = 1, cash = 0 },
    game = { add_player_cash = function(_, target, amount) target.cash = (target.cash or 0) + amount end },
  }
  return w.si
end
return dsl.steps({
  ["玩家当前金币为<之前金币:int>"] = function(w, a)
    if w.si_granted then return dsl.eq(_si(w).player.cash, a["之前金币"], "签到后金币") end
    _si(w).player.cash = a["之前金币"]
  end,
  ["玩家领取第<签到天数:int>天签到奖励"] = function(w, a)
    local si = _si(w)
    sign_in.grant(si.game, si.player, a["签到天数"])
    w.si_granted = true
  end,
  ["玩家当前金币为 500"] = function(w) _si(w).player.cash = 500 end,
  ["触发一个未配置奖励的签到事件"] = function(w)
    local si = _si(w)
    sign_in.claim(si.game, "RewardDay99", si.player) -- RewardDay99 合法事件名,该天未配置奖励
  end,
  ["玩家当前金币保持 500 不变"] = function(w) return dsl.eq(_si(w).player.cash, 500, "未配置奖励后金币") end,
}, { name = "sign_in" })
