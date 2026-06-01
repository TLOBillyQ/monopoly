# 座驾系统整体拆除 — 项目状态 (handoff: vehicle-teardown)

用户裁定（2026-05-30）：**整体拆除座驾功能**；操作倒计时 = 15 秒、黑市购买 = 60 秒。

## specifier 本轮已落 (main)

- 删除 `features/game/vehicles.feature`（5 个场景全是座驾专属：座驾决定骰子数 / 付费座驾购买 / 支付回调装备 / 地雷摧毁座驾 / 不可摧毁座驾免疫）。
- `features/game/turn_flow.feature`：两处超时 Examples 由 10 改为 操作选择=15 / 黑市购买=60 / 道具目标选择=15；警告阈值 5/3/0 不变。
- `docs/decisions/0011` 加修订段（D1 倒计时 10→15/60、座驾项撤回、F2 不实现）。
- 验证：`make acceptance` 绿（22 specs 重生成，RESULT 531 ok）。

座驾 step 句仅 `vehicles.feature` 使用，无跨 feature 复用。`tools/acceptance/acceptance_features.lua` 本就无 vehicles 条目（座驾从未进 busted 验收套件），无需改。

## 待 coder 拆除（代码层）

骰子基线裁定：**基础骰子数固定为 1**（现 `default_dice_count`/无座驾基线）；道具 2002 遥控、2003 加倍 独立于座驾，**保留**。

- `src/rules/dice.lua`：移除 `dice_count_for_vehicle_level`，基础骰子数固定 1。补 busted 钉「基础骰子数=1」（替代被删的座驾骰子规则）。
- 地雷→座驾耦合：`src/rules/movement.lua` 及 `src/rules/land/*`、`src/rules/items/demolish.lua` 等中「地雷摧毁座驾 / 4 级座驾免地雷」逻辑移除 → 所有玩家踩雷一律住院。
- 付费座驾购买 / 装备 / 宿主支付回调路径移除（黑市去付费座驾）。
- UI：`src/ui/panels/skin_panel.lua` 等座驾页 / HUD 座驾展示移除。
- `src/config/content/items.lua` 2005 地雷卡 description「摧毁该玩家的座驾」散文改为不提座驾（如「强制住院」）。
- 座驾资源 / 常量残留清理（注：`src/config/content/runtime_refs.lua` 现已无 4001-4006 块）。
- 受影响 busted：`spec/behavior/rules/market_choice_residual_closure_spec.lua`、`market_choice_survivors_spec.lua`、`market_choice_extra_survivors_spec.lua`（引用座驾）随拆除调整。
- `tools/acceptance/steps/vehicles.lua` step handler 删除（死 handler，不删不报错但应清）。
- 可选：补 busted 钉 `timing.scope_timeouts`（审计 F1 旁覆盖缺口：改 choice/market_buy 无测试可抓）。

## 待 architect（下游）

座驾系统整体拆除是架构级移除，补一条拆除 ADR（subsystem removal + 骰子基线固定 1 的理由）。
