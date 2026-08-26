-- 商店购买结果的全量构造器与唯一形状判定器。
-- purchase.execute 历史返回 4 种不兼容形状:
--   false(非法商品) / { ok=false, reason }(校验/余额/在途/通道失败) /
--   { ok=true, fulfilled_now=true, inventory_full_after }(本地即时成交) /
--   { ok=true, deferred_fulfillment=true }(付费下单、异步履约)。
-- canonicalize 是全模块唯一解码点,收敛为 4 个终态 status:
--   fulfilled / deferred / rejected / residual。
-- residual = 「非可识别终态」(非表、ok=nil 的表),由解释者
-- (purchase_settlement)统一收尾。与 items 的 use_result 同构,但 residual 的
-- 收尾语义按 market 既有契约(非表 → 收尾而非失败留屏)保留,不照抄 items。
--
-- 为什么不把那 4 种形状在**产地**(purchase.execute)就统一掉(工单 #126):
-- 那 4 种形状已被硬钉在测试面上 —— 全仓 45 个 purchase.execute 调用点 +
-- 55 处形状断言(purchase_result_spec 27 / market_choice_spec 28)。改产地的返回值
-- 要同时动这 45 处,收益不抵风险。**收敛只能做在解释者侧** —— 这正是本模块存在的理由:
-- 它是那 4 种形状与下游之间的解码层,让下游只认 status,不认形状。
local purchase_result = {}

local RESULT_MT = {}

local function _new(status, fields)
  return setmetatable({
    status = status,
    reason = fields.reason,
    kind = fields.kind,
    product_id = fields.product_id,
    fulfilled_now = fields.fulfilled_now,
    inventory_full_after = fields.inventory_full_after,
    raw = fields.raw,
  }, RESULT_MT)
end

function purchase_result.is_result(value)
  return getmetatable(value) == RESULT_MT
end

function purchase_result.fulfilled(fields)
  fields = fields or {}
  return _new("fulfilled", {
    kind = fields.kind,
    product_id = fields.product_id,
    fulfilled_now = true,
    inventory_full_after = fields.inventory_full_after == true,
    raw = fields.raw,
  })
end

function purchase_result.deferred(fields)
  fields = fields or {}
  return _new("deferred", { kind = fields.kind, product_id = fields.product_id, raw = fields.raw })
end

function purchase_result.rejected(reason, fields)
  assert(type(reason) == "string" and reason ~= "", "rejected requires a stable reason")
  fields = fields or {}
  return _new("rejected", { reason = reason, raw = fields.raw })
end

function purchase_result.residual(raw)
  return _new("residual", { raw = raw })
end

local function _decode_rejected(raw, fallback_reason)
  return purchase_result.rejected(raw.reason or fallback_reason or "purchase_rejected", { raw = raw })
end

-- ok == true 的两个成交终态;两者都不是则仍属 residual(非可识别终态)。
local function _decode_ok(raw)
  if raw.deferred_fulfillment == true then
    return purchase_result.deferred({ kind = raw.kind, product_id = raw.product_id, raw = raw })
  end
  if raw.fulfilled_now == true then
    return purchase_result.fulfilled({
      kind = raw.kind,
      product_id = raw.product_id,
      inventory_full_after = raw.inventory_full_after == true,
      raw = raw,
    })
  end
  return purchase_result.residual(raw)
end

-- 4 种历史 raw 形状的唯一解码点。解释者只认 canonicalize 的产出。
function purchase_result.canonicalize(raw, fallback_reason)
  if purchase_result.is_result(raw) then
    return raw
  end
  if type(raw) ~= "table" then
    return purchase_result.residual(raw)
  end
  if raw.ok == false then
    return _decode_rejected(raw, fallback_reason)
  end
  if raw.ok == true then
    return _decode_ok(raw)
  end
  return purchase_result.residual(raw)
end

return purchase_result

--[[ mutate4lua-manifest
version=4
projectHash=2d350c9cba9e9dd5
scope.0.id=chunk:src/rules/market/purchase_result.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=101
scope.0.semanticHash=9123400167618416
scope.1.id=function:_new
scope.1.kind=function
scope.1.startLine=21
scope.1.endLine=31
scope.1.semanticHash=9f18ab6d516b1973
scope.2.id=function:purchase_result.is_result
scope.2.kind=function
scope.2.startLine=33
scope.2.endLine=35
scope.2.semanticHash=cbc50c0c0c0152e1
scope.3.id=function:purchase_result.fulfilled
scope.3.kind=function
scope.3.startLine=37
scope.3.endLine=46
scope.3.semanticHash=43b6d3cf541b7abd
scope.4.id=function:purchase_result.deferred
scope.4.kind=function
scope.4.startLine=48
scope.4.endLine=51
scope.4.semanticHash=547be6bb19c3a71e
scope.5.id=function:purchase_result.rejected
scope.5.kind=function
scope.5.startLine=53
scope.5.endLine=57
scope.5.semanticHash=7df67622d7f1c976
scope.6.id=function:purchase_result.residual
scope.6.kind=function
scope.6.startLine=59
scope.6.endLine=61
scope.6.semanticHash=65b504efd6b6eeff
scope.7.id=function:_decode_rejected
scope.7.kind=function
scope.7.startLine=63
scope.7.endLine=65
scope.7.semanticHash=df045dc8c8cb1a9f
scope.8.id=function:_decode_ok
scope.8.kind=function
scope.8.startLine=68
scope.8.endLine=81
scope.8.semanticHash=1221a71630b4bc0e
scope.9.id=function:purchase_result.canonicalize
scope.9.kind=function
scope.9.startLine=84
scope.9.endLine=98
scope.9.semanticHash=63c695a074bc0e47
]]
