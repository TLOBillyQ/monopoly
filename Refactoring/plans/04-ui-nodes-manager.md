# UI 节点清点与管理器接入

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，`Refactoring` 将拥有可工作的 UI 管理器，所有 UI 面板由 UIManager 统一管理并从 `ui_data.lua` 读取，玩法逻辑通过统一接口打开/关闭 UI，而不关心具体实现细节。`Data/UINodes.lua` 被移除，不再作为依赖。

## Progress

- [x] (2026-01-26 19:15) 创建本 ExecPlan，明确 UI 节点清点与接入范围。
- [ ] (2026-01-26 19:15) 仅基于 `ui_data.lua`/`refs.lua` 盘点 UI 面板资源与命名。
- [ ] (2026-01-26 19:15) 接入 `docs/eggy/ui_manager_lib.md` 所述 UIManager 到 `Refactoring`。
- [ ] (2026-01-26 19:15) 删除 `Data/UINodes.lua`（如存在），并确保无引用残留。
- [ ] (2026-01-26 19:15) 验证核心弹窗可被打开并关闭。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: UI 面板命名与资源唯一来源为 `ui_data.lua`/`refs.lua`，不再使用 `UINodes.lua`。
  Rationale: `ui_data.lua` 已包含面板数据，避免重复来源与同步成本。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

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
