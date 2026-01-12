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
    description = entry.desc or entry.description or entry.usage or "",
  }

  local shop = entry.shop or { DEFAULTS.shop_currency, DEFAULTS.shop_price }
  out.shop_currency = shop[1]
  out.shop_price = shop[2]

  return out
end

local items_compact = {
  { 2001, "免费卡", tier = 1, shop = { "广告", 1 }, weight = 1000, timing = "rent_prompt", usage = "确认使用，免除本次租金", desc = "停留在其他玩家地块时，可使用免费卡免交本次租金。" },
  { 2002, "遥控骰子卡", tier = 1, weight = 1000, timing = "pre_action", usage = "主动使用，设定骰子点数", desc = "投骰子前可设置骰子点数，点击循环 1~6 后确定。" },
  { 2003, "骰子加倍卡", tier = 1, weight = 1000, timing = "pre_move", usage = "投出后触发，令本次点数加倍", desc = "投出骰子后可使用，将本次投掷步数翻倍。" },
  { 2004, "路障卡", tier = 1, weight = 1000, angel_immune = true, usage = "主动使用，前后 3 格放置路障", desc = "释放后可在前后 3 格放置路障，经过者停留并清除路障。" },
  { 2005, "地雷卡", tier = 1, weight = 1000, angel_immune = true, usage = "主动使用，在脚下放置地雷", desc = "在当前位置放置地雷，经过者触发炸毁座驾并送医。" },
  { 2006, "清障卡", tier = 1, weight = 1000, timing = "pre_action", usage = "主动使用，清除前方 12 格障碍", desc = "行动前释放机器人清除前方 12 格（含分叉）路障/地雷。" },
  { 2007, "偷窃卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, timing = "pass_player", usage = "经过玩家时触发，选择一个道具偷取", desc = "路过其他玩家弹窗选择是否使用，指定道具转移到自己背包。" },
  { 2008, "怪兽卡", tier = 2, shop = { "乐园币", 10 }, usage = "主动使用，拆除前后 3 格建筑", desc = "选择前后 3 格内的建筑释放怪兽拆除该建筑。" },
  { 2009, "强征卡", tier = 2, shop = { "乐园币", 10 }, timing = "rent_prompt", usage = "停留他人地块时触发，支付总价强制买下", desc = "停留在他人地块时支付地块+建筑总价并转移所有权。" },
  { 2010, "免税卡", tier = 2, shop = { "乐园币", 10 }, timing = "tax_prompt", usage = "征税时触发，抵扣本次税金", desc = "到税务局或被查税时可出示免税卡免除本次税费。" },
  { 2011, "均富卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, usage = "主动使用，选择一名玩家平分双方资金", desc = "选择一名玩家，将双方现金总和平分。" },
  { 2012, "流放卡", tier = 2, shop = { "乐园币", 10 }, angel_immune = true, usage = "主动使用，选择一名玩家送往深山", desc = "强制目标玩家移动到深山并开始停留回合。" },
  { 2013, "导弹卡", tier = 3, shop = { "金豆", 5 }, weight = 250, usage = "主动使用，前后 3 格范围导弹轰炸", desc = "前后 3 格选一格，摧毁建筑与座驾，所有玩家送医。" },
  { 2014, "查税卡", tier = 3, shop = { "金豆", 5 }, weight = 250, angel_immune = true, usage = "主动使用，目标支付 50% 现金的所得税", desc = "选择一名玩家立刻支付 50% 现金，可被免税卡抵消，天使免疫。" },
  { 2015, "请神卡", tier = 3, shop = { "金豆", 5 }, weight = 250, usage = "主动使用，夺取目标的附身神", desc = "选择一名玩家，将其附身神转移到自己身上（仅保留一位神）。" },
  { 2016, "送神卡", tier = 3, shop = { "金豆", 5 }, weight = 250, timing = "trigger_poor_god", usage = "被穷神附身时触发，将穷神送给他人", desc = "自己有穷神时可选择一名玩家转移穷神（目标仅保留一位神）。" },
  { 2017, "财神卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，财神附身 5 回合收款翻倍", desc = "财神附身，持续 5 回合，租金/奖金翻倍。" },
  { 2018, "穷神卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，给目标附身穷神 5 回合付款翻倍", desc = "选择玩家让其穷神附身 5 回合，租金/罚金翻倍。" },
  { 2019, "天使卡", tier = 3, shop = { "金豆", 5 }, weight = 0, usage = "主动使用，天使附身 5 回合免疫负面", desc = "天使附身 5 回合，免疫负面卡牌/地雷/路障/送医/深山。" },
}

local items = {}
for _, entry in ipairs(items_compact) do
  table.insert(items, normalize(entry))
end

return items
