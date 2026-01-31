本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE 架构重写


## 目的 / 全局视角

目标是在保持玩法与行为不变的前提下，将当前项目从 `src/` 结构整体迁移到与 SecretOfEscaper 相同的顶层架构。完成后用户能在仓库根目录看到 `Components/`、`Config/`、`Data/`、`Globals/`、`Library/`、`Manager/`、`init.lua`、`main.lua` 这样的结构，并且游戏仍能正常启动。可见效果包括：入口 `main.lua` 能正常运行，原有测试脚本通过，且核心玩法逻辑不变。

## 进度

- [x] (2026-01-29 15:04Z) 盘点现有 `src/` 模块与 SecretOfEscaper 架构，明确迁移映射表与入口路径
- [x] (2026-01-29 15:04Z) 复制 `SecretOfEscaper/Library` 到根目录 `Library/`，并确认工具模块迁入 `Library/Monopoly/`
- [x] (2026-01-29 15:04Z) 迁移 `src/` 模块到 SOE 风格目录，修正所有 `require` 路径与入口文件
- [x] (2026-01-29 15:04Z) 移除 `src/` 目录，补齐缺失辅助函数并完成自测

## 意外与发现

- 观察：回归测试暴露出 `Manager/GameManager/Effect.lua` 缺少 `build_ctx`/`can_apply` 与执行器合并逻辑。
  证据：`lua tests/regression.lua` 报错 `global 'build_ctx' is not callable`。
- 观察：棋盘前进/后退路径缺失 `OPPOSITE` 与 `pick_any_dir`，导致移动回退失败。
  证据：`lua tests/regression.lua` 报错 `global 'OPPOSITE'` 与 `global 'pick_any_dir'`。
- 观察：测试环境没有 `GameAPI`，导致 RNG 调用失败。
  证据：`lua tests/regression.lua` 报错 `global 'GameAPI' is not callable`。

## 决策日志

- 决策：将原 `src/util/` 迁移到 `Library/Monopoly/`，避免与 `Library/Utils.lua` 命名冲突。
  理由：`SecretOfEscaper/Library` 已包含 `Utils.lua`，直接覆盖会引起路径冲突。
  日期/作者：2026-01-29 Codex
- 决策：在 RNG 中加入 `GameAPI` 缺失时的 `math.random` 兜底，仅用于测试环境。
  理由：保证测试运行，同时不影响运行时 `GameAPI` 存在时的行为。
  日期/作者：2026-01-29 Codex

## 结果与复盘

已完成 SOE 架构迁移，所有 `src/` 代码迁入新目录结构并修正 `require` 路径，根目录新增 `Library/`、`Globals/`、`Manager/` 与 `init.lua`，入口 `main.lua` 更新。补齐缺失辅助函数后回归测试通过。后续若需要统一文档路径引用，可再单独更新 `docs/` 与历史计划。

## 背景与导读

当前项目代码主要位于 `src/` 下，入口为根目录 `main.lua`，它直接加载 `Manager.System.Runtime`。核心业务逻辑分散在 `src/core/` 与 `src/gameplay/`，配置在 `src/config/`，适配层在 `src/adapters/`，工具在 `src/util/`。SecretOfEscaper 采用顶层分层结构：`Components/`（系统组件）、`Manager/`（管理器与业务流程）、`Config/`（配置）、`Data/`（数据表）、`Globals/`（全局初始化）、`Library/`（通用库）、`init.lua`（初始化）、`main.lua`（入口）。本次重写需要把现有逻辑迁移到类似结构，并确保旧功能不变。

## 工作计划

先梳理 `src/` 模块与依赖关系，形成一张迁移映射表，确定每个模块的新落点与新 `require` 路径。再把 `SecretOfEscaper/Library` 整体复制到根目录 `Library/`，并评估与现有 `src/util/` 的命名冲突，给出现有工具模块的新目录（例如 `Library/Monopoly/`）与 `require` 路径改写策略。随后按映射迁移代码：把 `src/core/` 迁到 `Components/`，把 `src/gameplay/` 迁到 `Manager/GameManager/`（或等价结构），把 `src/adapters/` 迁到 `Manager/Adapter/`，把 `src/config/` 迁到 `Config/`，把 `src/util/` 迁到 `Library/Monopoly/`。迁移过程中同步改写所有 `require` 路径，更新 `main.lua` 与新增 `init.lua`（如需）以符合 SOE 启动模式，但确保行为不变。最后删除 `src/` 目录，运行测试脚本验证。

## 具体步骤

在仓库根目录执行：

  1) 列出 `src/` 与 `SecretOfEscaper/` 结构，整理迁移映射表。
  2) 复制 `SecretOfEscaper/Library` 到根目录 `Library/`。
  3) 创建目标目录结构（`Components/`、`Config/`、`Globals/`、`Manager/` 等），移动文件并逐个修正 `require` 路径。
  4) 修改 `main.lua` 与必要的初始化入口，使启动流程与 SOE 风格一致但功能不变。
  5) 删除 `src/` 并运行测试脚本。

如需文件移动，使用 `git mv` 或等价方式以保留历史（若仓库无 git 也可直接移动）。

## 验证与验收

在仓库根目录运行：

  lua tests/deps_check.lua
  lua tests/regression.lua

预期所有脚本无报错退出。若有报错，修复路径或模块加载问题后重试。最终以启动入口 `main.lua` 无加载错误为验收基准之一。

## 可重复性与恢复

所有步骤为可重复迁移与路径改写，不涉及数据破坏。若迁移中断，可回滚到移动前的目录结构或从版本控制恢复。若缺少 git 历史，建议在迁移前复制当前工作目录作为备份。

## 产物与备注

迁移后应存在以下路径：

  Library/ (来自 SecretOfEscaper)
  Components/
  Config/
  Manager/
  init.lua
  main.lua

并且 `src/` 目录不存在。

测试输出片段：

  Dependency self-check passed
  All regression checks passed (30)

## 接口与依赖

依赖 `SecretOfEscaper/Library` 作为根目录 `Library/`。所有原 `src.*` 模块的 `require` 路径必须被替换为新的顶层目录命名，例如 `Components.Board` 迁移后应以新的路径（如 `Components.Board`）加载。入口 `main.lua` 必须在新结构下可直接加载游戏并触发原有逻辑。

变更说明：补全计划进度与测试结果，记录迁移中的缺失函数与 RNG 兜底决策，确保计划对现状完整自足。
