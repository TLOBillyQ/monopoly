local dsl = require("packages.acceptance.step_dsl")
local game_driver = require("packages.acceptance.game_driver")
-- 黑市现金显示域绑定（#192 簇 B）：显示值即 game:player_cash 的真实读数。
-- 「玩家角色ID为<角色ID>」为 v102 跨簇共享句面,归属本模块（见 #192 协调）。
local function _player(w)
  if w.market_player then return w.market_player end
  if w.driver then return game_driver.current_player(w.driver) end
  return nil
end
local function _refresh(w)
  local p = _player(w)
  if w.driver and p then w.displayed_cash = w.driver.game:player_cash(p)
  else w.displayed_cash = w.market_cash_amount or 0 end
end
return dsl.steps({
  ["玩家当前现金为<设置金额:int>"] = function(w, a)
    local p = _player(w)
    if w.driver and p then w.driver.game:set_player_cash(p, a["设置金额"]) end
    w.market_cash_amount = a["设置金额"]
  end,
  ["黑市向玩家开放"] = _refresh, ["黑市现金显示区刷新"] = _refresh,
  ["黑市现金显示区显示金额<显示金额:int>"] = function(w, a) return dsl.eq(w.displayed_cash, a["显示金额"], "黑市现金显示") end,
}, { name = "market_cash" })
