# 付费货币通道约束

- `金豆/乐园币` 是货币（commodity），不是商品。
- Lua 侧仅把 `commodity_id` 用于余额展示同步（`get_commodity_count`）。
- 黑市购买走官方商品链路：`show_goods_purchase_panel(goods_id)` + `SPEC_ROLE_PURCHASE_GOODS` 回调发货。
- 商品映射来源为 `Config/Generated/Market.lua` 的 `name` 对齐 `get_goods_list().name`。
- 充值/补单由外部系统处理，Lua 侧负责发起购买与回调发货。
