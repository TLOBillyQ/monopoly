local items_cfg = require("src.config.content.items")

local item_cfg_by_id = {}
for _, cfg in ipairs(items_cfg) do
  item_cfg_by_id[cfg.id] = cfg
end

local function _item_entry(order, product_id)
  local cfg = assert(item_cfg_by_id[product_id], "missing item config for market product_id=" .. tostring(product_id))
  return {
    order = order,
    product_id = product_id,
    name = cfg.name,
    page = "道具商店",
    kind = "item",
    currency = cfg.shop_currency,
    price = cfg.shop_price,
    limit = 5,
  }
end

local market = {
  _item_entry(1, 2003),
  _item_entry(2, 2005),
  _item_entry(3, 2006),
  _item_entry(4, 2002),
  _item_entry(5, 2004),
  _item_entry(6, 2012),
  _item_entry(7, 2001),
  _item_entry(8, 2007),
  _item_entry(9, 2008),
  _item_entry(10, 2009),
  _item_entry(11, 2010),
  _item_entry(12, 2013),
  _item_entry(13, 2017),
  _item_entry(14, 2018),
  _item_entry(15, 2019),
  _item_entry(16, 2015),
  _item_entry(17, 2016),
  _item_entry(18, 2011),
  _item_entry(19, 2014),
  { order = 20, product_id = 5001, name = "小猪佩奇", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
  { order = 21, product_id = 5002, name = "小猪乔治", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
  { order = 22, product_id = 5003, name = "海绵宝宝", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
  { order = 23, product_id = 5004, name = "派大星", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
  { order = 24, product_id = 5005, name = "奶龙", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
  { order = 25, product_id = 5006, name = "水豚嘟嘟", page = "皮肤商店", kind = "skin", currency = "金豆", price = 198, limit = 1 },
}

return market
