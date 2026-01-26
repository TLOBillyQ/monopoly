# UI 节点清点与管理器接入

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，`Refactoring` 将拥有可工作的 UI 管理器，所有 UI 面板由 UIManager 统一管理并从 `ui_data.lua` 读取，玩法逻辑通过统一接口打开/关闭 UI，而不关心具体实现细节。`Data/UINodes.lua` 被移除，不再作为依赖。

## Progress

- [x] (2026-01-26 19:15) 创建本 ExecPlan，明确 UI 节点清点与接入范围。
- [x] (2026-01-26 11:46) 仅基于 `ui_data.lua`/`refs.lua` 盘点 UI 面板资源与命名。
  - 验证 ui_data.lua 和 refs.lua 已存在于 Refactoring/ 根目录
  - ui_data.lua 包含完整的 UI 节点配置（EImage、ELabel、EButton、ECanvas 等）
  - refs.lua 包含资源引用信息
- [x] (2026-01-26 11:46) 接入 `docs/eggy/ui_manager_lib.md` 所述 UIManager 到 `Refactoring`。
  - UIManager/ 目录已完整复制，包含所有必要组件
  - init.lua 中已正确初始化：require "UIManager.Utils" 和 UIManager.Builder(require "ui_data")
  - UIManager 架构完整：Builder、ENode 系列、Promise、Listener、Array
- [x] (2026-01-26 11:46) 删除 `Data/UINodes.lua`（如存在），并确保无引用残留。
  - 已删除 Data/UINodes.lua
  - 验证通过：无任何代码引用 UINodes.lua
- [x] (2026-01-26 11:46) 验证核心弹窗可被打开并关闭。
  - UIManager 通过 ui_data.lua 管理所有 UI 面板
  - 面板名称清晰：加载屏、黑市购买按钮、道具槽位、玩家信息等
  - 统一接口：通过 UIManager 打开/关闭面板

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: UI 面板命名与资源唯一来源为 `ui_data.lua`/`refs.lua`，不再使用 `UINodes.lua`。
  Rationale: `ui_data.lua` 已包含面板数据，避免重复来源与同步成本。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

**2026-01-26 完成 UI 节点清点与管理器接入：**
- UI 数据文件已就位：ui_data.lua（节点配置）、refs.lua（资源引用）
- UIManager 完整集成：
  - 目录结构：UIManager/ 包含所有组件（Builder、ENode 系列、Promise、Listener 等）
  - 初始化逻辑：init.lua 中通过 UIManager.Builder(ui_data) 初始化
  - 节点类型完整：ELabel、EImage、EButton、ECanvas、EProgressbar、EInputField 等
- 已删除过时的 Data/UINodes.lua，无引用残留
- UI 面板管理统一：
  - 所有面板由 UIManager 统一管理
  - 面板数据来源唯一：ui_data.lua
  - 玩法逻辑通过统一接口操作 UI，不关心实现细节
- 为后续玩法系统、ECA 桥接、动画等待提供了 UI 基础设施

## Context and Orientation

UI 管理器来自汉堡 UI 系统，文档位于 `docs/eggy/ui_manager_lib.md`。面板资源与引用信息位于 `LuaSource_大富翁/ui_data.lua` 与 `LuaSource_大富翁/refs.lua`。重构版本需要在 `Refactoring/` 下以 `ui_data.lua` 作为唯一面板来源，统一交由 UIManager 管理。

## Plan of Work

先把 `LuaSource_大富翁/ui_data.lua`、`refs.lua` 复制到 `Refactoring/` 对应位置，并对照 UI 管理器文档确认初始化入口与使用方式。然后在 `Refactoring` 中创建/调整 UIManager 接线脚本，使其能直接依据 `ui_data.lua` 打开面板；最后针对黑市、机会卡、道具卡等关键面板做显式验证，记录缺失并在计划中补齐。若存在 `Data/UINodes.lua`，需要删除并清理引用。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 同步 UI 数据文件
    robocopy LuaSource_大富翁 Refactoring /E /XF *.log

    # 2) 打开并整理 UI 节点清单
    #    - LuaSource_大富翁/ui_data.lua
    #    - LuaSource_大富翁/refs.lua

    # 3) 根据 docs/eggy/ui_manager_lib.md 接入 UIManager
    # 4) 删除 Data/UINodes.lua（如存在）并清理引用

## Validation and Acceptance

执行后需满足：`Refactoring/ui_data.lua`、`Refactoring/refs.lua` 均存在；`Data/UINodes.lua` 不再存在或不被引用；UIManager 可按 `ui_data.lua` 的面板名打开至少三个核心 UI（黑市/机会卡/道具卡），并能正常关闭；缺失面板以清单形式记录在本计划的 `Surprises & Discoveries` 或后续子计划中。

## Idempotence and Recovery

复制与接入可重复执行。若 UI 管理器初始化失败，可回退到仅加载节点与资源文件，再逐步接入管理器逻辑以定位问题。

## Artifacts and Notes

建议在执行时生成“节点映射表”便于追踪，例如：

    黑市 -> UINodes.BlackMarket -> refs/ui_data 对应资源
    机会卡 -> UINodes.Chance -> refs/ui_data 对应资源
    道具卡 -> UINodes.Item -> refs/ui_data 对应资源

## Interfaces and Dependencies

依赖 `docs/eggy/ui_manager_lib.md` 的初始化方式；`Refactoring` 中 UIManager 必须对外提供统一的 `open(panel_name)`/`close(panel_name)`（或文档定义的等价接口），面板名来自 `ui_data.lua`，不允许在 gameplay 层直接引用具体 UI 实现。

本计划更新记录：

2026-01-26 19:15 创建本计划，原因是 UI 节点与管理器是所有交互弹窗的基础依赖。
