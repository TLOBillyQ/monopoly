# 生成 only_eggy 精简分支

本 ExecPlan 是一份持续演进的活文档。`Progress`、`Surprises & Discoveries`、`Decision Log`、`Outcomes & Retrospective` 必须随着执行持续更新。

本仓库的 ExecPlan 规范位于 `.agent/PLANS.md`，本文件必须遵守其中所有要求并在执行过程中保持自洽与可复现。

## Purpose / Big Picture

执行完成后，会新增一个 Git 分支 `only_eggy`，该分支仅保留 Eggy 平台开发所需的目录与文件，并移除全部非 Eggy 平台实现与相关文档。结果应保证 Eggy 运行路径与核心玩法逻辑可继续开发和验证，且仓库不再包含非 Eggy 平台的入口、适配层与打包脚本。完成后可以通过运行现有 Lua 测试脚本验证核心玩法稳定，并通过搜索确认已无非 Eggy 平台残留实现文件。

## Progress

- [x] (2026-01-26 00:00Z) 创建 `plans/only_eggy` ExecPlan 初稿。
- [x] (2026-01-26 13:44Z) 明确 Eggy 相关文件白名单与删除清单，并记录到 Decision Log。
- [x] (2026-01-26 13:44Z) 在 `only_eggy` 分支完成删减、修订入口与文档、通过验证。

## Surprises & Discoveries

- Observation: README 提到 `eggy_main.lua`，但仓库中未找到该文件。
  Evidence: 运行 `rg --files -g 'eggy_main.lua'` 无输出。

## Decision Log

- Decision: 以“Eggy 运行时 + 玩法核心 + Eggy 工程/文档/脚本”为保留范围，删除非 Eggy 平台实现与相关文档。
  Rationale: 目标是只保留 Eggy 开发路径，减少非 Eggy 平台噪音与误用风险。
  Date/Author: 2026-01-26 / Codex
- Decision: 保留 headless（全 AI）自测脚本与通用玩法测试，因为它们用于验证 Eggy 玩法逻辑且不依赖其他平台。
  Rationale: 删除平台实现后仍需可验证核心逻辑，避免无测试回归。
  Date/Author: 2026-01-26 / Codex
- Decision: Eggy 保留白名单明确为 `LuaSource_大富翁/`、`src/`（保留 `src/adapters/eggy` 与 `src/adapters/core`）、`main.lua`、`src/entry.lua`、`src/bootstrap.lua`、`docs/eggy/`、`docs/adapters_design.md`（仅保留 Eggy 内容）、`design/`、`assets/`、`src/config/`、`scripts/eggy_api_split_check.py`、`scripts/eggy_api_split_generate.py`、`scripts/remove_deprecated_eggyapi.py`、`scripts/export_xlsx.py`、`export_xlsx.bat`、`run_all_ai.bat`、`scripts/run_all_ai.ps1`、`tests/deps_check.lua`、`tests/regression.lua`、`tests/flow_control_test.lua`、`tests/test_utils.lua`。
  Rationale: 这些目录与脚本覆盖 Eggy 运行、核心玩法、配置与最小验证；其余内容不再需要。
  Date/Author: 2026-01-26 / Codex

## Outcomes & Retrospective

已在 `only_eggy` 分支完成精简：移除非 Eggy 适配目录与平台文档，清理入口与 README，保留 Eggy 运行与 headless 验证路径。依赖检查与回归测试均通过，headless 模式可完整跑完并输出胜者。后续若需要重新引入其他平台，应在新的分支或独立仓库完成，避免污染 Eggy 精简分支。

## Context and Orientation

仓库核心逻辑在 `src/`，其中 `src/adapters/eggy/` 是 Eggy 适配层，`src/adapters/core/` 是共享适配骨架。Eggy 主工程位于 `LuaSource_大富翁/`，其 `main.lua` 依赖 Eggy 全局 `LuaAPI` 与 `EVENT`。Eggy 平台文档在 `docs/eggy/`，非 Eggy 文档在 `docs/architecture/` 等目录。测试脚本位于 `tests/`，其中平台自测脚本需剔除，仅保留通用规则测试。当前 `src/entry.lua` 仍支持多平台分支，需要在 Eggy 精简分支中移除非 Eggy 路径并保持 Eggy 行为不变。

## Plan of Work

首先确认“仅 Eggy 开发相关”在本仓库的具体范围，并将允许保留的路径记录为白名单（见 Decision Log）。确认后，在 `only_eggy` 分支中删除白名单之外的目录与文件，并修订入口与文档避免提及非 Eggy 平台。

