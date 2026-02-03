# Monopoly 目录结构说明

本文档描述当前 Monopoly 项目的目录职责与入口结构。

## 入口

- `main.lua`：项目入口，直接加载 `src/app/init.lua`。
- `init.lua`：兼容入口，返回 `src/app/init.lua`。
- `src/app/init.lua`：运行时装配与游戏初始化逻辑。

## 代码结构

- `src/app/`：应用装配层。负责加载运行时全局、UIManager 以及游戏主循环。
- `src/runtime/`：运行时适配层。放置引擎全局封装、常量与 ECA 事件桥接。
- `src/core/`：基础通用组件（状态存储、流程控制、日志）。
- `src/game/`：玩法域子系统。
  - `board/`：棋盘与地块对象。
  - `player/`：玩家与背包。
  - `turn/`：回合驱动与掷骰阶段。
  - `movement/`：移动与路径逻辑。
  - `land/`：地块与落地结算。
  - `item/`：道具系统。
  - `choice/`：选择/提示交互与处理器。
  - `chance/`：机会卡与抽取逻辑。
  - `effect/`：效果管线与执行器。
  - `market/`：黑市与购买。
  - `game/`：游戏生命周期与装配（Game/State/胜利/破产等）。
- `src/ui/`：界面与表现层逻辑。

## 第三方与模板库

- `vendor/third_party/`：模板遗留库与通用工具（UIManager、Behavior、NavMesh、Utils、ClassUtils、Bincore）。

## 配置与数据

- `Config/`：玩法配置与导表产物（含 `Config/Generated`）。
- `Data/`：UI 节点与资源表。
