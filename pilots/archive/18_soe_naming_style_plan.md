本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE 命名风格统一


## 目的 / 全局视角

目标是把本项目的文件名、目录名、模块名与函数命名风格统一为 SecretOfEscaper 的命名习惯：目录与文件使用帕斯卡命名（如 `TurnManager.lua`、`MarketService.lua`），模块表名使用帕斯卡命名，函数保持小写蛇形或 SOE 现有风格不变。完成后用户能在根目录用 SOE 风格的路径 `Manager/System/Runtime.lua`、`Components/Board.lua` 等加载模块，测试脚本与入口 `main.lua` 正常运行，行为不变。

## 进度

- [x] (2026-01-29 15:24Z) 盘点现有文件与命名差异，输出“旧路径 -> 新路径”映射清单
- [x] (2026-01-29 15:24Z) 逐层重命名目录与文件（Components/Config/Manager/Library），同步改写 require 与文档引用
- [x] (2026-01-29 15:25Z) 清理遗留路径引用，补齐必要的 `__init.lua`，运行测试验证

## 意外与发现

- 观察：批量替换会先命中短模块名，导致 `land_pricing` 等长模块只被部分改写成 `Land_pricing`。
  证据：`rg -n "Land_pricing"` 命中多个 require 行。

## 决策日志

- 决策：对包含下划线的模块名做二次定向替换，确保完整映射到帕斯卡命名。
  理由：避免部分命中造成命名残留。
  日期/作者：2026-01-29 Codex

## 结果与复盘

已完成 SOE 命名风格统一：核心目录与文件全部改为帕斯卡命名，require 路径同步更新，Data 的 UI 节点文件改名为 `UIManagerNodes.lua`。回归与依赖测试通过。后续若需要同步历史文档中 `src/` 的说明，可另开任务。

## 背景与导读

当前项目已迁移为 SOE 风格顶层结构，但子目录与文件仍保留大量小写蛇形命名（例如 `Manager/GameManager/TurnManager.lua`、`Manager/System/Runtime.lua`、`Config/LandingEffects.lua`）。SecretOfEscaper 的命名习惯是：目录与文件名使用帕斯卡命名（如 `Manager/MapManager/Lobby/GUI/MainView.lua`），模块表名也是帕斯卡命名，函数多为小写蛇形。要达成统一，需要重命名文件与目录，并同步所有 `require` 路径与文档引用，同时保证行为不变。

## 工作计划

先生成“旧路径 -> 新路径”的映射清单，覆盖 `Components/`、`Config/`、`Manager/GameManager/`、`Manager/Adapter/`、`Library/Monopoly/` 以及 `Data/UIManagerNodes.lua` 相关引用。然后按层级重命名目录与文件，优先改目录（如 `Manager/Adapter/eggy` -> `Manager/Adapter/Eggy`），再改文件名（如 `turn_manager.lua` -> `TurnManager.lua`），并同步替换所有 `require` 与测试/文档中的旧路径。若系统对大小写不敏感，采用“临时名 -> 目标名”的两步重命名以避免失败。完成后运行测试脚本确保功能不变，记录输出。

## 具体步骤

在仓库根目录执行：

  1) 列出所有 Lua 文件，生成映射清单（可用 `rg --files` + 手工整理）。
  2) 逐级重命名目录与文件，必要时先改为临时名再改为目标名。
  3) 全量替换 `require("...")` 路径与文档中的旧路径。
  4) 运行测试脚本并修复遗漏引用。

## 验证与验收

在仓库根目录运行：

  lua tests/deps_check.lua
  lua tests/regression.lua

预期脚本无报错退出，并能从 `main.lua` 正常加载新路径模块。

## 可重复性与恢复

改动只涉及命名与路径替换，可重复执行。若需要回退，使用版本控制恢复或将目录/文件名改回旧命名。大小写重命名在大小写不敏感文件系统上需使用临时名过渡以保证可逆。

## 产物与备注

产物为新的 SOE 风格文件与目录命名、更新后的 `require` 与文档路径引用，以及通过的测试输出。

测试输出片段：

  Dependency self-check passed
  All regression checks passed (30)

变更说明：完成全部命名替换并补充测试记录。

## 接口与依赖

保持原有模块功能不变，仅修改命名。所有 require 路径必须与新的文件名完全匹配（大小写敏感），并保持 `__init.lua` 的入口语义不变。
