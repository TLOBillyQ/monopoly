local DEFAULTS = {
  tier = 1,
  shop_currency = "金币",
  shop_price = 1000,
  weight = 500,
  angel_immune = false,
  timing = "manual",
}

local function normalize(entry)
  local out = {
    id = entry[1],
    name = entry[2],
    tier = entry.tier or DEFAULTS.tier,
    weight = entry.weight or DEFAULTS.weight,
    angel_immune = entry.angel_immune or DEFAULTS.angel_immune,
    timing = entry.timing or DEFAULTS.timing,
    usage = entry.usage or "",
  }

  local shop = entry.shop or { DEFAULTS.shop_currency, DEFAULTS.shop_price }
  out.shop_currency = shop[1]
  out.shop_price = shop[2]

  return out
end

local items_compact = {
  { 2001, "免费卡", tier = 1, shop = { "广告", 1 }, weight = 1000, timing = "rent_prompt", usage = "确认使用，免除本次租金" },
  { 2002, "遥控骰子卡", tier = 1, weight = 1000, timing = "pre_action", usage = "主动使用，设定骰子点数" },
  { 2003, "骰子加倍卡", tier = 1, weight = 1000, timing = "pre_move", usage = "投出后触发，令本次点数加倍" },
  { 2004, "路障卡", tier = 1, weight = 1000, angel_immune = true, usage = "主动使用，前后 3 格放置路障" },
  { 2005, "地雷卡", tier = 1, weight = 1000, angel_immune = true, usage = "主动使用，在脚下放置地雷" },
  { 2006, "清障卡", tier = 1, weight = 1000, timing = "pre_action", usage = "主动使用，清除前方 12 格障碍" },
  { 2007, "偷窃卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, timing = "pass_player", usage = "经过玩家时触发，选择一个道具偷取" },
  { 2008, "怪兽卡", tier = 2, shop = { "乐园币", 10 }, usage = "主动使用，拆除前后 3 格建筑" },
  { 2009, "强征卡", tier = 2, shop = { "乐园币", 10 }, timing = "rent_prompt", usage = "停留他人地块时触发，支付总价强制买下" },
  { 2010, "免税卡", tier = 2, shop = { "乐园币", 10 }, timing = "tax_prompt", usage = "征税时触发，抵扣本次税金" },
  { 2011, "均富卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, usage = "主动使用，选择一名玩家平分双方资金" },
  { 2012, "流放卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, usage = "主动使用，选择一名玩家送往深山" },
  { 2013, "导弹卡", tier = 3, shop = { "金豆", 5 }, weight = 250, usage = "主动使用，前后 3 格范围导弹轰炸" },
  { 2014, "查税卡", tier = 3, shop = { "金豆", 5 }, weight = 250, angel_immune = true, usage = "主动使用，目标支付 50% 现金的所得税" },
  { 2015, "请神卡", tier = 3, shop = { "金豆", 5 }, weight = 250, usage = "主动使用，夺取目标的附身神" },
  { 2016, "送神卡", tier = 3, shop = { "金豆", 5 }, weight = 250, timing = "trigger_poor_god", usage = "被穷神附身时触发，将穷神送给他人" },
  { 2017, "财神卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，财神附身 5 回合收款翻倍" },
  { 2018, "穷神卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，给目标附身穷神 5 回合付款翻倍" },
  { 2019, "天使卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，天使附身 5 回合免疫负面" },
}

local items = {}
for _, entry in ipairs(items_compact) do
  table.insert(items, normalize(entry))
end

return items
