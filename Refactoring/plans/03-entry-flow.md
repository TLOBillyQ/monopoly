# 主入口与回合流程接线

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，`Refactoring` 将拥有清晰的入口与帧循环接线方式，入口只做 wiring，不写规则；游戏回合逻辑通过 `src/game.lua` 与 `src/gameplay/*` 驱动，与 UI/适配层解耦。此状态是后续 UI 管理器、ECA 与动画等待接入的基础。

## Progress

- [x] (2026-01-26 19:10) 创建本 ExecPlan，明确入口与状态机接线目标。
- [ ] (2026-01-26 19:10) 设计 Refactoring 入口文件与初始化顺序。
- [ ] (2026-01-26 19:10) 打通最小运行链路并验证回合流转。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 入口只负责加载模块与初始化，不直接写规则与 UI 逻辑。
  Rationale: 遵循 deepfuture 的入口模式，保持“逻辑/表现/服务”分层。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

现有逻辑入口位于 `src/entry.lua`、`src/bootstrap.lua` 与 `src/game.lua`，参考初始化流程可见 `knowledge/LuaSource_生存割草/main.lua`。`Refactoring` 需要在不依赖仓库根目录运行的前提下完成入口搭建，适配 Eggy 环境时通常需要 `main.lua` 与 `eggy_main.lua` 组合入口。

## Plan of Work

在 `Refactoring/` 中创建/调整入口文件：`Refactoring/main.lua` 作为主入口，按“资源与配置初始化 → 组装游戏 → 适配层接入 → 启动回合”的顺序执行；`Refactoring/eggy_main.lua` 作为 Eggy 环境入口，负责 `require` 主入口或注入必要的环境参数。入口中禁止直接操作 UI 节点或玩法规则，所有规则仍在 `Refactoring/src/gameplay/*` 中执行。若需要帧循环，优先复用 `src/adapters/*` 现有 tick/loop 机制。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 参考生存割草入口组织结构，创建 Refactoring/main.lua
    # 2) 确保 Refactoring/eggy_main.lua 能调用 main.lua
    # 3) 在 main.lua 中初始化 game，并把 game 交给适配层

入口建议依赖文件：

    Refactoring/src/entry.lua
    Refactoring/src/bootstrap.lua
    Refactoring/src/game.lua
    Refactoring/src/adapters/*（选择适配层）

## Validation and Acceptance

执行后可通过最小链路验证：在 `Refactoring/` 下启动入口脚本，能够创建 game 实例且回合管理器可运行一次 `advance_turn()`；日志中应出现“启动蛋仔大富翁”或同等初始化信息，且无 Lua 运行时错误。

## Idempotence and Recovery

入口调整可重复执行；若遇到运行失败，可回退至仅 `require` `Refactoring/src/entry.lua` 的最小入口，再逐步加入适配层与 UI 逻辑。

## Artifacts and Notes

入口初始化顺序示例（缩进展示）：

    1. 读取常量与配置
    2. 初始化 AdapterLayer 与 UI 管理器（占位）
    3. 构造 Game（CompositionRoot）
    4. 把 Game 绑定到适配层
    5. 启动 tick/loop

## Interfaces and Dependencies

必须保留 `Refactoring/src/game.lua` 作为游戏门面，`Refactoring/main.lua` 只调用其构造方法。依赖 `Refactoring/src/adapters/core/adapter_layer.lua` 的 `AdapterLayer.attach` 与 `AdapterLayer.set_game` 作为接线入口，避免引入新的抽象层。

本计划更新记录：

2026-01-26 19:10 创建本计划，原因是重构版本需要先确定入口与回合驱动方式以承接 UI 与适配层。
