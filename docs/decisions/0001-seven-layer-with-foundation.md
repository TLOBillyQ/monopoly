---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-04
---
# ADR 0001 — 七层架构 + Foundation 基座

**Status**: Accepted (2026-04-30)
**Supersedes (partial)**: early architecture governance notes
**Driver**: architecture alignment decision set D1-D7

> **Note**：本 ADR 固化已拍板的 D1-D7 决策。任何修改需另开 ADR 取代。

---

## 上下文（Why）

早期架构治理笔记在 D2（保留物理目录名）之外仍留有大量歧义点：`src/state/` 11 个文件如何拆分、`runtime` component 是否拆分、是否新建 `src/board/`、6 条 exception 如何处置。

执行人在落地前必须把这些组合决策一次性钉死，否则每个 phase 都会回到决策表反复对照。本 ADR 把决策变更写入正式 ADR 序列，让后续实施进入"按表执行"状态。

---

## 决策（What）

### D1 — 架构模型：七层 + foundation 基座

```
L1  app                    → src/app/
L2  host                   → src/host/
L3  ui                     → src/ui/
L4  turn                   → src/turn/
L5  player | computer      → src/player/ | src/computer/
L6  rules                  → src/rules/
L7  state | config         → src/state/ | src/config/
─────
foundation（substrate）    → src/foundation/   ← 不计入七层；任何层都可依赖；不可依赖任何上层
```

**说明**：foundation 是横切的"基础设施基座"（substrate），不是层。它放编程语言级别的工具（log/lang/identity/events/ports），不含玩法语义。

### D2 — 命名对齐：物理目录名 = 逻辑层名 = arch 组件名

| 维度 | 旧 | 新 |
|------|---|---|
| arch component | `flow` | `turn` |
| arch component | `runtime`（合并） | 拆为 `player` + `state` |
| arch component | `ai` | `computer` |
| arch component | `systems` | `rules` |
| arch component | `core` | `foundation` |
| layer label | `infrastructure` | `host` |
| layer label | `presentation` | `ui` |

**说明**：governance_roadmap §3.1 选 D2 时仅承诺保留物理名，但允许 layer 与 component 名继续偏离。本 ADR 进一步收紧为"三方一致"：物理名 = 层名 = 组件名。代价是 arch component 重命名（D2 §3.3 选 A 拆分），收益是新人无需查映射表。

### D3 — Core 拆分映射（19 个文件 → 6 个去向）

| 模块 | 目标 | 路径 |
|------|------|------|
| `log.lua` (merged: logger + formatter + utils) | foundation | `src/foundation/log.lua` |
| `number.lua`, `tables.lua` | foundation | `src/foundation/number.lua`, `src/foundation/tables.lua` |
| `identity.lua` | foundation | `src/foundation/identity.lua` |
| `events.lua` | foundation | `src/foundation/events.lua` |
| `tips.lua` (was tip_queue) | foundation | `src/foundation/tips.lua` |
| `ports/runtime_ports.lua`, `ports/action_anim.lua` | foundation | `src/foundation/ports/` |
| `choice/contract.lua`, `choice/route_policy.lua` | config (L7) | `src/config/choice/` |
| `choice/registry.lua`, `choice/item_preconsume_policy.lua`, `choice/resolver.lua` | rules (L6) | `src/rules/choice/` |
| `choice/use_skip_choice.lua` | rules (L6) | `src/rules/choice_specs/` |
| `choice_handler_factory.lua` | rules (L6) | `src/rules/choice_handlers/factory.lua` |
| `utils/dirty_tracker.lua`, `ui_sync_shared.lua` | state (L7) | `src/state/` |
| `utils/with_client_role.lua` | ui (L3) | `src/ui/utils/` |

### D4 — ui/ 内部重组

```
src/ui/
├── input/          保持
├── view/           ← 重命名 pres/，role_context.lua 在此
├── render/         保持，吸收 wid/ → render/widgets/
├── coord/          ← 重命名 ctl/，actor_context.lua 在此
├── state/          合并 stores/ + 顶层 state.lua + ctl/ui_state + ctl/ui_runtime + ctl/event_state + 顶层 landing_visual_hold.lua
├── ports/          保持
├── schema/         保持
├── utils/          新增，接收 with_client_role + tip_queue
└── host_bridge.lua 保持顶层
```

**说明**：`actor_context.lua`（host 桥接查询）与 `role_context.lua`（view 数据投影）保持不合并；术语统一（role/actor）作为后续 follow-up，不在本 ADR 范围。

### D5 — landing_visual_hold 改名打包

- 选定新名：**`visual_hold`**
- 留 state（L7），打包为子目录：

```
src/state/
├── visual_hold/
│   ├── init.lua            ← 前 landing_visual_hold.lua
│   ├── deferred_dirty.lua
│   └── release_scheduler.lua
├── event_log.lua           留顶层（被多处使用）
├── runtime_state.lua       留顶层（全局通用）
└── ...
```

`src/ui/landing_visual_hold.lua`（4 行 wrapper）改名为 **`src/ui/visual_hold.lua`（顶层文件）** 而非 `src/ui/state/visual_hold.lua`：wrapper 同时引用 render（effect_track）与 state（impl），放在 state/ 子视图会引发 ui_state↔ui_render 子视图循环。顶层 ui/ 文件不参与子视图分类，无循环。

