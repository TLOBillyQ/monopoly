# 七层架构对齐 + Core 拆分 + UI 重组

## Context

将十层架构整治为七层 + 基础设施基座（foundation substrate），并完成 core 的彻底拆解、ui/ 的内部重组、landing_visual_hold 的改名打包。本计划取代 `docs/architecture/governance_roadmap.md` 中关于 D2 路径下文件迁移的若干决策（详见末尾"取代关系"）。

---

## 决策落槽（前置已拍板）

### D1. 架构模型：七层 + foundation 基座

```
L1  app                    → src/app/
L2  host                   → src/host/
L3  ui                     → src/ui/
L4  turn                   → src/turn/
L5  player | computer      → src/player/ | src/computer/
L6  rules                  → src/rules/
L7  state | config         → src/state/ | src/config/
─────
foundation（substrate）    → src/foundation/   ← 不计入七层，所有层共同的基础设施
```

### D2. 命名对齐：物理目录名 = 逻辑层名 = arch 组件名

| 组件名变更 | 旧 | 新 |
|----------|---|---|
| arch component | `flow` | `turn` |
| arch component | `runtime`（合并） | 拆为 `player` + `state` |
| arch component | `ai` | `computer` |
| arch component | `systems` | `rules` |
| arch component | `core` | `foundation` |
| layer label | `infrastructure` | `host` |
| layer label | `presentation` | `ui` |

### D3. Core 拆分映射（19 个文件 → 6 个去向）

| 模块 | 目标 | 路径 |
|------|------|------|
| `logger.lua`, `log_formatter.lua`, `logger_utils.lua` | foundation | `src/foundation/log/` |
| `number.lua`, `tables.lua` | foundation | `src/foundation/lang/` |
| `role_id.lua` | foundation | `src/foundation/identity/` |
| `events/init.lua` | foundation | `src/foundation/events/` |
| `ports/runtime_ports.lua`, `ports/action_anim.lua` | foundation | `src/foundation/ports/` |
| `choice/contract.lua`, `choice/route_policy.lua` | config (L7) | `src/config/choice/` |
| `choice/registry.lua`, `choice/item_preconsume_policy.lua`, `choice/use_skip_choice.lua` | rules (L6) | `src/rules/choice/` |
| `choice/resolver.lua` | turn (L4) | `src/turn/choice/` |
| `utils/dirty_tracker.lua`, `ui_sync_shared.lua` | state (L7) | `src/state/` |
| `utils/with_client_role.lua`, `utils/tip_queue.lua` | ui (L3) | `src/ui/utils/` |

### D4. ui/ 内部重组

```
src/ui/
├── input/                   保持
├── view/                    重命名 pres/，role_context.lua 在此
├── render/                  保持，吸收 wid/ → render/widgets/
├── coord/                   重命名 ctl/，actor_context.lua 在此
├── state/                   合并 stores/ + 顶层 state.lua + ctl/ui_state + ctl/ui_runtime + 顶层 landing_visual_hold.lua
├── ports/                   保持
├── schema/                  保持
├── utils/                   新增，接收 with_client_role + tip_queue
└── host_bridge.lua          保持顶层
```

`actor_context.lua` 与 `role_context.lua` **保持不合并**（职责不同：前者是 host 桥接查询，后者是 view 数据投影）。术语统一（role/actor）作为后续 follow-up。

### D5. landing_visual_hold 改名打包

- 改名：去掉 "landing"，提议 `visual_hold` 或 `ui_transaction`（待 Phase 6 拍板）
- 留 state（L7），打包为子目录：

```
src/state/
├── visual_hold/            ← 新子目录（命名待定）
│   ├── init.lua            ← 前 landing_visual_hold.lua
│   ├── deferred_dirty.lua  ← 从 state/ 顶层移入
│   └── release_scheduler.lua  ← 从 state/ 顶层移入
├── event_log.lua           留 state/ 顶层（turn 多处使用）
├── runtime_state.lua       留 state/ 顶层（全局通用）
└── ...
```

