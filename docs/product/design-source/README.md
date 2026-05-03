---
kind: spec
status: stable
owner: product
last_verified: 2026-05-04
---

# 策划原稿索引

这里放策划原稿（xlsx/docx）。**Agent 读不了这些二进制文件**；agent 要数据请从 `src/config/` 的 Lua 表读。

## 原稿清单

| 文件 | 内容主题 | 已导出 Lua | 对应 Lua 文件 |
|------|---------|-----------|-------------|
| 蛋仔--大富翁--地块表.xlsx | 地块属性与价格 | ✓ | `src/config/content/tiles.lua` |
| 蛋仔--大富翁--常量表.xlsx | 游戏常量配置 | ✓ | `src/config/gameplay/runtime_constants.lua` |
| 蛋仔--大富翁--座驾表.xlsx | 座驾属性列表 | ✓ | `src/config/content/vehicles.lua`、`src/config/gameplay/vehicle_catalog.lua` |
| 蛋仔--大富翁--机会表.xlsx | 机会卡内容 | ✓ | `src/config/content/chance_cards.lua` |
| 蛋仔--大富翁--皮肤表.xlsx | 皮肤配置 | 未导出 | — |
| 蛋仔--大富翁--角色表.xlsx | 角色属性 | ✓ | `src/config/content/roles.lua` |
| 蛋仔--大富翁--道具表.xlsx | 道具属性 | ✓ | `src/config/content/items.lua`、`src/config/gameplay/item_ids.lua` |
| 蛋仔--大富翁--黑市表.xlsx | 黑市商品 | ✓ | `src/config/content/market.lua`、`src/config/content/market_catalog.lua` |
| 蛋仔--大富翁--地图示例.xlsx | 地图布局示例 | 未导出 | — |
| 蛋仔策划案--大富翁.docx | 完整策划案文档 | 未导出 | — |

## 维护流程

修改 xlsx 后跑 `lua tools/data/export_xlsx.lua` 生成 Lua 表。
