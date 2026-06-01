---
kind: adr
status: proposed
owner: specification
last_verified: 2026-05-23
---
# ADR 0011 — 策划案 1.02 与 Gherkin 规格对齐边界

**Status**: Proposed (2026-05-23, 等待用户 review)
**Trigger**: 审计 `docs/product/design-source/蛋仔策划案--大富翁.docx` 与 `features/` 的产品行为覆盖。
**Related**: `features/game/setup.feature`, `features/game/vehicles.feature`, `features/game/movement.feature`, `features/game/turn_flow.feature`, `features/game/items.feature`, `features/game/endgame.feature`, [ADR 0010](0010-gift-skin-button-stubbed.md), `docs/product/map.md`

---

## 决策

### D1 — Gherkin 规格按策划案补齐当前可描述行为

本轮把下列策划案 1.02 行为升级为 feature 契约：

- 开局玩家数、单人补 3 个电脑、初始金币/地块/道具/卡槽
- 黑市经过时自动打开，关闭后继续剩余步数
- 操作选择统一 10 秒超时并执行默认选项
- 电脑玩家在道具阶段按 AI 优先级主动尝试使用道具
- 道具获得时先放大展示 3 秒，再收入卡槽
- 行动前/主动/触发型道具的使用时机
- 医院 5000 金币医药费
- 座驾骰子数、付费座驾购买、地雷与不可摧毁座驾关系

### D2 — 谢礼皮肤继续遵守 ADR 0010

策划案要求未获得谢礼皮肤点击后跳转赞助弹窗。当前宿主 gift/赞助接口仍未接入，ADR 0010 已决定把赠礼类按钮钉为不可点。

本轮不修改 `features/v102/skin_shop.feature` 的赠礼按钮行为。解除条件仍以 ADR 0010 为准。

### D3 — 路障行为暂不按策划案回滚

策划案描述路障为“停止、移除、访问该位置事件”。当前 `docs/product/map.md` 已追加稳定规则：路障停止后扣留 1 回合，且现有 movement feature 已锁定“剩余步数不继续”。

本轮不改路障规格。若要回到策划案原始行为，需要单独决策：

- 保留地图规格增强：路障停止并扣留 1 回合
- 回滚策划案原始行为：路障只中断当前位置事件，不额外扣留

### D4 — 附属模块只记录缺口，不纳入本轮 Gherkin

签到、分享任务、粉丝团权益、谢礼宿主集成、成就、排行榜依赖宿主账号、支付、社交、统计接口。本轮只做玩法与已接入 v102 UI 的 feature 对齐，不为这些模块写可执行 Gherkin。

---

## 后续

用户 review 接受后，specifier 通知 coder 按本轮 feature 更新 step handler 与生产实现。coder 需要优先处理当前会失败的新 step 文案，再实现生产行为。

---

## 修订 (2026-05-30, 用户裁定)

### D1 操作倒计时 — 10 秒改为分场景值（已落 feature）

用户裁定操作倒计时权威值为 **15 秒**，黑市购买单独 **60 秒**。`features/game/turn_flow.feature` 的超时 Examples 由 10 改为：操作选择 / 道具目标选择 = 15，黑市购买 = 60。生产 `src/config/gameplay/timing.lua` `scope_timeouts`（choice=15 / target_select=15 / market_buy=60）本就如此，本次仅消除 feature 与生产的漂移；code 不需改。

> D1 原文「操作选择统一 10 秒超时」作废，以本修订为准。

### D1 座驾相关项 — 撤回（座驾系统整体拆除）

用户裁定**整体拆除座驾功能**。本轮 specifier 删除 `features/game/vehicles.feature`，D1 中「座驾骰子数、付费座驾购买、地雷与不可摧毁座驾关系」一项随之撤回。拆除后：基础骰子数固定为 1（道具 2002 遥控 / 2003 加倍 不受影响仍保留），地雷不再有「不可摧毁座驾」免疫、黑市不再售付费座驾。

F2（机会表 3014-3016 / 3035-3037「更换座驾」卡）随之裁定为**不实现**；`features/game/chance.feature` 目录本就只锁 31 张，无需改动。`agent_context/draft-F2-vehicle-gift-chance-cards.md` 作废。

座驾**代码**拆除（`src/rules/dice.lua` 等）由 coder 实施；其架构级拆除 ADR 由 architect 在下游补记。详见 `agent_context/vehicle-teardown-context.md`。