`src/ui/landing_visual_hold.lua`（4 行 wrapper）改名跟随，移入 `src/ui/state/visual_hold.lua`。

### D6. State 逆向依赖修复

| 文件 | 当前问题 | 修复 |
|------|---------|------|
| `src/state/game_state.lua:4,21` | state(L7) → rules(L6) | mixin 安装移至 `src/app/compose_game.lua` |
| `src/state/player_state.lua:1-5` | state(L7) → player(L5) | mixin 安装移至 `src/app/compose_game.lua` |

### D7. Exception 处置

| # | 名称 | 处置 |
|---|------|------|
| 1 | `host_bridge_exception` | 保留 |
| 2 | `infrastructure_runtime_bridges` | 保留 |
| 3 | `runtime_state_bridges` | 重命名为 `gameplay_state_bridges` |
| 4 | `systems_choice_bridges` | **删除**（幻影：匹配零文件） |
| 5 | `state_access` | **删除**（state ↔ foundation 现在是平级关系） |
| 6 | `player_state_bridge` | **删除**（player_state 留 state，不再归类到 runtime） |

新增 `foundation_no_upper` 规则：`state/config/foundation` 不可依赖任何上层。

---

## 实施阶段（按优先级）

### 优先级总览

| Pri | Phase | 内容 | 阻塞下游 |
|-----|-------|------|---------|
| P0 | 0 | 决策记录（ADR） | 全部下游 |
| P0 | 1 | 删除幻影 exception #4 | 无 |
| P1 | 2 | 反转 state 逆向依赖 | Phase 7（runtime 拆分）|
| P1 | 3 | Core 拆分（保留 src/core/ 名）| Phase 4 |
| P1 | 4 | `src/core/` → `src/foundation/` 重命名 | Phase 7（component 重命名） |
| P2 | 5 | ui/ 内部重组 | Phase 7（路径匹配规则）|
| P2 | 6 | landing_visual_hold 改名 + 打包 | Phase 7 |
| P1 | 7 | arch config 重写 | Phase 8 |
| P3 | 8 | 文档更新 + 反向链接 | 无 |

P0 = 阻塞性前置；P1 = 核心代码变更；P2 = 整理优化；P3 = 收尾。

---

### Phase 0 — 决策记录（P0）

**变更**：
- 新增 `docs/architecture/adr/0001-seven-layer-with-foundation.md`，固化 D1-D7 决策

**验证**：人工 review；后续阶段执行人据此对照

---

### Phase 1 — 删除幻影 exception #4（P0，零风险）

**变更**：
- `tools/quality/arch/config.json` 删除 `systems_choice_bridges`（行 41-46）

**验证**：`lua tools/quality/arch.lua check`

**理由**：匹配模式 `^src%.player%.choices%..+` 对应零文件，纯清理。先做以减小后续混淆。

---

### Phase 2 — 反转 state 逆向依赖（P1）

**变更**：

`src/state/game_state.lua`：
- 删除行 4：`local game_victory = require("src.rules.endgame.game_victory")`
- 删除行 21：`game.check_victory = game_victory.check_victory`

`src/state/player_state.lua`：
- 删除行 1-5：5 个 `state_ops` require
- 删除行 8-20：groups 定义和 mixin 循环
- 文件简化为返回空表（保留导出位用于 game_state mixin 安装），或考虑直接删除并由 compose_game 接管

`src/app/compose_game.lua`：
- 接收 `game_victory` require + `game.check_victory = ...` 安装
- 接收 5 个 `state_ops` require + mixin 循环安装
- 安装时机：`composition_root.assemble()` 中，instance 创建前完成 class 级 mixin

