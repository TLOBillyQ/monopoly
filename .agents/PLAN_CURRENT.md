# 黑市金豆/乐园币付费道具接入（官方商城桥接）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循 `/.agents/PLANS.md` 维护。

## 目的 / 全局视角

当前黑市里部分道具和座驾使用“金豆/乐园币”计价，但余额完全是本地字段，和官方商品库存没有打通。改造后，金豆/乐园币将以官方 `commodity` 库存为准：余额不足可直接拉起官方购买面板，购买成功自动回写余额，黑市扣费通过 `consume_commodity` 真实消耗。用户可观察到：在黑市买金豆/乐园币商品时，余额和官方库存一致，充值后可立即继续购买。

## 进度

- [x] (2026-02-10 08:20Z) 清空并重写 `/.agents/PLAN_CURRENT.md`，建立本任务计划。
- [x] (2026-02-10 08:28Z) 新增 `Config/RuntimePaidGoods.lua` 与 `src/game/commerce/PaidCurrencyBridge.lua`。
- [x] (2026-02-10 08:31Z) 在 `GameplayLoop` 与 `Market` 接入托管币种同步、扣费与补购面板逻辑。
- [x] (2026-02-10 08:35Z) 新增 `/.agents/tests/suites/paid_currency.lua` 并挂载到 `regression.lua`。
- [x] (2026-02-10 08:36Z) 执行全量回归，`All regression checks passed (81)`。

## 意外与发现

- 观察：在测试环境下常缺少 `GameAPI.get_goods_list/get_role`，如果强依赖会导致逻辑不可用。
  证据：桥接模块新增能力探测与安全降级；回归 `81` 项通过。
- 观察：黑市托管币种扣费需要兼容“价格不是商品最小单位整数倍”的配置错误。
  证据：`PaidCurrencyBridge.consume_currency` 已做对齐校验并拒绝扣费，避免错账。

## 决策日志

- 决策：接入入口仅放在黑市购买链路，不新增主界面充值按钮。
  理由：用户已明确选择“黑市内触发”，改动范围最小且不依赖新增 UI 节点。
  日期/作者：2026-02-10 / Codex
- 决策：官方商品映射按“商品名配置”实现。
  理由：避免硬编码商品 ID，降低编辑器商品改名/重建后的维护成本。
  日期/作者：2026-02-10 / Codex
- 决策：金豆/乐园币扣费口径采用官方库存，黑市扣费调用 `consume_commodity`。
  理由：避免本地余额与真实库存双轨漂移。
  日期/作者：2026-02-10 / Codex

## 结果与复盘

本次目标已完成，黑市里的金豆/乐园币消费链路已接入官方商品库存：

- 新增 `RuntimePaidGoods` 配置，按商品名映射“金豆/乐园币 -> goods/commodity”。
- 新增 `PaidCurrencyBridge`，实现商品解析、余额同步、扣费、补购面板、购买成功事件回写。
- `GameplayLoop.set_game` 已在开局/重开时初始化桥接。
- `Market` 已改为托管币种优先同步余额，扣费走 `consume_commodity`，不足时拉起购买面板。
- 新增 `paid_currency` 回归套件，覆盖同步、扣费、不足拉面板、购买成功回写。

验收结果：`lua .agents/tests/regression.lua` 输出 `All regression checks passed (81)`，满足“行为可观察 + 全量通过”。

## 背景与导读

本次改动涉及四层：

第一层是配置层，在 `Config` 新增“币种 -> 官方商品名”的映射；
第二层是桥接层，在 `src/game/commerce` 负责读 `GameAPI.get_goods_list`、同步余额、拉起购买面板、处理购买成功事件；
第三层是业务层，在 `src/game/market/Market.lua` 将金豆/乐园币消费改为桥接扣费并在余额不足时触发补购；
第四层是测试层，在 `/.agents/tests` 增加回归用例验证关键行为。

关键现状：

- 黑市数据来自 `Config/Generated/Market.lua`，已有 `currency = 金豆/乐园币`。
- 玩家余额字段由 `GameState` 维护，当前金豆/乐园币只在黑市消费时做本地扣减。
- 工程已有事件与 API 封装，可直接注册 `EVENT.SPEC_ROLE_PURCHASE_GOODS`。

## 工作计划

先补配置与桥接模块，确保在“无 API / 无商品映射”情况下可以安全降级。然后在 `GameplayLoop.set_game` 中初始化桥接，保证开局与重开都生效。接着修改 `Market.buy_with_opts` 和可购买判断：对托管币种先同步余额，扣费时走桥接，余额不足时对真人玩家拉起官方购买面板。最后补充测试桩与回归用例，覆盖“同步、扣费、余额不足拉面板、购买成功回写”四条主链路，并跑全量回归。

## 具体步骤

工作目录：`/Users/billyq/Dev/Github/Lua/monopoly`

1. 新增 `Config/RuntimePaidGoods.lua`，定义金豆/乐园币商品名映射。
2. 新增 `src/game/commerce/PaidCurrencyBridge.lua`，实现：
   - 商品名解析（`GameAPI.get_goods_list`）
   - 余额同步（`Role.get_commodity_count` -> `game:set_player_balance`）
   - 扣费（`Role.consume_commodity`）
   - 补购面板（`Role.show_goods_purchase_panel`）
   - 购买成功事件处理（`EVENT.SPEC_ROLE_PURCHASE_GOODS`）
3. 修改 `src/game/turn/GameplayLoop.lua`，在 `set_game` 初始化桥接。
4. 修改 `src/game/market/Market.lua`，接入托管币种同步、扣费和补购触发。
5. 新增 `/.agents/tests/suites/paid_currency.lua` 并在 `/.agents/tests/regression.lua` 挂载。
6. 运行：
   lua .agents/tests/regression.lua

## 验证与验收

验收以“行为可观察”为准：

- 当托管币种余额足够时，黑市购买成功且官方库存减少。
- 当托管币种余额不足时，黑市不扣款并弹官方购买面板。
- 触发 `SPEC_ROLE_PURCHASE_GOODS` 后，玩家金豆/乐园币余额立即更新。
- 非托管币种（如金币）行为不变。
- 运行 `lua .agents/tests/regression.lua`，预期全部通过。

## 可重复性与恢复

本改动可重复执行；若线上商品名配置缺失，桥接会降级为“仅本地余额判断 + 余额不足提示”，不会阻断流程。回滚时按顺序撤销：`Market` 接入 -> `GameplayLoop` 接入 -> `PaidCurrencyBridge` -> `RuntimePaidGoods`。

## 产物与备注

主要产物：

- 付费币桥接配置与模块。
- 黑市托管币种扣费改造。
- 购买成功余额自动同步机制。
- 回归用例与测试桩。

## 接口与依赖

新增模块接口（`src.game.commerce.PaidCurrencyBridge`）：

- `setup_for_game(game)`
- `is_managed_currency(currency)`
- `sync_player_currency(game, player, currency)`
- `consume_currency(game, player, currency, amount)`
- `open_purchase_panel(player, currency)`

依赖 API：

- `GameAPI.get_goods_list`
- `GameAPI.get_role`
- `Role.get_commodity_count`
- `Role.consume_commodity`
- `Role.show_goods_purchase_panel`
- `EVENT.SPEC_ROLE_PURCHASE_GOODS`

计划更新说明（2026-02-10）：新建“黑市金豆/乐园币付费道具接入”可执行计划，替换旧任务文档。
计划更新说明（2026-02-10）：完成桥接模块、黑市接入与回归验证，并回填结果与证据。