具体修改应包括：删除 `src/adapters/` 下除 `core/` 与 `eggy/` 之外的适配目录；从 `src/entry.lua` 移除非 Eggy 分支与默认逻辑，仅保留 Eggy 与 headless；调整 `main.lua` 注释，使其表述为 Lua/headless 入口；删除非 Eggy 平台文档与打包脚本；更新 `README.md` 只描述 Eggy 入口与 headless 自测；移除平台自测脚本；并在 `docs/adapters_design.md` 中删除或改写非 Eggy 段落。所有删除与改写都必须保持 Eggy 路径行为一致，不引入新抽象，不新增多余文件。

完成删减后，通过搜索确认仓库内不再包含非 Eggy 平台实现与文档引用，并运行现有 Lua 测试验证核心逻辑。

## Concrete Steps

在仓库根目录执行以下命令。路径以 `/Users/billyq/Dev/Github/Lua/monopoly` 为准。

    cd /Users/billyq/Dev/Github/Lua/monopoly
    git status -sb

确认或创建 `only_eggy` 分支。如果已存在则切换，否则创建。

    git branch --list only_eggy
    git switch only_eggy

若不存在，则执行：

    git switch -c only_eggy

列出将要删除的非 Eggy 平台目录，并执行删除（若路径不存在可跳过）。删除范围以白名单为准，包含非 Eggy 适配目录、平台文档、打包脚本与历史规划目录。

调整入口与文档。

    # 编辑 src/entry.lua，移除非 Eggy 分支与默认逻辑，仅保留 eggy/headless
    # 编辑 main.lua，修改注释为 Lua/headless 入口
    # 编辑 README.md，仅保留 Eggy 与 headless 说明
    # 编辑 export_xlsx.bat，移除打包步骤
    # 编辑 docs/adapters_design.md，仅保留 Eggy 适配说明

验证仓库中是否仍有非 Eggy 平台相关实现或文档引用，并记录仍需处理的残留。可使用 `rg -n` 搜索旧平台目录名与入口关键词。

运行测试验证核心逻辑。

    lua tests/deps_check.lua
    lua tests/regression.lua

若需要验证 headless 模式可继续运行：

    lua main.lua --all-ai

## Validation and Acceptance

验收标准必须是可观察行为。完成后需满足：`git branch --show-current` 返回 `only_eggy`；`src/adapters/` 下仅剩 `core/` 与 `eggy/`；搜索不再匹配到非 Eggy 平台实现或文档内容；`lua tests/deps_check.lua` 与 `lua tests/regression.lua` 均成功；headless 模式可在终端输出完整流程且不报错。README 中只描述 Eggy 入口与 headless 自测，不再提示非 Eggy 平台入口。

## Idempotence and Recovery

所有删除都通过 `git rm` 完成，可重复执行且可通过 `git restore --source=HEAD -- <path>` 恢复误删文件。若步骤中断，重新进入 `only_eggy` 分支继续执行即可。执行前后均应运行 `git status -sb` 确认状态，避免误删未跟踪的本地文件。

## Artifacts and Notes

建议在完成删减后记录一段精简的对比输出，用于证明仓库已无非 Eggy 平台内容，例如：

    $ rg -n "<旧平台关键词>" -S
    (无输出)

    $ ls src/adapters
    core
    eggy

    $ lua tests/deps_check.lua
    Dependency self-check passed

    $ lua tests/regression.lua
    ............................
    All regression checks passed (28)

    $ lua main.lua --all-ai
    === All-AI Mode Start ===
    Players: 4 AI players
    Turn: 168, Alive: 3 (Steps: 168)
    Turn: 236, Alive: 2 (Steps: 258)
    Turn: 246, Alive: 1 (Steps: 277)

    === Game Over ===
    Turn count: 246
    Steps executed: 277
    Winner: AI3

## Interfaces and Dependencies

本计划不新增第三方依赖。`src/entry.lua` 仍需对外暴露 `Entry.run(opts)`，Eggy 路径继续调用 `src.adapters.eggy.eggy_runtime`，headless 路径保持既有日志与回合推进逻辑。删除非 Eggy 平台模块后，任何对旧平台适配的 `require` 必须被清理或替换，确保依赖检查与运行测试通过。

变更记录：
- 2026-01-26 创建初版 ExecPlan，明确仅 Eggy 开发范围与执行步骤。
- 2026-01-26 更新 ExecPlan 以反映删减执行、入口与文档调整、测试通过情况。
- 2026-01-26 补充 headless 与测试输出作为验收证据。