**验证**：
```bash
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

**风险**：mixin 安装时机错误导致 player 实例缺方法。
**缓解**：保持 class 级安装语义不变；测试覆盖完整。

---

### Phase 3 — Core 拆分（P1，保留 src/core/ 物理名）

按文件影响面从小到大分批，每批可独立验证。

#### Phase 3a — UI 专属（最小批，~12 个 require 变更）

| 迁移 | 影响文件 |
|------|---------|
| `core/utils/with_client_role.lua` → `src/ui/utils/with_client_role.lua` | 4 个 ui 消费者 |
| `core/utils/tip_queue.lua` → `src/ui/utils/tip_queue.lua` | 5 个消费者（含 logger.lua 内部，需先理顺） |

**注意**：`tip_queue` 被 `core/utils/logger.lua` 引用。logger 仍在 foundation，但需要 tip_queue 能从 ui 取——这违反层级（foundation 不能依赖 ui）。**必须先处理这个循环**：

- 选项 A：tip_queue 留在 foundation/utils/（推翻"UI 层"决定）
- 选项 B：拆分 logger，让其不依赖 tip_queue（tip_queue 是真正的 UI 提示队列）
- 选项 C：tip_queue 移到 ui，但 logger 通过 DI 接收 tip_queue 实例（在 compose_game 注入）

**推荐 C**：保持 tip_queue 的 UI 属性，logger 改为可选注入。需要在 Phase 3a 执行前确认是否可行（先读 logger.lua 看 tip_queue 用法）。

#### Phase 3b — 状态相关（小批，~6 个 require 变更）

| 迁移 | 影响文件 |
|------|---------|
| `core/utils/dirty_tracker.lua` → `src/state/dirty_tracker.lua` | 3 个消费者 |
| `core/ui_sync_shared.lua` → `src/state/ui_sync_shared.lua` | 2 个消费者 |

#### Phase 3c — Choice 拆分（中批，~25 个 require 变更）

| 迁移 | 目标 |
|------|------|
| `core/choice/contract.lua` | `src/config/choice/contract.lua` |
| `core/choice/route_policy.lua` | `src/config/choice/route_policy.lua` |
| `core/choice/registry.lua` | `src/rules/choice/registry.lua` |
| `core/choice/item_preconsume_policy.lua` | `src/rules/choice/item_preconsume_policy.lua` |
| `core/choice/use_skip_choice.lua` | `src/rules/choice/use_skip_choice.lua` |
| `core/choice/resolver.lua` | `src/turn/choice/resolver.lua` |

`resolver` 内部依赖 `item_preconsume_policy`（→ rules）→ turn(L4) 依赖 rules(L6)，合法 ✓
`contract` 内部依赖 `number`（→ foundation）→ config(L7) 依赖 foundation，合法 ✓

#### Phase 3d — 验证 src/core/ 剩余内容

完成 3a-3c 后 `src/core/` 应只剩：
```
src/core/
├── events/init.lua
├── ports/{runtime_ports.lua, action_anim.lua}
└── utils/{logger.lua, log_formatter.lua, logger_utils.lua, number.lua, tables.lua, role_id.lua}
```

进入 Phase 4 整体改名。

**验证（每子阶段）**：
```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 4 — `src/core/` → `src/foundation/` 重命名（P1）

**变更**：

子目录调整 + 改名（一次原子操作）：

```
src/core/                          src/foundation/
├── events/init.lua          →     ├── events/init.lua
├── ports/                   →     ├── ports/
│   ├── runtime_ports.lua    →     │   ├── runtime_ports.lua
│   └── action_anim.lua      →     │   └── action_anim.lua
└── utils/                   →     ├── log/
    ├── logger.lua           →     │   ├── logger.lua
    ├── log_formatter.lua    →     │   ├── formatter.lua
    ├── logger_utils.lua     →     │   └── utils.lua
    ├── number.lua           →     ├── lang/
    ├── tables.lua           →     │   ├── number.lua
    └── role_id.lua          →     │   └── tables.lua
                                   └── identity/
                                       └── role_id.lua
```

