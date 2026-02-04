# 扁平化 Config/Runtime 并语义化重命名

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agents/PLANS.md` 的规范维护。

## 目的 / 全局视角

把 `Config/Runtime` 扁平化到 `Config/` 根目录，并按语义重命名运行时文件，统一到现有 Config 的组织方式。完成后：所有引用改为新路径，回归脚本通过，运行时行为不变。

## 进度

- [x] (2026-02-04 13:50Z) 清空并重写 `.agents/PLAN_CURRENT.md` 为本计划
- [x] (2026-02-04 13:50Z) 迁移并重命名 `Config/Runtime` 下的 4 个文件到 `Config/`
- [x] (2026-02-04 13:50Z) 更新所有 `require` 引用到新文件名
- [x] (2026-02-04 13:50Z) 清理空目录并确认无旧路径残留
- [x] (2026-02-04 13:50Z) 运行 `.agents/tests/regression.lua` 验证

## 意外与发现

- 观察：回归脚本通过。
  证据：`All regression checks passed (36)`

## 决策日志

- 决策：选择“扁平化到 Config 根目录 + 语义化重命名”。
  理由：与现有 Config 组织一致，文件名表达用途且避免目录层级。
  日期/作者：2026-02-04 / Codex。

- 决策：重命名规则如下：
  - `Config/Runtime/Macro.lua` -> `Config/RuntimeConstants.lua`
  - `Config/Runtime/Refs.lua` -> `Config/RuntimeRefs.lua`
  - `Config/Runtime/Globals.lua` -> `Config/RuntimeGlobals.lua`
  - `Config/Runtime/ECA.lua` -> `Config/RuntimeECA.lua`
  理由：与内容语义对应，保持可读性。
  日期/作者：2026-02-04 / Codex。

## 结果与复盘

已完成 Config 扁平化与语义化重命名，引用已更新，回归测试通过。剩余事项：无。

## 背景与导读

上一轮迁移把 `src/runtime` 移到 `Config/Runtime`。为符合现有 Config 组织规范，需要进一步扁平化并语义化命名。涉及引用位于 `src/app/init.lua`、`src/ui/UIView.lua`、`src/ui/ActionAnim.lua`、`src/ui/MoveAnim.lua`，以及运行时模块内部 `require`。

## 工作计划

先移动并重命名 `Config/Runtime` 下的 4 个文件到 `Config/` 根目录，然后逐一更新所有 `require` 引用到新的文件名。最后删除空目录并全局搜索旧路径，运行回归脚本确认行为不变。

## 具体步骤

在仓库根目录完成如下修改：
1. 移动并重命名文件：
   - `Config/Runtime/Macro.lua` -> `Config/RuntimeConstants.lua`
   - `Config/Runtime/Refs.lua` -> `Config/RuntimeRefs.lua`
   - `Config/Runtime/Globals.lua` -> `Config/RuntimeGlobals.lua`
   - `Config/Runtime/ECA.lua` -> `Config/RuntimeECA.lua`
2. 更新引用：
   - `src/app/init.lua` 的 `Config.Runtime.Globals` / `Config.Runtime.ECA`。
   - `src/ui/UIView.lua` 的 `Config.Runtime.Refs`。
   - `src/ui/ActionAnim.lua` 与 `src/ui/MoveAnim.lua` 的 `Config.Runtime.Macro`。
   - `Config/RuntimeGlobals.lua` 与 `Config/RuntimeECA.lua` 内部的 `require`。
3. 删除空目录 `Config/Runtime`，并确认无旧路径残留。
4. 运行 `lua .agents/tests/regression.lua`。

## 验证与验收

运行 `lua .agents/tests/regression.lua`，预期输出 `All regression checks passed (36)`。启动游戏后初始化与 UI/动画/相机逻辑不因路径变更报错。

## 可重复性与恢复

本变更为路径与引用更新，可重复执行。若需回退，将文件移回 `Config/Runtime` 并恢复原 `require` 路径。

## 产物与备注

    文件：Config/RuntimeConstants.lua
    说明：原 Config/Runtime/Macro.lua

    文件：Config/RuntimeRefs.lua
    说明：原 Config/Runtime/Refs.lua

    文件：Config/RuntimeGlobals.lua
    说明：原 Config/Runtime/Globals.lua

    文件：Config/RuntimeECA.lua
    说明：原 Config/Runtime/ECA.lua

## 接口与依赖

路径变更：
- `Config/Runtime/Macro.lua` -> `Config/RuntimeConstants.lua`
- `Config/Runtime/Refs.lua` -> `Config/RuntimeRefs.lua`
- `Config/Runtime/Globals.lua` -> `Config/RuntimeGlobals.lua`
- `Config/Runtime/ECA.lua` -> `Config/RuntimeECA.lua`

依赖变更：所有 `require "Config.Runtime.*"` 更新为新文件名（不再使用子目录）。

计划变更说明：2026-02-04 补充完成状态与回归结果。
