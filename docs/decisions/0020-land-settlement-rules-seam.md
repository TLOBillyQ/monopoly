---
kind: adr
status: stable
owner: architecture
last_verified: 2026-06-24
---
# ADR 0020 - 落地结算流程归属 rules/land seam

## 背景

`落地结算流程` 是棋子移动结束或被效果移动后，根据最终落点触发地雷、起点奖励、道具格、机会卡、医院、深山、黑市、买地、升级、租金、税务等效果，并在必要时生成玩家或电脑玩家选择的完整玩法过程。

当前实现已经有可复用材料，但外部 seam 仍然浅：

- `src/turn/phases/land.lua` 同时负责落地规则执行、递归落地处理、等待 choice、动作动画、landing visual hold 和回合状态路由。
- `src.rules.effects.pipeline` 是通用机制，caller 仍要传 `landing_defs`、optional choice 形状、cost resolver 和 `on_need_landing` 等落地语义细节。
- `src.rules.bootstrap` 的 `landing_optional_effect` handler 和 `src.rules.choice_handlers.land` 直接理解 optional effect、租金卡、免税卡 choice 的 meta 与执行细节。
- `spec/support/shared_support.lua` 复制了 `_resolve_landing` 风格的落地结算逻辑，行为测试容易穿过私有实现形状，而不是穿过稳定 interface。
- `tools/acceptance/turn_driver.lua` 已经把 AI 落地结算当作真实 seam 使用，但它仍通过 turn phase 间接触发，并不能作为 rules 层的稳定 interface。

这些入口都在学习落地结算的内部结构。后续改买地、升级、租金卡、免税卡、连锁落地或 AI 落地决策时，复杂度会在 `turn`、choice handler、test helper 和 acceptance driver 中扩散。

## 决策

在 `rules/land` 引入一个深 module 表达 **落地结算流程**。它的外部 seam 是 land rules interface，而不是 `turn` phase、通用 effect pipeline、choice handler、UI 或 acceptance。

该 module 至少承担两阶段入口：

- 开始落地结算：解析 actor 与落点；按稳定顺序执行 mandatory effects；生成 optional buy/upgrade choice；处理 effect 返回的后续落地请求；返回结构化结算结果。
- 解析落地结算选择：验证 pending choice 属于本次落地结算；验证 option 仍在候选内；执行买地、升级、强征卡、免费卡、免税卡或正常支付；返回结构化结算结果。

具体函数名和参数形状由实现阶段决定，但 interface 必须保持领域语言。推荐形状为 `begin_landing_settlement(game, actor_id, context)` 与 `resolve_landing_settlement_choice(game, choice, action, context)`。`context` 可以携带 `move_result`、递归深度或 follow-up 来源；caller 不得传 `landing_defs`、effect runner opts、effect id 查找函数或 turn wait 状态。

## 规则归属

该 module 内部拥有以下规则和状态变更细节：

- 落地效果顺序：地雷、起点奖励、道具格、机会卡、医院、深山、黑市、买地、升级、租金、税务。
- 每个 effect 是否可在当前落点应用，以及 mandatory 与 optional 的分流。
- 买地、升级的候选、价格、确认文案、余额不足 reason 和实际扣款/产权变更。
- 租金结算、连片租金、深山免租、破产租金、强征卡、免费卡与 pending 免租状态。
- 税务结算、免税卡与 pending 免税状态。
- effect 触发强制移动或传送后的后续落地请求，包括最大递归深度与稳定失败 reason。
- 玩家与电脑玩家共享同一套候选、choice meta、option 验证和执行规则。
- 非法或不可用路径返回稳定 reason，而不是 `warn + finish_choice(false)` 或静默 no-op。

返回值必须是结构化结果，至少能表达已结算、等待选择、后续落地、拒绝、稳定 reason、choice 信息、是否触发动作动画、是否需要移动动画等待等语义。旧的 `waiting`、`intent.need_choice`、`need_landing`、`ok`、`false` 等内部形状可以继续存在于 implementation 内部，但不得泄漏为新 seam 的 caller 契约。

## Adapter 归属

