# src/ 目录层级与命名审查

规范参照：`docs/architecture/layer-model.md`

## 发现总览

7 个问题，按影响面分 3 档。

### 🔴 高影响（语义混淆）

#### H1: `src/game/core/runtime/` 混装 5 种职责

当前 16 个文件混合了状态模型、AI、领域逻辑、编排和玩家状态操作：

| 职责 | 文件 | 应属组件 |
|------|------|----------|
| 状态容器 | Game.lua, GameState{Players,Tiles,Turn}.lua | state |
| 领域规则 | GameVictory.lua, Bankruptcy.lua, GameFactory.lua | state / shared-mechanics 边界 |
| AI 决策 | Agent.lua | Computer |
| 编排/DI | CompositionRoot.lua, Bootstrap.lua | 辅助层 |
| 玩家状态操作 | player_state/*.lua (6 files) | state |

**方案 — 保留 `core/runtime/` 作为 Game 聚合根，拆出两处：**

```
src/game/core/
├── player/                          # 现有
│   ├── Player.lua
│   ├── Inventory.lua
│   └── state_ops/                   # ← 从 runtime/player_state/ 移入
│       ├── BalanceOps.lua
│       └── …
├── runtime/                         # 收窄为 Game 聚合根 + 组装
│   ├── Game.lua
│   ├── GameState*.lua
│   ├── GameVictory.lua
│   ├── Bankruptcy.lua
│   ├── GameFactory.lua
│   ├── CompositionRoot.lua
│   └── Bootstrap.lua
└── ai/                              # ← 新建，Agent 单独提出
    └── Agent.lua
```

影响：34 处 require 需更新（Agent 8 处、player_state 10 处、其余已在 runtime/ 内部无需改）。

### 🟡 中影响（命名歧义）

#### M1: `src/game/runtime/` vs `src/game/runtime_coroutine/`

- `runtime/`：2 deprecated (TurnEngine, PhaseRegistry) + 2 adapter (AutoPlay, Bankruptcy)
- `runtime_coroutine/`：活跃的协程调度器 (Scheduler, Session, TurnScript…)

两者都叫 "runtime" 但职责完全不同。

**方案：**

```
src/game/turn_engine/                # ← 重命名 runtime/
│   ├── TurnEngine.lua               # (deprecated, frozen)
│   ├── PhaseRegistry.lua            # (deprecated, frozen)
│   ├── AutoPlayPortAdapter.lua
│   └── BankruptcyPortAdapter.lua
src/game/scheduler/                  # ← 重命名 runtime_coroutine/
│   ├── Scheduler.lua
│   └── …
```

影响：~15 处 require。

#### M2: `src/game/flow/ports/` vs `src/game/ports/` — 两个 ports 目录方向相反

- `flow/ports/`：output adapter（flow → 外部）
- `game/ports/`：input resolver（外部 → systems）

**方案：** `flow/ports/` → `flow/output_adapters/`。`game/ports/` 保持不变（已是纯契约层）。

影响：3 处 require。

#### M3: `src/core/` 根级 14 文件无分类

当前 Logger、NumberUtils、ChoiceContract、RuntimeContext facade、ActionAnimPort 等全平铺。

**方案：**

```
src/core/
├── utils/          Logger, NumberUtils, DirtyTracker, RoleId
├── choice/         ChoiceContract, ChoiceRoutePolicy
├── ports/          ActionAnimPort, RuntimePorts, TurnUISyncShared
├── config/         (现有，不动)
├── events/         (现有，不动)
└── runtime_facade/ RuntimeContext, RuntimeEventBridge, RuntimeEditorExports,
                    RuntimeState, UIRoleGlobals
```

影响：91 处 require（最大批量，建议最后做或工具化）。

### 🟢 低影响（命名规范）

#### L1: `src/presentation/api/` 名称不精确

实际是 adapter 层（桥接 game ports 与 presentation runtime），不是 API。

**方案：** → `src/presentation/adapter/`

#### L2: `src/presentation/ui/` 冗余

`presentation/` 下再放 `ui/` 语义重叠。内含 MarketModalRenderer、PopupRenderer 等。

**方案：** → `src/presentation/widgets/` 或合并入 `canvas/`。

#### L3: `ChoiceHandlers/` PascalCase 目录

全仓唯一 PascalCase 目录，其余目录均 snake_case。

**方案：** → `choice_handlers/`

## 优先级排序

| 阶段 | 改动 | require 更新量 | 风险 |
|------|------|---------------|------|
| 1 | L3: ChoiceHandlers → choice_handlers | 4 | 低 |
| 2 | M2: flow/ports → flow/output_adapters | 3 | 低 |
| 3 | H1: player_state 移入 core/player/state_ops + Agent 提至 core/ai | 18 | 中 |
| 4 | M1: runtime → turn_engine, runtime_coroutine → scheduler | 15 | 中 |
| 5 | L1+L2: presentation 子目录重命名 | ~20 | 低（仅 presentation 内部） |
| 6 | M3: src/core 分组 | 91 | 高（全局 require 路径变更） |

阶段 1-4 可独立完成，每步回归测试验证。阶段 6 建议写脚本批量替换。
