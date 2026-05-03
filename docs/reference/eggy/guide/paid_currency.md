---
kind: reference
status: stable
owner: eggy-vendor
last_verified: 2026-05-04
---
# 付费货币通道约束

- `金豆/乐园币` 是外部维护的付费货币，不是 Eggy `commodity`，Lua 侧不查询余额，也不本地扣减。
- 黑市中的付费商品统一走官方商品链路：`show_goods_purchase_panel(goods_id)` + `SPEC_ROLE_PURCHASE_GOODS` 回调发货。
- 商品映射来源为 `src/config/content/market.lua` 的 `name` 对齐 `get_goods_list().name`。
- 充值、补单、真实余额与扣费由外部系统处理；Lua 侧只负责发起购买和在购买成功回调后发货。
