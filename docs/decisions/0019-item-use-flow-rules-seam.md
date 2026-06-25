---
kind: adr
status: stable
owner: architecture
last_verified: 2026-06-24
---
# ADR 0019 — 道具使用流程归属 rules/items seam

## 背景

`CONTEXT.md` 将 `道具使用流程` 定义为玩家或电脑玩家尝试使用背包中的道具卡时，从可用性判断、目标或参数选择，到效果结算并确定道具消耗或留存的完整玩法过程。现有代码中，可用性、目标候选、玩家 choice、AI 选择、效果结算、消耗时机和验收断言容易散落在 `rules/items`、`turn`、UI adapter、AI 策略和 acceptance step 之间，导致同一道具语义被多个入口各自理解。

## 决策

在 `rules/items` 引入一个深 module 表达 **道具使用流程**。它的外部 seam 是道具规则 interface，而不是 `turn`、UI 或 acceptance。

该 module 至少承担两阶段入口：

- 开始使用道具：检查 actor、阶段、背包、道具可用性；生成目标或参数候选；无需选择时直接结算；需要选择时返回等待选择的结构化结果。
- 解析道具选择：验证 pending choice 属于本次道具使用；验证目标或参数仍然合法；执行效果；决定道具消耗或留存；返回结构化结果。

具体函数名和参数形状由实现阶段决定，但 interface 必须保持领域语言。推荐形状为 `begin_item_use(game, actor_id, item_id, context)` 与 `resolve_item_use_choice(game, choice_id, selected_option, context)`。

## 规则归属

该 module 内部拥有以下规则和状态变更细节：

- 道具是否存在于 actor 背包。
- 道具在当前使用阶段是否可用。
- 道具是否需要目标或参数，以及候选如何生成、排序和验证。
- 玩家选择与电脑玩家选择共享同一套候选、可用性、目标合法性和效果结算规则。
- 道具效果如何 apply，以及成功、失败、等待 choice、等待动画等结果如何归一化。
- 道具何时消耗、何时留存；目标选择取消或超时时，道具应留存在背包，而不是依赖外部退还逻辑。
- 非法或不可用路径返回稳定 reason，而不是 `warn + false` 或静默 no-op。

返回值必须是结构化结果，至少能表达成功、等待选择、拒绝、稳定 reason、choice 信息、是否消耗、是否触发动画等语义。旧的 `true`、`false`、`waiting`、`intent.need_choice`、`ok` 等内部返回形状可以继续存在于 implementation 内部，但不得泄漏为新 seam 的 caller 契约。

## Adapter 归属

`turn` 只负责开放道具使用窗口、接收结构化结果后推进 turn-flow、等待动画或处理超时。它不拥有偷窃目标过滤、导弹目标玩家语义、遥控骰点数候选、路障候选、具体道具效果或消耗/留存规则。

UI 只负责把玩家点击和选择翻译成道具使用意图，并展示 module 给出的候选、结果和 reason。UI 不计算候选，不判断每张道具的可用性。

电脑玩家策略只负责从 module 给出的候选中做选择，或决定是否尝试使用某张道具；它不复制目标合法性、消耗时机或具体效果规则。

Acceptance step 降为 adapter：只布置状态、触发玩家可观察动作、读取真实 driver/module 结果。道具使用语义不得在 step handler 中平行实现；这延续 ADR 0012 与 ADR 0017。

## 范围外

本决定不覆盖道具获得展示、道具获得展示队列、商店购买、皮肤解锁、纯图鉴展示或纯背包展示。这些可以有自己的 module 和 seam，但不应被塞进 `道具使用流程`。

## 影响

这个决定提高 locality：道具可用性、目标候选、目标验证、AI/玩家共享规则、效果结算和消耗/留存集中在 `rules/items`。它提高 leverage：`turn`、UI、AI、acceptance 和行为测试穿过同一个小 interface，而不是各自学习每张道具的规则。

测试应把这个 interface 当作主要 test surface。行为测试覆盖开始使用、等待选择、选择解析、非法 reason、消耗/留存和关键道具语义；验收测试继续描述玩家可观察行为，但 step handler 不再复制道具规则。

## 取舍

不把 seam 放在 `turn`：`turn` 管使用窗口和回合推进，但道具规则属于 `rules/items`。

不让 caller 传入 candidates：候选生成是道具语义的一部分；caller 传 candidates 会让 seam 变浅，并让每个入口继续理解每张道具的目标规则。

不做单一同步 `use_item` 大入口：目标玩家、遥控骰点数、路障位置等路径天然存在 pending choice；两阶段 interface 更准确地隐藏流程复杂度。
