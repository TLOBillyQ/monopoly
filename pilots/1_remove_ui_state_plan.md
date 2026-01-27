# 去掉 UIState 薄封装并直连 UIManager

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。  
本计划遵循 ` .agent/PLANS.md`。

## 目的 / 全局视角

目标是删除 `src/adapters/eggy/ui_state.lua` 这层薄封装，让 UI 逻辑直接使用 `UIManager` 查询节点与设置属性。完成后，Eggy 适配层不再依赖 `UIState.get_node/set_label/set_visible` 等转发函数，节点查询与属性变更路径与 `docs/eggy/ui_manager_lib.md` 描述一致。验证方式：运行现有测试脚本，且 UI 行为无变化。

## 进度

- [x] (2026-01-27 14:44Z) 盘点 UIState 依赖点并标注替换范围  
- [x] (2026-01-27 14:44Z) 在 EggyLayer 中替换为 UIManager 直连调用  
- [x] (2026-01-27 14:44Z) 清理 ui_state.lua 与相关引用  
- [x] (2026-01-27 14:50Z) 运行测试并记录结果

## 意外与发现

- 观察：仓库中已不存在 src/adapters/eggy/ui_state.lua，eggy_layer.lua 已直接使用 UIManager 查询节点。
  证据：ls src/adapters/eggy；src/adapters/eggy/eggy_layer.lua:180-256。

## 决策日志

- 决策：优先删除 UIState 模块而非保留兼容层。  
  理由：CodingDiscipline 要求复用与删除优先，UIManager 已提供完整能力。  
  日期/作者：2026-01-27 / Codex
- 决策：同步更新 docs/adapters_design.md 的 UIState 描述为当前实现。  
  理由：避免设计文档与现状不一致，降低新手阅读成本。  
  日期/作者：2026-01-27 / Codex

## 结果与复盘

已完成 UIState 清理与文档同步，Lua 测试通过。

## 背景与导读

当前 `src/adapters/eggy/ui_state.lua` 封装了 UI 节点查询与属性设置，并在 `src/adapters/eggy/eggy_layer.lua` 中作为 `self.ui` 使用。`docs/eggy/ui_manager_lib.md` 指出 `UIManager.query_nodes_by_name` 直接返回节点数组，节点属性（如 `text`、`visible`、`disabled`）可直接设置并同步到引擎。为减少薄封装与冗余逻辑，需要删除 `UIState`，在 Eggy 适配层直接使用 `UIManager` API。

## 工作计划

先定位 `src/adapters/eggy/eggy_layer.lua` 内对 `ui:set_label/set_button/set_visible/set_touch_enabled/get_node` 的调用点，并逐一替换为 `UIManager.query_nodes_by_name` 取首个节点后直接设置属性。对图片相关逻辑保留现有 `set_ui_image` 入口，但其内部也改为直接查询节点。确认没有其他模块引用 `ui_state.lua` 后删除该文件与 `require` 引用，更新 `EggyLayer.new` 中 `ui` 的初始化结构，确保保留必要的状态字段（如 `auto_play`、`choice`、`popup`、`item_slots` 等）。

## 具体步骤

在仓库根目录执行以下步骤：

1. 搜索 `ui_state`、`set_label` 等调用点，整理替换清单。  
2. 修改 `src/adapters/eggy/eggy_layer.lua`：  
   - 移除 `require("src.adapters.eggy.ui_state")`。  
   - 将 `ui = UIState.create()` 改为内联构建 `ui` 状态表。  
   - 将所有 `ui:set_*` 调用替换为直接节点查询与属性赋值。  
3. 删除 `src/adapters/eggy/ui_state.lua`，并确认无残留引用。  
4. 运行测试命令并记录输出。

预期命令与输出示例（缩进块示例）：

    cd c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly
    lua tests\deps_check.lua
    lua tests\regression.lua
    Dependency self-check passed
    All regression checks passed (29)

## 验证与验收

运行 `lua tests\deps_check.lua` 与 `lua tests\regression.lua`，两者均通过。功能层面，UI 相关文本、可见性与按钮交互行为与改动前一致，不出现空指针或节点查询失败的报错。

## 可重复性与恢复

修改均为代码层替换，无数据迁移。若出现问题，可通过 `git checkout -- src/adapters/eggy/eggy_layer.lua` 与恢复 `src/adapters/eggy/ui_state.lua` 回滚。测试命令可重复执行，不影响运行环境。

## 产物与备注

完成后产物应包括：  
`src/adapters/eggy/eggy_layer.lua` 修改、`src/adapters/eggy/ui_state.lua` 删除。

    docs/adapters_design.md 已同步为 build_ui_state 直连 UIManager 的描述。

    测试输出：
    Dependency self-check passed
    All regression checks passed (29)

## 接口与依赖

直接使用以下 UIManager 能力：  
- `UIManager.query_nodes_by_name(name)` 返回节点数组  
- 节点属性 `text`、`visible`、`disabled` 直接赋值  
- 需要图片更新时，继续使用现有 `set_image_texture` 逻辑  
依赖文档：`docs/eggy/ui_manager_lib.md`。

附记：初版计划，用于删除 UIState 并直连 UIManager，便于后续按同一逻辑实施。
改动说明：确认 UIState 已清理并补齐文档同步记录，原因是需要与当前实现保持一致。
改动说明：补充测试结果与完成状态，原因是已执行 Lua 测试并需要记录验收结论。
