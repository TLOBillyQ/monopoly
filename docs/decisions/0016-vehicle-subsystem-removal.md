---
kind: adr
status: accepted
owner: architecture
last_verified: 2026-05-30
---
# ADR 0016 — 座驾子系统整体拆除（架构级）

**Status**: Accepted (2026-05-30, 用户裁定)
**Trigger**: ADR 0011 修订裁定整体拆除座驾功能；其架构级拆除记录下游补于本 ADR。
**Related**: [ADR 0011](0011-planning-doc-feature-alignment.md)（产品决策与倒计时对齐）、`agent_context/vehicle-teardown-context.md`、`features/game/vehicles.feature`（已删）、`src/rules/items/remote_dice.lua`、`src/config/content/constants.lua`

---

## 背景

座驾在策划案 1.02 里是一个附属玩法（座驾等级决定基础骰子数、付费座驾购买、地雷与不可摧毁座驾的免疫关系）。审计（ADR 0011 D1）曾把这些升级为 Gherkin 契约（`features/game/vehicles.feature` 5 个场景）。用户 2026-05-30 裁定**整体拆除**。

**关键架构事实**：座驾从未在 `src/` 落地为子系统——它是一个**规格层存在、生产层未实现**的计划附属模块。拆除时对 `src/` 的真实足迹只有：
- `src/config/content/items.lua` 2005 地雷卡 description 散文里一句「摧毁该玩家的座驾」（纯文案，无逻辑）。
- 确认基础骰子数本就固定为 1（`src/config/content/constants.lua: default_dice_count = 1` → `status_ops.player_dice_count` 直接返回该常量），无 `dice_count_for_vehicle_level` 之类按座驾分级的代码存在。

因此本次「子系统拆除」在架构层等于：**撤回规格契约 + 锁定既有 src 基线 + 清理唯一残留文案**，而非删除一个真实的 src 子系统。

## 决策

### D1 — 撤回座驾规格契约
删除 `features/game/vehicles.feature`（5 个座驾专属场景）。座驾 step 句仅该 feature 使用，无跨 feature 复用；`tools/acceptance/acceptance_features.lua` 本就无 vehicles 条目（座驾从未进 busted 验收套件），无需改。

### D2 — 基础骰子数固定为 1（既有基线，正式锁定）
基础骰子数 = `default_dice_count`（=1），与座驾无关。道具 **2002 遥控骰子 / 2003 骰子加倍**独立于座驾，**保留**——它们经 `remote_dice.apply` / `dice_multiplier` 走自己的规则路径，不依赖任何座驾分级。`config_sanity_spec.lua` 钉死该基线。

### D3 — 解除座驾相关耦合（确认无残留）
- 地雷不再有「不可摧毁座驾」免疫语义：所有玩家踩雷一律强制住院。`src/config/content/items.lua` 2005 description 散文改为不提座驾。
- 黑市不售付费座驾。
- src 全量 `座驾`/`vehicle` 引用扫描为零（已验证）。

### D4 — F2 机会卡「更换座驾」不实现
机会表 3014-3016 / 3035-3037「更换座驾」卡随之裁定不实现；`features/game/chance.feature` 本就只锁 31 张，无需改动。`agent_context/draft-F2-vehicle-gift-chance-cards.md` 作废。

## 后果

- 玩法表面收窄：少一个附属模块的规格契约与文案表面，降低 feature 维护面。
- 无 src 死代码遗留（拆除前 src 本就无座驾子系统）；唯一改动是数据文案 + 既有基线锁定测试。
- 骰子语义简化为「基线 1 + 道具修正（遥控/加倍）」单一来源，便于后续规则推理。
- `items.lua` description 改动是纯数据散文，不进 mutation 闭合环（消费方不断言 description 文本）；其结构-only manifest 已随改动刷新 chunk semanticHash。

## 验证

- `verify --smoke` 绿；`make acceptance` 531 ok（22 specs 重生成）；property 35。
- src `座驾`/`vehicle` 残留扫描 = 0。