**操作**：
1. `git mv src/core/ src/foundation/`
2. 内部重组（log/、lang/、identity/）
3. 全局批量替换 require 路径（`src.core.*` → `src.foundation.*` + 子目录调整）
4. 在 `.git-blame-ignore-revs` 中添加该 commit hash

**估算**：~150+ 个 require 路径变更（logger 54 + number 55 + role_id 27 + events 17 + runtime_ports 43 + action_anim 12，去重后）

**验证**：
```bash
grep -rn "src\.core\." src/ tests/ tools/ --include='*.lua'   # 应为 0
lua tools/quality/lint.lua
busted --run behavior
busted --run contract
busted --run guards
lua tools/quality/arch.lua check
```

**风险**：动态拼接 require（`require("src.core." .. name)`）漏改。
**缓解**：执行前 `grep -rn 'require.*"src\.core\.\?\.\.\?'` 扫描动态路径；测试覆盖。

---

### Phase 5 — ui/ 内部重组（P2）

按依赖顺序分批：

#### Phase 5a — pres/ → view/

`git mv src/ui/pres src/ui/view`，全局替换 `src.ui.pres` → `src.ui.view`。

#### Phase 5b — ctl/ 状态文件抽离

新增 `src/ui/state/`，移入：
- `src/ui/ctl/ui_state.lua` → `src/ui/state/ui_state.lua`
- `src/ui/ctl/ui_runtime.lua` → `src/ui/state/ui_runtime.lua`
- `src/ui/ctl/event_state.lua` → `src/ui/state/event_state.lua`（如属状态容器）
- `src/ui/state.lua`（顶层） → `src/ui/state/runtime.lua`
- `src/ui/stores/canvas_store.lua` → `src/ui/state/canvas_store.lua`
- `src/ui/stores/modal_state.lua` → `src/ui/state/modal_state.lua`

删除 `src/ui/stores/` 空目录。

#### Phase 5c — ctl/ → coord/

`git mv src/ui/ctl src/ui/coord`，全局替换 `src.ui.ctl` → `src.ui.coord`。

#### Phase 5d — wid/ → render/widgets/

`git mv src/ui/wid src/ui/render/widgets`，全局替换 `src.ui.wid` → `src.ui.render.widgets`。

#### Phase 5e — utils/ 落位

确认 `src/ui/utils/with_client_role.lua` + `src/ui/utils/tip_queue.lua` 已就位（Phase 3a 已做）。

#### Phase 5f — 顶层 landing_visual_hold.lua 移入

`src/ui/landing_visual_hold.lua` → `src/ui/state/visual_hold.lua`（命名跟 Phase 6 拍板结果）。

**验证（每子阶段）**：
```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 6 — landing_visual_hold 改名 + 打包（P2）

**Phase 6a — 拍板新名字**

候选：`visual_hold` / `ui_transaction` / `animation_hold` / `ui_freeze`

执行前确认：选哪个？（不在本计划内代填，需要执行人或人工选）

**Phase 6b — 打包子目录**

```
src/state/landing_visual_hold.lua        → src/state/{NEW_NAME}/init.lua
src/state/deferred_dirty.lua             → src/state/{NEW_NAME}/deferred_dirty.lua
src/state/release_scheduler.lua          → src/state/{NEW_NAME}/release_scheduler.lua
```

`event_log.lua`、`runtime_state.lua` 留 `src/state/` 顶层（被多处使用，非 hold 专属）。

**Phase 6c — UI wrapper 跟随**

`src/ui/landing_visual_hold.lua` → `src/ui/state/{NEW_NAME}.lua`

**Phase 6d — 全局 require 替换**

涉及消费者数量需扫描后估算。预计 ~15-20 处。

**验证**：
```bash
grep -rn 'landing_visual_hold' src/ tests/ tools/ --include='*.lua'   # 应只剩文档级引用
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

