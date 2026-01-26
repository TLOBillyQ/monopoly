# 重构目录与基线骨架

本 ExecPlan 是活文档，`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随执行进度持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，执行与维护必须遵循该文件要求。

## Purpose / Big Picture

完成后将得到一个可独立运行的 `./Refactoring` 目录，它作为最终 Eggy 适配版本的根目录，具备完整的基础工程结构、入口文件与运行所需的最小代码拷贝。后续所有子计划都在这个骨架上叠加实现，并且不会再依赖 `LuaSource_大富翁/` 的运行环境。

## Progress

- [x] (2026-01-26 19:00) 创建本 ExecPlan，明确骨架目标与依赖。
- [ ] (2026-01-26 19:00) 定义 `Refactoring/` 目录结构与复制清单。
- [ ] (2026-01-26 19:00) 完成首次拷贝并确认基础入口文件可加载。

## Surprises & Discoveries

当前无新增记录。

## Decision Log

- Decision: 以 `LuaSource_大富翁/` 作为基础模板，复制到 `Refactoring/` 后再覆盖 `src/` 目录。
  Rationale: `LuaSource_大富翁/` 已是 Eggy 工程结构，直接复制可减少结构性差异。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

尚未执行，暂无产出与回顾。

## Context and Orientation

本仓库已包含一份 Eggitor 主工程 `LuaSource_大富翁/`，同时包含跨平台逻辑实现 `src/`。最终重构版本要求位于 `./Refactoring` 并独立运行，因此需要先建立一个与 Eggy 工程一致的目录结构，并把 `src/` 复制到 `Refactoring/src/` 作为逻辑底座。入口文件需放在 `Refactoring/main.lua` 与 `Refactoring/eggy_main.lua`（若 Eggy 入口约定需要）等位置。

## Plan of Work

先在 `Refactoring/` 下创建基础目录结构，复制 `LuaSource_大富翁/` 的工程骨架（含 `assets/`、`docs/`、`ui`、脚本目录等，具体以该目录现有内容为准），再覆盖 `Refactoring/src/` 为仓库根目录的 `src/`，确保逻辑代码一致。最后补齐 `Refactoring/main.lua` 与 `Refactoring/eggy_main.lua` 的入口占位（可先简单 `require` 根目录的入口逻辑），保证能被后续计划引用。

## Concrete Steps

在仓库根目录执行以下步骤（命令示例）：

    # 1) 准备目录
    mkdir Refactoring
    mkdir Refactoring\\plans

    # 2) 复制 Eggy 工程骨架
    robocopy LuaSource_大富翁 Refactoring /E

    # 3) 覆盖逻辑代码
    robocopy src Refactoring\\src /E

    # 4) 确认入口文件存在
    dir Refactoring\\main.lua
    dir Refactoring\\eggy_main.lua

若 Eggy 入口文件缺失，则在 `Refactoring/` 下创建最小入口文件，内容以调用 `Refactoring/src/entry.lua` 为准，避免引入新的逻辑分支。

## Validation and Acceptance

执行后需要满足以下可验证结果：`Refactoring/` 存在且包含 `src/`、`main.lua` 与工程骨架目录；`Refactoring/src/` 与仓库根目录 `src/` 内容一致；入口文件能够被 Lua `require` 加载（可用 `lua -e "require('Refactoring.main')"` 验证无语法错误）。

## Idempotence and Recovery

重复执行拷贝步骤应保持一致结果。若出现覆盖问题，可删除 `Refactoring/` 后重建并重新复制；不应修改 `LuaSource_大富翁/` 与根目录 `src/` 的原始内容。

## Artifacts and Notes

期望目录示例（缩进展示）：

    Refactoring/
      main.lua
      eggy_main.lua
      src/
      assets/
      ui/
      docs/
      plans/

## Interfaces and Dependencies

`Refactoring/main.lua` 必须能够加载 `Refactoring/src/entry.lua`（或等价入口），并保持“只做 wiring，不写规则”的原则。`Refactoring/src/` 直接依赖仓库根目录 `src/` 的模块结构，不允许在此阶段新增额外抽象层。

本计划更新记录：

2026-01-26 19:00 创建本计划，原因是重构版本需要先建立独立运行骨架与清晰拷贝策略。
