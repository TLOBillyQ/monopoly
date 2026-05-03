---
kind: report
status: generated
owner: quality
last_verified: 2026-05-04
---
# Market 子系统架构依赖图

> 生成日期：2026-05-01
> 配套：[plan.md](../../plan.md)（pending_choice 原地改写审计）、commit `a54beb8`、`78acda7`
> 维护方式：手工绘图。新增文件或调整 require 关系时同步更新。

箭头方向：**依赖方 → 被依赖方**（require 方向）。★ 标记 = `plan.md` 审计的关键焦点。

## 总览：market 子系统跨层依赖

```
                                     ┌─────────────────────────────────────┐
                                     │  config/content                     │
                                     │   market.lua  ─►  market_catalog ─► │
                                     │                       items.lua     │
                                     └──────────────┬──────────────────────┘
                                                    │
                ┌───────────────────────────────────┼────────────────────────────────┐
                │                                   ▼                                │
                │            ┌──────────────────────────────────────┐                │
                │            │  rules/market  (核心规则)            │                │
                │            │                                      │                │
                │            │   init.lua  (对外门面)               │                │
                │            │     │                                │                │
                │            │     ├─► query/                       │                │
                │            │     │     context.lua  ◄── 所有子模块│                │
                │            │     │     eligibility.lua            │                │
                │            │     │                                │                │
                │            │     ├─► choice/                      │                │
                │            │     │     builder.lua ──► query/*    │                │
                │            │     │     session.lua ★ ──► builder, │                │
                │            │     │              feedback,         │                │
                │            │     │              choice/contract   │                │
                │            │     │     feedback.lua               │                │
                │            │     │     outcome.lua ──► session    │                │
                │            │     │                                │                │
                │            │     ├─► purchase/                    │                │
                │            │     │     core.lua ──► policy,       │                │
                │            │     │              local_purchase,   │                │
                │            │     │              paid_callback,    │                │
                │            │     │              paid_purchase_port│                │
                │            │     │     local_purchase ─► fulfillm.│                │
                │            │     │     paid_fulfillment ─► policy,│                │
                │            │     │              fulfillment       │                │
                │            │     │     paid_callback ─► session   │                │
                │            │     │     fulfillment ─► items/inv.  │                │
                │            │     │                                │                │
                │            │     ├─► auto.lua ──► query, purchase │                │
                │            │     ├─► effects.lua  ──► (self)      │                │
                │            │     └─► paid_purchase_port.lua (port)│                │
                │            └──────────────────────────────────────┘                │
                │                          ▲          ▲                              │
                │       ┌──────────────────┘          └──────────────┐               │
                │       │                                            │               │
                │  ┌────┴──────────────────────┐         ┌───────────┴─────────┐     │
                │  │ rules/bootstrap           │         │ rules/choice_       │     │
                │  │   registries.lua          │         │   handlers/         │     │
                │  │     ─► market.effects     │         │   market.lua        │     │
                │  │ rules/ports/{intent_out,  │         │   ─► market(rules), │     │
                │  │   auto_play, event_feed}  │         │      choice.outcome,│     │
                │  └───────────────────────────┘         │      query.context  │     │
                │                                        └─────────────────────┘     │
                │                                                                    │
                │           ┌─────────────────────────────────────────┐              │
                │           │ turn/                                   │              │
                │           │   actions/action_dispatcher ─► market   │              │
                │           │   phases/move_followup     ─► market   │              │
                │           │   loop/init  ─► purchase.core           │              │
                │           └─────────────────────────────────────────┘              │
                │                                                                    │
                │           ┌─────────────────────────────────────────┐              │
                │           │ host / app  (装配)                      │              │
                │           │   app/host_install ─► paid_purchase_port│              │
                │           │   host/paid_purchase_gateway            │              │
                │           │     (lazy ─► market.query.context)      │              │
                │           └─────────────────────────────────────────┘              │
                │                                                                    │
                ▼                                                                    │
   ┌───────────────────────────────────────────────────────────────────┐             │
   │  state  (跨层 — 不属于任何一层，被多方读写)                       │◄────────────┘
   │    dirty_tracker.lua    ← market 域（★ a54beb8 修复点）           │
   │    runtime_state / ui_sync_shared                                 │
   └───────────────────────────────────────────────────────────────────┘
                ▲
                │ 通过 dirty.market 标志位单向触达 UI
                │
   ┌────────────┴──────────────────────────────────────────────────────┐
   │  ui/  (UI 七层下的多个子模块)                                     │
   │                                                                   │
   │  schema/                                                          │
   │    market.lua (canvas nodes)                                      │
   │    market_layout.lua (像素布局)                                   │
   │       ▲                                                           │
   │       │                                                           │
   │  render/market/                                                   │
   │    init.lua ─► slots, controls, schema/market_layout              │
   │    slots.lua ─► items_cfg, market_catalog, vehicle_catalog        │
   │    controls.lua ─► schema/market_layout                           │
   │       ▲                                                           │
   │       │                                                           │
   │  coord/                                                           │
   │    market.lua ─► render/market, canvas_coordinator                │
   │    canvas_coordinator ─► schema/market                            │
   │    modal.lua ★ ─► coord/market                                    │
   │       ▲                                                           │
   │       │                                                           │
   │  ports/                                                           │
   │    ui_sync/model.lua ★ — _should_open_choice_modal 看 dirty.market│
   │    view_command.lua ─► coord/market                               │
   │                                                                   │
   │  input/                                                           │
   │    canvas_route/market.lua ─► schema/market                       │
   │    lock.lua ─► schema/market_layout                               │
   └───────────────────────────────────────────────────────────────────┘
```