---

### Phase 7 — arch config 重写（P1）

执行顺序很重要。

#### Phase 7a — Component 重命名（无逻辑变更，纯字符串）

`tools/quality/arch/config.json`：
- `flow` → `turn`
- `ai` → `computer`
- `systems` → `rules`
- `core` → `foundation`（match pattern 同步改 `^src%.foundation%..+`）

#### Phase 7b — Component 拆分

- 删除 `runtime` component
- 新增 `player` component：match `^src%.player$`, `^src%.player%..+`
- 新增 `state` component：match `^src%.state$`, `^src%.state%..+`

#### Phase 7c — 替换 forbidden 规则

删除：
- `runtime_state_no_outer`
- `config_no_outer_layers`
- `runtime_player_*` 系列重命名为 `player_*`

新增：
```json
{
  "name": "foundation_no_upper",
  "from": ["^src%.state%..+", "^src%.config%..+", "^src%.foundation%..+"],
  "to": ["^src%.player%..+", "^src%.computer%..+", "^src%.rules%..+",
          "^src%.turn%..+", "^src%.ui%..+", "^src%.host%..+", "^src%.app%..+"],
  "description": "L7 foundation (state/config/foundation) must not depend on any upper layer"
}
```

注意：`state ↔ config ↔ foundation` 之间无禁止规则（L7 平级 + 基座，可互相引用）。

#### Phase 7d — Exception 处置

| # | 名称 | 操作 |
|---|------|------|
| 3 | `runtime_state_bridges` | 重命名 `gameplay_state_bridges` |
| 5 | `state_access` | 删除 |
| 6 | `player_state_bridge` | 删除 |

#### Phase 7e — 注释格式确认

确认 `arch.lua` 的 JSON 解析器是否支持 `//` 注释（governance_roadmap §5.2 OQ-1）。若不支持，保留 exception 时使用 `_governance` 字段方案。

**验证**：
```bash
lua tools/quality/arch.lua check
busted --run contract
busted --run behavior
busted --run guards
busted --run tooling
```

---

### Phase 8 — 文档更新（P3）

#### Phase 8a — `docs/architecture/layer-model.md`

完全重写：
- 七层 + foundation 基座的描述
- 物理目录 = 层名 = 组件名 的统一映射
- 各层职责与禁止行为
- foundation 子目录结构（log/lang/identity/events/ports）

#### Phase 8b — `docs/architecture/boundaries.md`

更新边界规则描述，对齐新的 forbidden 规则。

#### Phase 8c — `docs/architecture/governance_roadmap.md`

顶部追加：

```markdown
> **Status**: 部分决策已被 `docs/architecture/adr/0001-seven-layer-with-foundation.md` 取代。
> 取代项：3.2.1 / 3.2.2 / 3.2.3 / 3.3 / 3.4（state 文件去向）；W4（state 迁移大半不再需要）；
> Chapter 5 exception 处置（按七层方案重做）。
> 仍有效：D2 决策（保留物理名，但 host/ui/computer 现在也作为层名）；W1 决策结构。
```

#### Phase 8d — 反向链接

在以下文件顶部添加 "See also"：
- `docs/architecture/layer-model.md`
- `docs/architecture/boundaries.md`
- `docs/architecture/health_signals.md`
- `AGENTS.md`（"按任务找文档"表新增一行）

#### Phase 8e — `CLAUDE.md` 更新

`src/` 禁用 `tonumber` / `type == "number"` 的规则改为：用 `NumberUtils`（`src.foundation.lang.number`）。其他 require 路径示例同步更新。

---

## 风险登记

