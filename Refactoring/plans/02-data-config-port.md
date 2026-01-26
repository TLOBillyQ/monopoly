# 设计数据与配置同步

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后，`Refactoring/src/config/` 与 `design/*.xlsx` 保持一致的单向数据流，配置成为可追溯、可更新的唯一来源。这样任何版本都能以策划表为准更新玩法数值，并保证重构版本与现有 `src/` 行为一致。

## Progress

- [x] (2026-01-26 19:05) 创建本 ExecPlan，明确配置同步策略。
- [ ] (2026-01-26 19:05) 建立 `design → src/config → Refactoring/src/config` 的同步流程。
- [ ] (2026-01-26 19:05) 校验同步结果与版本一致性。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 以 `design/*.xlsx` 为唯一真源，`src/config/*.lua` 作为生成产物，再同步到 `Refactoring/src/config/`。
  Rationale: 已有导出脚本与约定，延续现有工作流可避免多人协作分歧。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

策划需求位于 `design/`，配置导出脚本为 `export_xlsx.bat`，生成产物位于 `src/config/`。重构版本位于 `Refactoring/`，因此需要把 `src/config/` 同步为 `Refactoring/src/config/`，并且在后续修改中只通过 `design` 更新。

## Plan of Work

先运行 `export_xlsx.bat` 更新 `src/config/`，再将 `src/config/` 复制到 `Refactoring/src/config/`。在同步完成后，用文件差异校验确保 `Refactoring/src/config/` 与 `src/config/` 一致，并在 `Refactoring` 目录下记录“配置来源”的说明（可在 `Refactoring/README.md` 或后续文档中补充）。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 重新导出配置
    .\\export_xlsx.bat

    # 2) 同步到 Refactoring
    robocopy src\\config Refactoring\\src\\config /E

    # 3) 校验差异
    fc /B src\\config\\constants.lua Refactoring\\src\\config\\constants.lua

若 `export_xlsx.bat` 无法运行，先记录失败原因并停止同步，避免将旧配置写入重构版本。

## Validation and Acceptance

执行后需满足：`Refactoring/src/config/` 全部文件存在；与 `src/config/` 内容一致；关键配置（如 `constants.lua`、`items.lua`、`chance_cards.lua`）可被 `Refactoring` 入口正常 `require`。

## Idempotence and Recovery

同步流程可重复执行。若中途失败，删除 `Refactoring/src/config/` 后重新复制即可恢复。严禁手工编辑 `Refactoring/src/config/` 以免数据源漂移。

## Artifacts and Notes

可作为验证的文件清单示例：

    Refactoring/src/config/constants.lua
    Refactoring/src/config/items.lua
    Refactoring/src/config/chance_cards.lua
    Refactoring/src/config/tiles.lua

## Interfaces and Dependencies

`export_xlsx.bat` 必须可生成 `src/config/*.lua`；`Refactoring/src/config/` 只作为下游产物，不允许新增逻辑分支。后续计划依赖此计划提供的稳定配置数据。

本计划更新记录：

2026-01-26 19:05 创建本计划，原因是重构版本需要稳定的配置同步流程以保证需求完整性。