### D6 — State 逆向依赖修复

| 文件 | 当前问题 | 修复 |
|------|---------|------|
| `src/state/game_state.lua:4,21` | state(L7) → rules(L6) | mixin 安装移至 `src/app/compose_game.lua` |
| `src/state/player_state.lua:1-5` | state(L7) → player(L5) | mixin 安装移至 `src/app/compose_game.lua` |

### D7 — Exception 处置

| # | 名称 | 处置 |
|---|------|------|
| 1 | `host_bridge_exception` | 保留（加 `_governance` 字段） |
| 2 | `infrastructure_runtime_bridges` | 保留（加 `_governance` 字段） |
| 3 | `runtime_state_bridges` | 重命名为 `gameplay_state_bridges`（加 `_governance` 字段） |
| 4 | `systems_choice_bridges` | **删除**（幻影：匹配零文件） |
| 5 | `state_access` | **删除**（state ↔ foundation 现在是平级关系） |
| 6 | `player_state_bridge` | **删除**（player_state 留 state，不再归类到 runtime） |

新增 `foundation_no_upper` 规则：`state/config/foundation` 不可依赖 `player/computer/rules/turn/ui/host/app` 中任何上层。

由于 `tools/quality/arch.lua` 使用的自定义 JSON 解析器不支持 `//` 行注释，保留 exception 的注释字段必须使用 `_governance: { governance_anchor, retain_reason, review_cadence }` 对象形式（governance_roadmap §5.2 §备选方案）。

---

## 被本 ADR 收敛的旧决策项

| 旧决策项 | 本 ADR 处置 |
|--------------|----------|
| §3.1 D2（保留物理名） | 仍有效，进一步收紧为三方一致 |
| §3.2.1 game_state 归属 | 选 A：留 state，反转 rules 依赖（D6） |
| §3.2.2 runtime_state 处置 | 选 A：留 state（七层下 state 即 L7） |
| §3.2.3 UI 三件套归属 | landing_visual_hold + deferred_dirty + release_scheduler 打包成 `state/visual_hold/`（D5） |
| §3.3 Component 拆分 | 选 A：拆 runtime → player + state |
| §3.4 board_state 归属 | 选 C：维持 src/state/board_state.lua（不新建 src/board/） |
| W3 拆分 component | 已执行 |
| W4 state/ 文件迁移 | 大半作废；只保留 D6 mixin 反转 + D5 visual_hold 打包 |
| W5 物理目录改名 | 不执行 |
| W6 Exception 清零 | 已执行 |
| W7 反向链接 | 已执行 |

---

## 已识别的耦合影响

- **D1 + D2**：拆 component（`runtime` → `player` + `state`）后，所有引用旧 component 名的 exception（#3 #5 #6）必须同步处置。Phase 7 严格按 a→e 顺序执行：先重命名再拆分再处置 exception。
- **D3 + D4**：`tip_queue.lua` 从 foundation 移到 ui 的方案会让 foundation logger 反向引用 ui；最终按 **Option C** 修订：`tip_queue.lua` 留在 foundation，避免 foundation 上行依赖。
- **D5 + D7**：visual_hold 打包后，原 `state_access` exception 中的 `landing_visual_hold/deferred_dirty/release_scheduler` 三条记录全部失效，与 D7 中"删除 #5"协同。
- **D6 + D7**：state→rules 与 state→player 反转完成后，`runtime_state_bridges` 中的 `rules.endgame.game_victory` 与 `player.actions.state_ops.*` 不再是真正的"state 引用上层"，而是"上层引用 state"——方向反转，重命名为 `gameplay_state_bridges` 后保留意义改变（声明 rules + player 对 state 的合法 use-case 引用）。
- **JSON 注释**：D7 保留 exception 的注释格式锁定为 `_governance` 对象，禁止 `//` 注释（解析器不支持）。

---

## 完成判据

完成判据：

| 项 | 标准 |
|----|------|
| `src/core/` 不存在 | `[ ! -d src/core ]` |
| `src/foundation/` 存在并按 D3 + Phase 4 子目录组织 | `ls src/foundation/` |
| `src/ui/` 按 D4 重组完成 | `ls src/ui/` 显示 view/coord/render/state/utils 等 |
| state 无逆向依赖 | `grep -rn 'src\.player\|src\.rules\|src\.turn\|src\.ui\|src\.host\|src\.app' src/state/ --include='*.lua'` 应为 0（除注释/字符串） |
| arch.lua 无新增违规 | `lua tools/quality/arch.lua check` 通过 |
| Exception 数量 | 从 6 降至 3（host_bridge / infrastructure_runtime_bridges / gameplay_state_bridges） |
| `/verify` 全绿 | lint + behavior + contract + guards + tooling + arch 全部通过 |
| 文档反向链接 | layer-model / boundaries / governance_roadmap / AGENTS 4 个文件含 ADR 引用 |

---

## 决策日期 / 作者

**Date**: 2026-04-30
**Author**: user（拍板 D1-D7） + Sisyphus（Phase 3a Option C / Phase 6a `visual_hold` / `_governance` 字段格式 子决策）