| ID | 风险 | 影响 Phase | 缓解 |
|----|------|-----------|------|
| R1 | tip_queue 在 logger 内的循环依赖 | 3a | 执行前读 logger.lua 确认；选 DI 注入方案 |
| R2 | 动态 require 拼接路径未覆盖 | 4, 5, 6 | 每阶段前 grep 扫描动态路径 |
| R3 | mixin 安装时机错误导致 class 缺方法 | 2 | behavior + guards 测试覆盖 |
| R4 | git blame 链断裂 | 4 | `.git-blame-ignore-revs` 维护 |
| R5 | arch config 解析器不支持 `//` 注释 | 7e | OQ-1 在 Phase 0 前确认 |
| R6 | foundation_no_upper 规则触发新违规 | 7c | Phase 7c 前 arch check 确认无残余逆向依赖 |
| R7 | state 子目录化后 require 路径漏改 | 6b | Phase 6 后全文 grep 验证 |

---

## 完成判据

| 项 | 标准 |
|----|------|
| `src/core/` 不存在 | `[ ! -d src/core ]` |
| `src/foundation/` 存在并按 D3 + Phase 4 子目录组织 | `ls src/foundation/` |
| `src/ui/` 按 D4 重组完成 | `ls src/ui/` 显示 view/coord/render/state/utils 等 |
| state 无逆向依赖 | `grep -rn 'src\.player\|src\.rules\|src\.turn\|src\.ui\|src\.host\|src\.app' src/state/ --include='*.lua'` 应为 0 |
| arch.lua 无新增违规 | `lua tools/quality/arch.lua check` 通过 |
| Exception 数量 | 从 6 降至 3（host_bridge / infrastructure_runtime_bridges / gameplay_state_bridges） |
| `/verify-full` 全绿 | lint + behavior + contract + guards + tooling + arch 全部通过 |
| 文档反向链接 | 4 个文件含 governance/ADR 引用 |

---

## 涉及文件清单

| Phase | 代码文件 | 文档/配置 | require 变更估算 |
|-------|---------|----------|----------------|
| 0 | — | 1 个 ADR 新建 | 0 |
| 1 | — | `arch/config.json` | 0 |
| 2 | 3 个（game_state, player_state, compose_game） | — | 0 |
| 3 | 19 个 core 文件迁移 | — | ~50 |
| 4 | 重命名 src/core/ → src/foundation/ + 子目录调整 | — | ~150 |
| 5 | ui/ 30+ 个文件位置变更 | — | ~50 |
| 6 | 3-4 个 state 文件 + 1 个 ui wrapper | — | ~15-20 |
| 7 | — | `arch/config.json` 大改 | 0 |
| 8 | — | `layer-model.md`, `boundaries.md`, `governance_roadmap.md`, `AGENTS.md`, `CLAUDE.md`, 3 处反向链接 | 0 |

总计代码文件迁移/修改约 60 个，require 路径变更约 250+ 处，文档变更 7 处。

---

## 与 governance_roadmap.md 的取代关系

| roadmap 决策项 | 本计划处置 |
|--------------|----------|
| 3.1 D2 路径（保留物理名） | 仍有效（host/ui/computer 现在物理名 = 层名）|
| 3.2.1 game_state 归属 | 留 state，反转 rules 依赖 |
| 3.2.2 runtime_state 处置 | 留 state（七层下 state 是 L7 数据层） |
| 3.2.3 UI 三件套归属 | landing_visual_hold + deferred_dirty + release_scheduler 打包成 state/{visual_hold}/ 子目录 |
| 3.3 Component 拆分 | **必须执行**（runtime → player + state） |
| 3.4 board_state 归属 | 留 state（七层下 state 即数据层，无需新增 board/） |
| W3 拆分 component | 本计划 Phase 7b |
| W4 state/ 文件迁移 | 大半作废；只保留 mixin 反转（Phase 2） + visual_hold 打包（Phase 6） |
| W5 物理目录改名 | 不执行（D2 决议）；本计划 Phase 4 仅改 core → foundation |
| W6 Exception 清零 | 本计划 Phase 7d |
| W7 反向链接 | 本计划 Phase 8d |
