# 皮肤脱下 — 宿主还原接线（specifier 验收规约）

Handoff 名：`skin-unequip-restore`

## 背景 / 缺口

Equip 已通：`host_install.lua:46` `skin_panel.configure_equip` → 解析
`runtime_refs.skins[tostring(product_id)]` 数值资源 id → `cosmetics.equip(role_id, resource_id)`
→ 宿主 `unit.set_model_by_creature_key`。busted 钉死：`host_install_spec.lua:128`
`skip_context_install_wires_skin_panel_to_skin_equip`（断言 `creature_key == refs.skins[product_id]`）。

Unequip 半成品：
- UI 面板层完整（`skin_panel._unequip` 清选中 / 存 nil / 调 unequip 回调；feature + step + spec 覆盖面板层）。
- `cosmetics.unequip(role_id, default_creature_key)` 已存在（用 default key 转调 equip）。
- **缺口**：`host_install.lua` 从不调 `skin_panel.configure_unequip(...)`。脱下时宿主不还原模型。

EggyAPI：还原走 equip 同一接口 `Character.change_custom_model_by_creature_key(creature_key)`
（封装为 `unit.set_model_by_creature_key`，`EggyAPI.lua:1872`）。脱下 = 把 creature 设回创建角色
creature key，**无需** reset 专用接口。

## 用户裁定

- 默认还原语义：**全局单一默认 creature key = 1**（所有玩家角色 1001/1002/1003 都还原到同一 creature 1，
  即创建角色的默认模型）。roles.lua 无每角色 creature_key，与此一致。
- 默认常量位置：**命名 ref** —— `refs.default_creature = 1`，与 `refs.skins` 解析表对称、可发现、可变异。

## 验收规约（对称于 equip）

1. `runtime_refs.lua`：新增 `refs.default_creature = 1`。
2. `host_install.lua`：在 `_load_required_modules` 内，紧随 `configure_equip` 之后，接线
   `skin_panel.configure_unequip(function(role_id) return skin_equip.unequip(role_id, runtime_refs.default_creature) end)`。
3. 行为闭合（busted，coder 写）：在 `spec/behavior/app/host_install_spec.lua` 加一条镜像
   `skip_context_install_wires_skin_panel_to_skin_equip` 的用例 —— stub `skin_equip.unequip`，open 面板 →
   buy+equip → unequip，断言 unequip 接线收到 `role_id` 且 `default_creature_key == runtime_refs.default_creature`（==1）。
   注意：`refs.default_creature` 经 host_install 透传到 unequip，断言取 `runtime_refs.default_creature` 而非硬写 1，
   以杀掉常量变异并随 ref 变更自洽。

## 边界 / 非目标

- 无 Gherkin 改动：acceptance 用 fake 回调，资源解析在 host_install 层（与 equip 解析同样不进 Gherkin corpus）。
  现有 `features/v102/skin_shop.feature` 脱下场景（`脱下已装备皮肤` / `脱下当前皮肤触发还原回调`）覆盖面板层，保持不变。
- 不动 `cosmetics.unequip`（签名已满足）。
- 持久化已由 `_save_equipped(., nil)` 覆盖，本任务不涉及。

## 验证

coder：`make verify --smoke`（src 七层行为 spec）；handoff 前 `make verify`。host_install 接线属 `src/app/*`，
busted 行为 spec 是最低验证线。
