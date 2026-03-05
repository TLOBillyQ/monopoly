local paid_goods = {
  enabled = true,
  -- 货币配置仅用于展示同步（get_commodity_count -> 玩家余额显示）。
  -- 黑市真实购买链路走 show_goods_purchase_panel + SPEC_ROLE_PURCHASE_GOODS。
  currencies = {
    ["金豆"] = {
      -- TODO: 填写线上金豆 commodity_id
      commodity_id = 0,
      unit_value = 1,
    },
    ["乐园币"] = {
      -- TODO: 填写线上乐园币 commodity_id
      commodity_id = 0,
      unit_value = 1,
    },
  },
}

return paid_goods