## 关键流：黑市点击 → server 改写 → UI 刷新（a54beb8 修复链路）

```
  user click (翻页/切 tab)
        │
        ▼
  ui/input/canvas_route/market  ──► 发出 intent
        │
        ▼
  rules/choice_handlers/market  ──► market.choice.outcome
                                         │
                                         ▼
                                  market.choice.session._apply_spec
                                         │ ★ 原地改写 pending_choice
                                         │
                                         ├─► state.dirty_tracker.mark("market")
                                         │
                                         └─► state.dirty.market = true
                                                       │
                                                       ▼
  turn loop consume_dirty  ──► ui/ports/ui_sync/model.refresh_from_dirty
                                          │
                                          │ dirty.market == true ?
                                          │   ├─ true  → 强制返回 true ★
                                          │   └─ false → should_reconcile（保留 78acda7 防闪屏）
                                          ▼
                                  ui/coord/modal.open_choice_modal
                                          │
                                          ▼
                                  ui/coord/market.show / refresh
                                          │
                                          ▼
                                  ui/render/market.refresh_market
                                          │
                                          ▼
                                  canvas 更新 → 用户看到新 options
```

## 边界要点

- **rules/market 的对外门面只有 3 个**：`market.init`（聚合）、`market.purchase.core`（下单）、`market.paid_purchase_port`（付费端口）。其他文件都是内部实现。
- **唯一的 server→UI 通道是 dirty 域**：`rules/market` 不直接 require 任何 `ui/`；耦合点全在 `state.dirty_tracker` 这一处共享状态。
- **ui/render/market 不 require rules/market**：它读的是 `runtime_state` 与 `config/content/*`（已被 server 写好的快照）。这是 a54beb8 没破坏的清洁架构边界。
- **modal.lua + ui_sync/model.lua 是"是否重开 modal"的双闸门**：前者用 choice.id 去重（`_should_skip_reopen`），后者用 dirty 强制刷新（`_should_open_choice_modal`）。两者协作才让"原地改写 pending_choice"也能触发重渲。

## 关联文档

- [plan.md](../../plan.md) — pending_choice 原地改写审计计划
- [layer-model.md](layer-model.md) — 七层 + foundation 整体模型
- [boundaries.md](boundaries.md) — 跨层边界总规
- [subsystems.md](subsystems.md) — 子系统归属表
