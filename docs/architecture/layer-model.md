# 分层模型

```
app -> infrastructure -> presentation -> turn -> (state | computer) -> rules -> (state | config)
```

当前 viewer 根语义已经切到：`app / infrastructure / presentation / turn / ai / rules / state / player / core / config`。
其中 `app` 只负责装配与启动，`infrastructure` 负责 Eggy 宿主接入；它们都不拥有玩法规则。

## 组件映射

| 组件 | 当前目录语义 |
|------|--------------|
| app | `src/app/` |
| infrastructure | `src/host/` |
| presentation | `src/ui/` + `src/ui/ports/` |
| turn | `src/turn/` |
| state | `src/state/` |
| player | `src/player/` |
| ai | `src/computer/` |
| rules | `src/rules/` |
| config | `src/config/` |
| core | `src/core/` |

## 强制边界

| 边界 | 规则含义 |
|------|----------|
| `presentation` ↛ `turn/computer/rules` | 表现层不能直接拥有回合、AI、规则实现 |
| `turn` ↛ `presentation` | 回合编排不直接读写 UI 实现 |
| `state/player/ai` ↛ `turn/presentation/infrastructure/app` | 状态、玩家与 AI 只面向内层能力 |
| `rules` ↛ `turn/presentation/ai/infrastructure/app` | 玩法规则保持内核位置 |
| `state/config` ↛ 外层 wiring | 状态与配置不回流依赖启动/宿主/UI |
| `infrastructure` ↛ gameplay chain | 宿主实现不反向拥有玩法逻辑 |

## Port 注入

- `src/core/ports/`：宿主/运行时广义契约
- `src/rules/ports/`：gameplay 共享 contract
- `src/ui/ports/`：presentation runtime grouped ports / adapter 真源
- `src/turn/output/`：turn 输出与 runtime adapter

## 读图方式

从功能定位时，优先按下面顺序找代码：

```
app -> host -> ui -> turn -> state/computer -> rules -> state/config
```

## 迁移备注

- `main.lua` 现在从 `src.app` 启动。
- `src/ui`、`src/turn`、`src/rules`、`src/state`、`src/player`、`src/host` 仍保留原物理目录，但在 arch_view 中已经按新组件语义投影。
- `src/ui/` 承接入口里的 UI/runtime wiring，其中 `src/ui/ports/` 是 grouped ports / adapter 真源。
- `src/ui/` 承接展示侧共享 seam（`state` / `landing_visual_hold` / `host_bridge`）。
- `src/host/global_aliases.lua` 是显式 seam exception，而不是业务兼容别名层。
