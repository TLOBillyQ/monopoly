-- 金币扣费与破产结算深模块:唯一解释者。
-- 「扣一笔钱/转一笔钱 → 判非正余额 → 破产淘汰(或延后上报) → 收款遥测」
-- 全部收敛于此。deity ×2 定价规则按域各异,留在 adapter;
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

local function _build_transfer_opts(cash_opts)
  local transfer_opts = { allow_partial = true }
  if cash_opts then
    for key, value in pairs(cash_opts) do
      transfer_opts[key] = value
    end
  end
  return transfer_opts
end

-- 转账(payer → receiver)。始终 partial:payer 余额不足时封顶到其流动性,
-- 绝不创造钱。实际到账 > 0 时记一次 receiver 的 cash_received 遥测。
function coin_settlement.transfer(game, payer, receiver, amount, opts)
  opts = opts or {}
  local transfer_opts = _build_transfer_opts(opts.cash_opts)
  local _, _, moved = game:transfer_player_cash(payer, receiver, amount, transfer_opts)
  if moved and moved > 0 then
    achievement_progress.cash_received(game, receiver, moved)
  end
  local bankrupt, reason = _settle_bankruptcy(game, payer, opts)
  return { moved = moved, bankrupt = bankrupt, reason = reason }
end

return coin_settlement

--[[ mutate4lua-manifest
version=4
projectHash=bdda8dcfce5a262d
scope.0.id=chunk:src/rules/commerce/coin_settlement.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=66
scope.0.semanticHash=278ef20f44af2cc8
scope.1.id=function:_resolve_reason
scope.1.kind=function
scope.1.startLine=10
scope.1.endLine=15
scope.1.semanticHash=6a5ecf4533bccebf
scope.2.id=function:_settle_bankruptcy
scope.2.kind=function
scope.2.startLine=20
scope.2.endLine=29
scope.2.semanticHash=4bffd4ced731cfec
scope.3.id=function:coin_settlement.charge
scope.3.kind=function
scope.3.startLine=33
scope.3.endLine=40
scope.3.semanticHash=e5c814f5f4daf6ea
scope.4.id=function:_build_transfer_opts
scope.4.kind=function
scope.4.startLine=42
scope.4.endLine=50
scope.4.semanticHash=7d2d763e77ec6f9b
scope.5.id=function:coin_settlement.transfer
scope.5.kind=function
scope.5.startLine=54
scope.5.endLine=63
scope.5.semanticHash=64c262f1b97eca0e
]]
