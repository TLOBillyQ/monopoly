# 架构与放置原则

本项目采用七层 + foundation：

```text
L1 app
L2 host
L3 ui
L4 turn
L5 player | computer
L6 rules
L7 state | config
   foundation（唯一 substrate）
```

物理目录名、逻辑层名和 arch 组件名保持一致。可执行依赖方向、层内纯度和环检测以 `tools/packages/arch_view/config.json` 及 `test/guards/` 为准；本文只记录静态扫描无法替代的职责判断。

## 放置原则

| 变化原因 | 放置位置 |
|---|---|
| 启动、装配、mixin 安装、跨边界接线 | `src/app` |
| Eggy 宿主对象与 API 适配 | `src/host` |
| 展示状态、输入路由、视图投影与渲染 | `src/ui` |
| 回合推进、等待、意图校验与输出编排 | `src/turn` |
| 玩家状态操作 / 中性电脑策略 | `src/player` / `src/computer` |
| 玩法判定与结算 | `src/rules` |
| 持久局面 / 静态内容与策略配置 | `src/state` / `src/config` |
| 无玩法语义的语言级工具与横切 port | `src/foundation` |

- 一个模块同时因业务规则和宿主/UI 细节而变化时，先拆边界，再放入对应层。
- port 跟随消费者命名：通用运行时契约在 `foundation/ports`，玩法契约在 `rules/ports`，局部回合 override 留在 `turn`。
- `app` 和 `host` 不拥有玩法规则；`foundation` 不持有游戏状态。
- UI schema 只描述节点、画布和布局；状态写入、输入路由与渲染分别留在所属视图。
- UI 内部由 `ui.state` 拥有展示状态与迁移，`ui.coord` 消费其结果并协调视图或宿主副作用；允许 `ui.coord` 依赖 `ui.state`，禁止 `ui.state` 反向依赖 `ui.coord`。
- 已批准的例外和不可由目录推导的边界见 [`decisions.md`](decisions.md)。
