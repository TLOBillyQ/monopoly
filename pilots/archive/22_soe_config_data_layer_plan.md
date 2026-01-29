本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE 配置/数据分层


## 目的 / 全局视角

把配置与生成数据分层为 SOE 风格：由脚本生成的只读数据落在 `.h.lua`（或 `Generated/`）中，手写配置与运行时变换保留在 `.lua` 中。完成后，配置来源清晰、导出脚本与运行时依赖一致，行为不变。验收时导出脚本可运行、测试通过。

## 进度

- [x] (2026-01-29 16:09Z) 盘点现有配置文件与导出脚本，确认哪些是生成数据
- [x] (2026-01-29 16:09Z) 调整导出脚本输出位置与命名，新增 `Config/Generated/` 层
- [x] (2026-01-29 16:09Z) 维护运行时入口与 require 路径兼容，更新脚本与测试

## 意外与发现

- 观察：Lua 的默认 require 无法直接加载 `Config/<Name>.h.lua` 形式的文件名。
  证据：现有运行环境未修改 `package.path`，需要避免新增搜索路径。

## 决策日志

- 决策：采用 `Config/Generated/` 承载导出数据，`Config/<Name>.lua` 作为薄封装入口。
  理由：无需改动 `package.path`，保持 `require("Config.<Name>")` 不变。
  日期/作者：2026-01-29 / Codex
- 决策：`Constants` 继续按导出数据处理，与其它表一致进入 `Config/Generated/`。
  理由：当前常量表来源于 Excel，保持脚本一致输出更清晰。
  日期/作者：2026-01-29 / Codex

## 结果与复盘

完成配置/生成数据分层：导出数据迁入 `Config/Generated/`，入口封装保持不变，导出脚本与批处理提示更新。依赖检查、回归测试与导出脚本运行通过。

## 背景与导读

当前配置集中在 `Config/*.lua`，由 `scripts/export_xlsx.py` 直接生成，例如 `Config/Tiles.lua`、`Config/Roles.lua` 等。为避免引入 `.h.lua` 的 require 路径问题，本次改造采用 `Config/Generated/` 承载导出数据，`Config/*.lua` 变成薄封装入口，保持调用方式不变。

## 工作计划

先盘点哪些配置来自 Excel（tiles/roles/items/vehicles/market 等），哪些是手写配置（Map、LandingEffects 等）。调整 `scripts/export_xlsx.py` 输出到 `Config/Generated/<Name>.lua`，并在 `Config/<Name>.lua` 中以 `return require("Config.Generated.<Name>")` 形式返回数据。对手写配置保持不变。更新导出脚本提示，确保团队知道生成文件的职责。

## 具体步骤

在仓库根目录执行：

  1) 修改 `scripts/export_xlsx.py` 的输出目录为 `Config/Generated/`，并更新文件名为帕斯卡命名。
  2) 为每个导出配置创建对应的 `Config/<Name>.lua` 入口，保持调用路径不变。
  3) 更新 `export_xlsx.bat` 输出提示。
  4) 运行导出脚本并刷新生成文件。

## 验证与验收

在仓库根目录运行：

  lua tests/deps_check.lua
  lua tests/regression.lua

如环境具备 Python，运行：

  python3 scripts/export_xlsx.py

预期导出成功，且运行时仍能通过 `Config.<Name>` 获取数据。已运行导出脚本并通过测试。

## 可重复性与恢复

导出文件为可重复生成产物。若需回退，可保留旧的 `Config/*.lua` 文件并恢复脚本输出路径。本次已拆出 `Config/Generated/`。

## 产物与备注

产物包括 `Config/Generated/*.lua` 生成文件、`Config/*.lua` 入口包装，以及更新后的导出脚本说明。

  Dependency self-check passed
  ..............................
  All regression checks passed (30)

## 接口与依赖

`Config.<Name>` 的 require 路径保持不变。生成文件只包含数据，不包含运行时逻辑。

更新说明：完成 Config/Generated 分层与导出脚本更新，避免 .h.lua require 限制并保持运行时兼容。
