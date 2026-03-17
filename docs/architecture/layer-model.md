# 分层模型

```
app -> infrastructure -> presentation -> flow -> (runtime | ai) -> systems -> (runtime | config)
```

当前 viewer 根语义已经切到：`app / infrastructure / presentation / flow / ai / systems / runtime / core / config`。
其中 `app` 只负责装配与启动，`infrastructure` 负责 Eggy 宿主接入；它们都不拥有玩法规则。

## 组件映射

| 组件 | 当前目录语义 |
|------|--------------|
| app | `src/app/bootstrap/` |
| infrastructure | `src/infrastructure/runtime/` + `src/host/` |
| presentation | `src/presentation/runtime/` + `src/ui/` + `src/ui/runtime/` |
| flow | `src/turn/` |
| runtime | `src/state/` + `src/player/` |
| ai | `src/computer/` |
| systems | `src/rules/` |
| config | `src/config/` |
| core | `src/core/` |

## 强制边界

| 边界 | 规则含义 |
|------|----------|
| `presentation` ↛ `runtime(ai/systems)` | 表现层不能直接拥有玩家/AI/规则实现 |
| `flow` ↛ `presentation` | 回合编排不直接读写 UI 实现 |
| `runtime(ai)` ↛ `flow/presentation/infrastructure/app` | 玩家状态与 AI 只面向内层能力 |
| `systems` ↛ `flow/presentation/ai/infrastructure/app` | 玩法规则保持内核位置 |
| `runtime/config` ↛ 外层 wiring | 状态与配置不回流依赖启动/宿主/UI |
| `infrastructure` ↛ gameplay chain | 宿主实现不反向拥有玩法逻辑 |

## Port 注入

- `src/core/ports/`：宿主/运行时广义契约
- `src/rules/ports/`：gameplay 共享 contract
- `src/turn/output/`：flow 输出与 runtime adapter

## 读图方式

从功能定位时，优先按下面顺序找代码：

```
app -> infrastructure -> presentation -> flow -> runtime/ai -> systems -> runtime/config
```

## 迁移备注

- 这一轮只对 `src.entry` 做硬切迁移：`main.lua` 现在从 `src.app.bootstrap` 启动。
- `src/ui`、`src/turn`、`src/rules`、`src/state`、`src/player`、`src/host` 仍保留原物理目录，但在 arch_view 中已经按新组件语义投影。
- `src/presentation/runtime/` 承接入口里的 UI/runtime wiring；`src/ui/runtime/` 承接展示侧共享 seam（`runtime_state` / `landing_visual_hold` / `host_runtime`）；`src/infrastructure/runtime/` 承接运行时全局别名注入。
