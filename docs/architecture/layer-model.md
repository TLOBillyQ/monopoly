---
kind: contract
status: stable
owner: architecture
last_verified: 2026-05-04
---
# 分层模型

> **See also**：架构治理路线图 → [`governance-roadmap.md`](governance-roadmap.md)（10 → 7 层 + foundation 基座的对齐债务及治理波次）；架构决策 → [`../decisions/0001-seven-layer-with-foundation.md`](../decisions/0001-seven-layer-with-foundation.md)（D1-D7 决策记录）。

## 七层 + Foundation 基座

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

**核心约定：物理目录名 = 逻辑层名 = arch 组件名**。新人读目录树即知层归属，无需查映射表。

`app` 只负责装配与启动；`host` 负责 Eggy 宿主接入；它们都不拥有玩法规则。
`foundation` 是横切的基础设施基座（log/lang/identity/events/ports/coordination），不含玩法语义。

## 组件映射

| 层 / 基座 | 物理目录 |
|----------|---------|
| app | `src/app/` |
| host | `src/host/` |
| ui | `src/ui/` |
| turn | `src/turn/` |
| player | `src/player/` |
| computer | `src/computer/` |
| rules | `src/rules/` |
| state | `src/state/` |
| config | `src/config/` |
| foundation | `src/foundation/` |

## Foundation 子树结构

```
src/foundation/
├── events/        ← monopoly_event 总线（init.lua）
├── ports/         ← 横切端口（runtime_ports / action_anim）
├── log/           ← logger / formatter / utils
├── lang/          ← 语言级工具（number / tables）
├── identity/      ← role_id 标识
└── coordination/  ← 跨层协调（tip_queue）
```

## 强制边界

| 边界 | 规则名 | 含义 |
|------|--------|------|
| `ui` ↛ `player/computer/rules` | `ui_no_player` / `ui_no_computer` / `ui_no_rules` | UI 不能直接拥有玩家、AI、规则实现 |
| `turn` ↛ `ui` | `turn_no_ui` | 回合编排不直接读写 UI 实现 |
| `player/computer` ↛ `turn/ui/host/app` | `player_no_*` / `computer_no_*` | 玩家、AI 只面向内层能力 |
| `rules` ↛ `turn/ui/computer/host/app` | `rules_no_outer` | 玩法规则保持内核位置 |
| `state/config/foundation` ↛ `player/computer/rules/turn/ui/host/app` | `foundation_no_upper` | L7 数据层与基座不回流依赖 |
| `host` ↛ `ui/turn/player/computer` | `host_no_gameplay_chain` | 宿主实现不反向拥有玩法逻辑 |
| `ui.schema` ↛ 其他 ui 子视图与外层 | `ui_schema_pure` | 表现 schema 保持纯净 |

## Port 注入

- `src/foundation/ports/`：宿主/运行时广义契约（runtime_ports / action_anim）
- `src/rules/ports/`：gameplay 共享 contract
- `src/ui/ports/`：UI 运行时分组端口 / adapter 真源
- `src/turn/output/`：turn 输出与 runtime adapter

## UI 内部视图

```
src/ui/
├── input/             用户输入分发
├── view/              数据投影（presenter / role_context）
├── render/            渲染 + render/widgets/
├── coord/             协调器（actor_context / ui_state / ui_runtime / event_state）
├── state/             纯状态容器（runtime / canvas_store / modal_state）
├── ports/             grouped ports / adapter 真源
├── schema/            UI 描述 schema
├── utils/             with_client_role 等
├── visual_hold.lua    顶层 wrapper：bridges effect_track + state.visual_hold
└── host_bridge.lua    顶层：到 host 的桥
```

## State 子树结构

```
src/state/
├── visual_hold/       ← 子目录：init.lua / deferred_dirty / release_scheduler
├── game_state.lua     ← 根状态对象（Game class），mixin 由 src/app/compose_game.lua 安装
├── player_state.lua   ← 占位空表（保留 require 兼容；mixin 由 compose_game 接管）
├── board_state.lua    ← 棋盘 mixin 源
├── turn_state.lua     ← 回合 mixin 源
├── runtime_state.lua  ← UI runtime 状态访问
├── dirty_tracker.lua  ← 脏标志追踪
├── ui_sync_shared.lua ← UI 同步共享数据
├── event_log.lua
├── ui_role_globals.lua
├── vehicle_runtime_source.lua
└── ...
```

## 读图方式

按功能定位时优先按下面顺序找代码：

```
app -> host -> ui -> turn -> state/computer -> rules -> state/config -> foundation
```

## 迁移备注

- `main.lua` 从 `src.app` 启动。
- `src/host/global_aliases.lua` 是显式 host 桥接 seam（exception #1）。
- `state/game_state.lua` 的 mixin（status_ops / balance_ops / deity_ops / vehicle_ops / location_ops / check_victory）由 `src/app/compose_game.lua` 在模块加载时安装到 Game 类——这是 Phase 2 反转 state 逆向依赖的关键支点。
- `src/ui/visual_hold.lua` 是顶层 wrapper，桥接 `src/ui/render/support/effect_track` 与 `src/state/visual_hold` 的 post-release hook。
- 旧路径（`src.core.*`、`src.ui.pres.*`、`src.ui.ctl.*`、`src.ui.wid.*`、`src.ui.stores.*`、`src.state.landing_visual_hold`、`src.state.deferred_dirty`、`src.state.release_scheduler`）全部已迁移；`tools/quality/arch.lua check` 通过。
