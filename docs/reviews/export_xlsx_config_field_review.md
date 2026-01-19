# 导表字段一致性审查

**日期**: 2026-01-19  
**范围**: `export_xlsx.bat`、`scripts/export_xlsx.py` 与 `src/config/*.lua`

---

## 一、所核之表

导表脚本所落配置仅此七件：

- `src/config/tiles.lua`
- `src/config/roles.lua`
- `src/config/items.lua`
- `src/config/vehicles.lua`
- `src/config/market.lua`
- `src/config/chance_cards.lua`
- `src/config/constants.lua`

凡未列者（如 `map.lua`、`landing_effects.lua`）不在此审。

---

## 二、逐项核对

### 1) `tiles.lua`

**导表字段**: `id`、`name`、`type`、`row`、`col`、`build_row`、`build_col`、`price`、`upgrade_costs`、`rents`。  
**现有字段**: 同上。

**细注**：脚本仅在价格/租金列有值时写入 `upgrade_costs`、`rents`；现文件对特殊地块亦显式写零。若表中空白，则导表后可能缺此二键，虽 `src/core/tile.lua` 以空表兜底，然数据形态将异。

### 2) `roles.lua`

**导表字段**: `id`、`name`、`prototype`、`description`。  
**现有字段**: 同上。  
**结论**: 一致。

### 3) `items.lua`

**导表字段**: `id`、`name`、`tier`、`shop_currency`、`shop_price`、`weight`、`angel_immune`、`timing`、`usage`、`description`。  
**现有字段**: 同上。  
**结论**: 一致。

### 4) `vehicles.lua`

**导表字段**: `id`、`name`、`tier`、`dice_count`、`indestructible`。  
**现有字段**: 同上。  
**结论**: 一致。

### 5) `market.lua`

**导表字段**: `order`、`product_id`、`name`、`page`、`kind`、`currency`、`price`、`limit`。  
**现有字段**: 同上。  
**结论**: 一致。

### 6) `chance_cards.lua`

**导表字段**: `id`、`description`、`weight`、`negative`、`target`、`effect`，并按效果写入 `amount/percent/vehicle_id/steps/item_id/count/destination_tile_id`。  
**现有字段**: 同上（以效果定字段）。  
**结论**: 一致。

### 7) `constants.lua`

**导表字段**:  
`starting_cash`、`starting_jindou`、`starting_leyuanbi`、`default_dice_count`、`dice_with_vehicle`、`action_timeout_seconds`、  
`pass_start_bonus`、`hospital_fee`、`hospital_stay_turns`、`mountain_stay_turns`、`tax_rate`、`inventory_slots`、  
`deity_duration_turns`、`unlimited_currency`。

**现有字段**: 上述全有，且另有  
`turn_limit`、`max_tile_occupants`、`item_phase_queue`。

**不一致处**：

- **缺字段**：导表不写 `turn_limit`、`max_tile_occupants`、`item_phase_queue`，而三者于运行时有用（`src/game.lua`、`src/gameplay/item_phase.lua`、`src/gameplay/movement_service.lua`）。若导表覆盖，则三键消失。
- **值差**：导表内置 `unlimited_currency = "广告"`，现有为 `"밤멩"`。若常量表不覆写该值，则导表后会改写。

---

## 三、结语

除常量表外，诸导表字段与现有配置大体相符；常量表之字段缺失与默认值差异，为当前唯一显著不合处。若欲以导表覆盖现有配置，宜先补全常量字段与默认值，或在表中显式声明之。
