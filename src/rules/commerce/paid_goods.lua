local paid_goods = {
  enabled = true,
  -- 金豆/乐园币由外部系统维护，不走 Eggy commodity 查询或本地扣减。
  -- Lua 侧只把它们标记为“付费货币”，用于识别黑市中哪些商品需要走官方商品面板。
  currencies = {
    ["金豆"] = {
      source = "external",
    },
    ["乐园币"] = {
      source = "external",
    },
  },
}

return paid_goods

--[[ mutate4lua-manifest
version=4
projectHash=5050775cd1ea1b8a
scope.0.id=chunk:src/rules/commerce/paid_goods.lua
scope.0.kind=chunk
scope.0.startLine=1
scope.0.endLine=16
scope.0.semanticHash=c66c5b340d3e1656
]]