`turn/phases/land.lua` 只负责把 turn phase 输入翻译成“开始落地结算”，接收结构化结果后路由到 `wait_choice`、`wait_action_anim`、`wait_move_anim`、`wait_landing_visual`、`move_followup` 或 `post_action`。它不拥有 effect 顺序、optional effect 构造、租金卡/免税卡语义、后续落地递归或落地 choice 验证。

`move_followup` 只负责在移动动画或位置效果结束后重新进入落地结算。它不构造落地 rules context，也不解释 `need_landing`。

`choice_handlers/land.lua` 与 `bootstrap.optional_effect_handler` 降为 adapter：只把 `choice_select` 或 `choice_cancel` 交给 `resolve_landing_settlement_choice`，并按结构化结果清理 choice 或继续等待。它们不得直接调用 `land_actions.execute_*`、查找 `landing_defs` 或重建 `game_ctx`。

UI 只展示 module 给出的 choice、confirm copy、reason 和结果。UI 不计算买地/升级/租金/税务候选。

电脑玩家策略只从 module 给出的候选中做选择。它不复制买地/升级可用性、租金卡优先级或免税卡语义。

Acceptance step 与 `turn_driver` 降为 adapter：布置状态、触发玩家可观察动作、读取真实结果。不得在 step handler 或 driver 中平行实现落地结算规则。

## 测试边界

行为测试应把新 land settlement interface 当作主要 test surface。重点覆盖：

- mandatory effects 的顺序与短路行为。
- unowned land 生成买地 choice，own land 生成升级 choice，对手地触发租金或租金卡 choice。
- 强征卡、免费卡、免税卡的 use/skip 分支。
- 黑市、机会卡、地雷、医院、深山、税务等非土地格效果。
- 强制移动或传送后的后续落地，包括递归深度上限。
- AI 与玩家通过同一 choice 候选和执行入口落地。
- 非法 choice、过期 choice、缺 actor、缺 tile、option 不在候选内等稳定 reason。

旧的 `spec/support/shared_support.resolve_landing` 应改为调用新 interface，或只作为薄 adapter 保留。测试不得继续复制 `effect_pipeline.run(landing_defs, ...)` 的私有组合。

Mutation 重点放在新 module 的外部 interface，而不是分别突变 `turn/phases/land.lua` 的 wait routing 与 `rules/effects/pipeline.lua` 的通用机制。`turn` wait routing 仍应有自己的窄测试，但不应承载落地规则断言。

## 范围外

本决定不要求删除通用 `rules/effects.pipeline`。它可以继续作为 land settlement implementation 的内部机制，也可以继续服务 chance、item 或其它 effect 系统。决策只约束外部 caller 不再把它当作落地结算 interface。

本决定不覆盖纯 UI 动画表现、行动状态面板渲染、地图视觉同步、黑市商品购买流程、破产后资产清理或道具使用流程。它们可以由各自 module 和 seam 处理。

## 影响

这个决定提高 locality：落地效果顺序、候选生成、choice meta、买地/升级/租金/税务执行和后续落地递归集中在 `rules/land`。它提高 leverage：`turn`、choice handler、AI、acceptance 和行为测试穿过同一个小 interface，而不是各自学习 `landing_defs`、effect runner opts 和每类 choice 的执行细节。

它也让 `turn/phases/land.lua` 更浅：保留 wait/animation/phase routing，而把玩法语义下沉到 rules。删除新 module 时，复杂度会重新散回 `turn`、choice handler、test helper 和 acceptance driver；这通过 deletion test。

## 取舍

不把 seam 放在 `turn/phases/land.lua`：turn phase 拥有等待和状态路由，但落地结算是玩法规则，属于 `rules/land`。

不把 seam 放在 `rules/effects.pipeline`：pipeline 是通用执行机制，不知道落地领域语言。让 caller 传 `landing_defs` 和 optional opts 会让 interface 继续浅。

不把买地/升级、租金、税务拆成多个外部入口：这些路径共享落地上下文、choice 生命周期和后续 turn 推进。拆成多个 caller-facing seam 会让 caller 继续编排流程；可以保留内部小 module，但外部 interface 应表达完整落地结算。

不让 acceptance driver 成为 rules seam：driver 是测试 adapter，只能触发真实玩法和观察结果，不能成为生产语义的接口。
