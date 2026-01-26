# 玩法与道具/机会系统接入

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，重构版本的玩法逻辑与道具/机会系统将完整落地并与 UI/商城对接，玩家可以按设计进行投骰、移动、触发事件、使用道具与抽取机会卡，同时 AI 行为保持与设计优先级一致。

## Progress

- [x] (2026-01-26 19:20) 创建本 ExecPlan，明确玩法接入范围。
- [ ] (2026-01-26 19:20) 同步 `src/gameplay` 到 `Refactoring/src/gameplay` 并完成接线。
- [ ] (2026-01-26 19:20) 对照设计表确认道具/机会卡数量与效果覆盖。
- [ ] (2026-01-26 19:20) 打通道具槽位、黑市购买与 UI 提示。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 以仓库根目录 `src/gameplay` 为逻辑实现唯一来源，Refactoring 只做接线与适配。
  Rationale: 保持单一实现，符合 CodingDiscipline 的“相似逻辑合并”要求。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

玩法逻辑当前位于 `src/gameplay/`，配置数据位于 `src/config/`。道具系统包含 19 种道具（`src/config/items.lua`），机会卡配置位于 `src/config/chance_cards.lua`，黑市与座驾配置位于 `src/config/market.lua` 与 `src/config/vehicles.lua`。重构版本需在 `Refactoring/src/` 下保持一致，并通过 UI 管理器/商城接口完成交互。

## Plan of Work

首先确保 `Refactoring/src/gameplay` 与 `Refactoring/src/config` 同步并可 `require`。随后对照 `design/` 的道具表、机会表检查数量与效果覆盖情况，并在差异清单中记录。接着将道具槽位与黑市购买逻辑串入 UI（例如满槽提示、黑市购买失败提示），并保证 AI 自动使用逻辑仍然可用。最后对核心流程（投骰→移动→落地→事件→行动后）进行一次端到端验证。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 同步 gameplay 代码
    robocopy src\\gameplay Refactoring\\src\\gameplay /E

    # 2) 校验道具与机会卡配置
    #    - design/蛋仔--大富翁--道具表.xlsx
    #    - design/蛋仔--大富翁--机会表.xlsx
    #    - Refactoring/src/config/items.lua
    #    - Refactoring/src/config/chance_cards.lua

    # 3) 验证黑市购买与道具槽位提示
    #    - Refactoring/src/gameplay/market_service.lua
    #    - Refactoring/src/gameplay/item_inventory.lua

## Validation and Acceptance

执行后需满足：`Refactoring` 运行时可以完成一回合流程（投骰、移动、落地事件、行动后结束）；道具卡可抽取并进入道具槽，满槽时有明确提示；机会卡能够按权重抽取并执行效果；AI 自动操作不出现死锁或异常。

## Idempotence and Recovery

代码同步可重复执行。若发现行为回退或逻辑异常，应以 `src/` 为唯一来源重新覆盖 `Refactoring/src/gameplay`，避免在 Refactoring 内做分叉修改。

## Artifacts and Notes

建议输出“道具/机会卡对照表”作为执行证据，列出每个 ID 在设计表与配置中的对应关系，确保数量一致。

## Interfaces and Dependencies

依赖 `Refactoring/src/config/*.lua` 的配置一致性与 UI 管理器的弹窗支持。外部接口以 `gameplay/choice_handlers` 与 `IntentDispatcher` 为主，不允许在 gameplay 中直接引用 UI 实现。

本计划更新记录：

2026-01-26 19:20 创建本计划，原因是玩法与道具/机会系统是需求完整性核心。
