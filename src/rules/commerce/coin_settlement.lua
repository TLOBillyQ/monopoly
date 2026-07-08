-- 金币扣费与破产结算深模块:唯一解释者。
-- 「扣一笔钱/转一笔钱 → 判非正余额 → 破产淘汰(或延后上报) → 收款遥测」
-- 全部收敛于此。原先散落在 land/chance/items/tax 四处、用 3 套破产协议
-- (bankrupt_reason 字段 / helper 顺手 eliminate / inline eliminate)重写的
-- 同一段逻辑,降为四个 adapter。deity ×2 定价规则按域各异,留在 adapter;
-- 本模块只拥有结算机制:余额钳制、partial 封顶、非正判定、淘汰时机、收款遥测。
local achievement_progress = require("src.rules.ports.achievement_progress") -- luacheck: ignore (Task 2 transfer 使用)
local bankruptcy_port = require("src.rules.ports.bankruptcy")

local coin_settlement = {}

local function _resolve_reason(reason, payer)
  if type(reason) == "function" then
    return reason(payer)
  end
  return reason
end

-- 破产判定 + 淘汰时机。非正余额(<= 0) → 破产。
-- defer_bankruptcy 时只上报不淘汰(land 管线在 land_events 阶段统一淘汰,
-- 保留既有「先发事件、后淘汰」顺序)。
local function _settle_bankruptcy(game, payer, opts)
  if game:player_cash(payer) > 0 then
    return false, nil
  end
  local reason = _resolve_reason(opts.reason, payer)
  if not opts.defer_bankruptcy then
    bankruptcy_port.eliminate(game, payer, { reason = reason })
  end
  return true, reason
end

-- 扣费(单向流出)。按 add_player_cash 语义在 0 处钳制,绝不为负。
-- 无收款遥测(流出不记 cash_received)。
function coin_settlement.charge(game, payer, amount, opts)
  opts = opts or {}
  local before = game:player_cash(payer)
  game:add_player_cash(payer, -amount, opts.cash_opts)
  local charged = before - game:player_cash(payer)
  local bankrupt, reason = _settle_bankruptcy(game, payer, opts)
  return { charged = charged, bankrupt = bankrupt, reason = reason }
end

return coin_settlement
