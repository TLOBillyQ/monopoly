# 道具槽位图标随库存变化更新


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。本文件必须遵循仓库内 `.agent/PLANS.md` 的规范维护。

## 目的 / 全局视角


当玩家库存发生变化（获得、消耗、被偷、清空）时，道具槽位图标会立即刷新为对应的道具图标或空槽图标。改动完成后，可以在游戏内触发获得道具或消耗道具，观察 UI 立刻更新来验证。

## 进度


- [x] (2026-02-03 17:10) 清空并重写 `PLAN_CURRENT.md`，切换到道具槽位图标更新任务
- [x] (2026-02-03 17:10) 调整 `src/ui/UIView.lua` 复用统一的槽位图标设置逻辑，确保同名节点同步更新
- [x] (2026-02-03 17:11) 运行 `lua .agent/tests/regression.lua` 回归验证

## 意外与发现


目前无意外与发现。

## 决策日志


- 决策：将 `set_item_slot_image` 提升为文件内共享本地函数，供初始化与刷新共同使用。
  理由：确保道具槽位在初始化与库存变化时都按同一逻辑更新，并覆盖同名 UI 节点。
  日期/作者：2026-02-03 / Codex。

## 结果与复盘


已完成回归脚本验证，未发现新增回归问题。

## 背景与导读


道具槽位 UI 刷新由 `src/ui/UIView.lua` 的 `refresh_item_slots` 负责，图标映射来自 `src/runtime/Refs.lua`。初始化阶段 `init_ui_assets` 内部定义了 `set_item_slot_image` 并用于预设图标，但刷新逻辑只更新单节点，无法保证同名节点全部更新。本计划统一槽位图标设置逻辑，确保库存变化时 UI 完整刷新。

## 工作计划


只修改 `src/ui/UIView.lua`。把 `set_item_slot_image` 提升为文件内共享本地函数，内部使用 `ui_aliases.resolve` 并遍历 `UIManager.query_nodes_by_name` 的所有节点设置 `image_texture`。`init_ui_assets` 继续使用该函数保持初始化行为不变。`refresh_item_slots` 改为调用该函数设置图标，触摸开关逻辑维持原样。

## 具体步骤


在仓库根目录编辑 `src/ui/UIView.lua`，完成以下修改：

    1) 将 `set_item_slot_image` 移到文件顶部 `_query_node` 附近，作为共享本地函数。
    2) 在 `set_item_slot_image` 内使用 `ui_aliases.resolve` 并遍历 `UIManager.query_nodes_by_name` 返回的所有节点。
    3) 在 `refresh_item_slots` 中调用 `set_item_slot_image` 设置图标。

如需回归验证，在 `c:\Users\Lzx_8\Desktop\dev\monopoly` 运行：

    lua .agent/tests/regression.lua

## 验证与验收


回归脚本通过且输出包含 `All regression checks passed`。在游戏内触发获得道具与消耗道具，观察道具槽位图标及时更新为空或对应图标。

## 可重复性与恢复


修改可重复执行且无破坏性变更。如需回退，只需恢复 `src/ui/UIView.lua` 的修改。

## 产物与备注


本次产物仅包含 `src/ui/UIView.lua` 的槽位图标设置逻辑调整，无新增文件。

## 接口与依赖


不新增依赖，不新增公共接口。`src/ui/UIView.lua` 内部新增共享本地函数：

    local function set_item_slot_image(slot_name, image_key)

变更记录：2026-02-03 17:10 重写 `PLAN_CURRENT.md`，原因是切换到道具槽位图标更新任务。
变更记录：2026-02-03 17:11 更新进度与结果，原因是回归脚本已通过。
