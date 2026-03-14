# 分层模型

```
ui -> turn -> (player | computer) -> rules -> (state | config)
```

`entry` 与 `host` 是支撑层：`entry` 负责装配与启动，`host` 负责 Eggy 宿主接入；它们不拥有玩法规则。

## 组件映射

| 组件 | 目录 |
|------|------|
| entry | `src/entry/` |
| host | `src/host/eggy/` |
| ui | `src/ui/` |
| turn | `src/turn/` |
| player | `src/player/` |
| computer | `src/computer/` |
| rules | `src/rules/` |
| state | `src/state/` |
| config | `src/config/` |
| shared core | `src/core/` |

## 强制边界

| 边界 | 规则含义 |
|------|----------|
| `ui` ↛ `player/computer/rules` | UI 只能经 `turn`、`state`、`config`、`host` 协作 |
| `turn` ↛ `ui` | turn flow 不直接读写 UI 实现 |
| `player/computer` ↛ `turn/ui/host/entry` | 玩家与 AI 只面向内层 |
| `rules` ↛ `turn/ui/player/computer/host/entry` | rules 保持玩法内核位置 |
| `state/config` ↛ 外层 | 状态与配置不回流依赖玩法编排或 UI |
| `host` ↛ gameplay chain | 宿主实现不反向拥有玩法逻辑 |

## Port 注入

- `src/core/ports/`：宿主/运行时广义契约
- `src/rules/ports/`：gameplay 共享 contract
- `src/turn/output/`：turn output/runtime adapter

## 读图方式

从功能定位时，优先按下面顺序找代码：

```
entry -> host -> ui -> turn -> player/computer -> rules -> state/config
```
