本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件遵循仓库内的 `/.agent/PLANS.md`。

# SOE 启动链路重构


## 目的 / 全局视角

把启动链路改成更接近 SecretOfEscaper 的模式：入口只负责延迟启动与调用初始化，初始化集中管理全局表、资源索引与 UI 构建，运行时只负责安装与驱动回合。完成后，启动顺序更清晰、初始化职责集中，规则行为保持不变。验收时应能正常进入场景、UI 初始化成功，且回归脚本通过。

## 进度

- [x] (2026-01-29 15:47Z) 梳理当前启动链路与职责边界，列出需要迁移到初始化阶段的内容
- [x] (2026-01-29 15:47Z) 调整 `main.lua` 与 `init.lua` 的调用顺序，迁移全局初始化逻辑并保持行为一致
- [x] (2026-01-29 15:47Z) 清理重复初始化路径，补齐文档与测试验证

## 意外与发现

暂无。

## 决策日志

- 决策：将 `EggyRuntime.install()` 移入 `init.lua`，入口 `main.lua` 保持单一 require。
  理由：对齐 SOE 入口形态，且不改变实际调用时机。
  日期/作者：2026-01-29 / Codex

## 结果与复盘

已将启动链路调整为 `main.lua` 仅加载 `init.lua`，运行时安装逻辑由 `init.lua` 统一触发。保持原始行为并通过测试验证。后续若需要把 GAME_INIT 相关初始化进一步集中到 Globals 层，可在不引入新 helper 的前提下增量调整。

## 背景与导读

当前入口 `main.lua` 直接加载 `init.lua` 并调用 `Manager.System.Runtime.install()`。初始化逻辑（UIManager.Builder、G 全局表初始化、资源索引）主要在 `Manager/System/Runtime.lua` 的 `GAME_INIT` 事件中完成；`Globals/__init.lua` 与 `Manager/__init.lua` 目前只提供占位入口。SecretOfEscaper 的启动链路强调 `init.lua` 负责全局初始化与资源绑定，`main.lua` 只负责延迟启动与场景入口。此次改动需要把初始化职责集中到 `init.lua` 或 `Globals/__init.lua`，保留 EggyRuntime 的运行时职责，但不改变任何游戏行为。

## 工作计划

先从 `Manager/System/Runtime.lua` 中整理出“初始化职责清单”（UI 构建、G.refs/G.tiles/G.buildings、UIManager 事件桥接等），区分哪些必须在 `GAME_INIT` 内执行、哪些可提前执行。然后把可提前部分迁移到 `Globals/__init.lua` 或 `init.lua`，并提供明确的初始化入口给 `EggyRuntime.install` 调用。更新 `main.lua` 为 SOE 风格的延迟启动（例如 `LuaAPI.call_delay_frame`），确保运行时环境准备好后再进行初始化与安装。最后清理重复初始化，保证每个全局表只初始化一次。

## 具体步骤

在仓库根目录执行：

  1) 打开 `main.lua`、`init.lua`、`Globals/__init.lua`、`Manager/System/Runtime.lua`，列出初始化职责与调用顺序。
  2) 将初始化代码抽到 `Globals/__init.lua` 或 `init.lua` 内的显式函数中，并在 `EggyRuntime.install` 中调用该函数。
  3) 调整 `main.lua` 的启动顺序为“延迟 -> init -> install”，避免重复初始化。
  4) 清理旧的初始化分支与重复调用。

## 验证与验收

在仓库根目录运行：

  lua .github/tests/deps_check.lua
  lua .github/tests/regression.lua

若可进入 Eggy 场景，确认 UI 与棋盘初始化正常，启动无报错，且回合推进不变。

## 可重复性与恢复

改动为可逆的初始化重排，不涉及数据迁移。若出现异常，可恢复到当前的 `main.lua` 与 `EggyRuntime.install` 初始化路径，并重新运行回归测试。

## 产物与备注

产物包括更新后的 `main.lua` 与 `init.lua`，以及整理后的初始化职责调用链。

测试输出片段：

  Dependency self-check passed
  All regression checks passed (30)

## 接口与依赖

`EggyRuntime.install` 必须继续对外暴露安装入口；初始化函数必须保持幂等或显式只调用一次。任何新增函数必须在至少两个位置被调用，或明确写明是启动链路唯一入口的必要模块。

变更说明：更新启动入口为 `init.lua` 内部安装运行时，并记录测试结果以完成本计划。
