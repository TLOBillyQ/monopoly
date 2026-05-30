# skin-purchase-archive — 皮肤购买存档

规约：`features/v102/skin_persistence.feature`（2 场景）。付费购买的皮肤写宿主存档，
第二次开局读回；记住上次装备并在重载时自动穿上、还原宿主模型。赠礼/免费解锁不持久化
（用户裁定仅付费持久化；不写"赠礼不持久化"的断言场景）。

## 现状缺口

`ui.skin_panel.owned_by_role` / `selected_by_role` 纯内存，每次 `_ensure_state`
初始化为空（`src/ui/coord/skin_panel.lua:24-25`），开局即清零。付费购买扣金豆后只写内存
`_unlock_skin`，不落任何存档 → 第二次开局皮肤全锁回。

## 真相来源

宿主 **无权属查询**：`GameAPI.get_goods_list()` 只返回商品目录，不返回"某玩家是否已购买"。
所以只能自持久化——购买成功写 role archive，开局 init 读回。

## 实现要点（coder）

1. **持久化端口**（新边界）：建议 `skin_archive` 端口 —
   `load_owned(role)` / `mark_owned(role, product_id)` /
   `load_equipped(role)` / `save_equipped(role, product_id)`。
   - coordinator `open`/`_ensure_state`：seed `owned_by_role` + `selected_by_role`，
     并对持久化的 equipped 自动 `equip`（触发换装回调 → 宿主换模型）。
   - `_unlock_skin`（purchase 源）→ `mark_owned`；
     `_equip_owned_skin` / `_unequip` → `save_equipped`。
2. **宿主实现**：仿 `src/app/host_integrations/leaderboard.lua` 接
   `Role.get/set_archive_by_type`（`runtime_ports.get/set_archive_int` 同款端口）。
3. **step handlers**（新）：
   - `玩家付费购买槽位<槽位>的皮肤` —— 走真实 purchase 成功持久化路径（非 unlock 捷径）。
   - `玩家重新开局并打开皮肤商店` —— 弃 panel state 重建 + 读档。
   - `换装回调已注册` / `换装回调收到的皮肤产品ID为<产品ID>` —— equip 回调 spy。
4. 新 feature 入 runner/generator + 补 busted 覆盖 + 闭突变。

## 架构依赖（architect）

- 存档**编码方案**：`Int` 位掩码（1 key，bit/product）vs `Str` 产品 id 列表 vs 每皮肤
  `Bool`。`ArchiveType` 支持 `Bool/Int/Str/Fixed/SheetID/Timestamp`。
- **host 编辑器需新增 Archive key**（外部配置，像 leaderboard 的 `WIN_COUNT_KEY`）。
- 建议起 ADR 钉这个新持久化边界 + 选定编码。

## 联动

- 与脱下还原模型（handoff `skin-unequip-restore`，commit 4a749722 起）同一套
  capture-before-equip / 换模型机制；自动穿上复用还原路径。
- 金豆是付费货币，覆盖必须含付费购买路径。
