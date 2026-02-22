# 纹理接口语义重构执行计划（keep_size / native_size）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”四个章节。本文件遵循 `.github/PLANS.md`。

## 目的 / 全局视角

本次改动只解决纹理接口语义混乱问题，不改变业务行为。完成后，表现层只保留两种清晰语义：`keep_size`（保持节点尺寸）与 `native_size`（按贴图原始尺寸重置节点）。用户侧可见结果是：现有 UI 行为不变，但接口名和调用点更可读，后续排查缩放问题不再被 `auto_size` 命名误导。

## 进度

- [x] (2026-02-22 04:21Z) 清空并重建 `PLAN_CURRENT.md`，写入本次执行计划。
- [x] (2026-02-22 04:24Z) 在 `UIRuntimePort` 新增 `set_node_texture_native_size`，并将 `set_node_texture_auto_size` 改为兼容别名 + warn once。
- [x] (2026-02-22 04:24Z) 迁移 `presentation` 调用点：`PopupRenderer` 改用 `native_size`，`MarketView` 删除本地纹理 helper 并统一走 runtime。
- [x] (2026-02-22 04:24Z) 补充/更新 `presentation_ui` 套件与切片注册，覆盖新接口语义与兼容告警。
- [x] (2026-02-22 04:24Z) 运行 `rg` 校验剩余 `auto_size` 调用点并执行 `lua .github/tests/regression.lua` 全量回归。
- [x] (2026-02-22 04:24Z) 更新“结果与复盘”与“产物与备注”证据。
- [x] (2026-02-22 04:27Z) 第二阶段完成：删除 `set_node_texture_auto_size` 兼容别名与对应测试，`auto_size` 在 `src` 与 `.github/tests` 零命中。

## 意外与发现

- 观察：`UIRuntimePort.set_node_texture_auto_size` 当前行为实际优先走 `set_texture_native_size`，命名与行为不一致。
  证据：`src/presentation/api/UIRuntimePort.lua`。

- 观察：`MarketView` 维护了本地 `_set_node_texture_keep_size`，与 runtime 回退策略重复。
  证据：`src/presentation/render/MarketView.lua`。

- 观察：`presentation_ui_registry` 原有名称表缺失 `_test_choice_route_policy_prefers_explicit_route_metadata`，会导致后续索引名称错位；本次已补齐，避免新增测试后错位扩大。
  证据：`.github/tests/suites/presentation_ui_registry.lua`。

## 决策日志

- 决策：采用 `keep_size` / `native_size` 作为唯一语义名，不再新增第三种抽象命名。
  理由：直接镜像底层 `EImage` 语义，减少解释成本。
  日期/作者：2026-02-22 / Codex。

- 决策：按第二阶段计划删除 `set_node_texture_auto_size` 兼容别名与告警测试。
  理由：所有调用点已迁移到 `set_node_texture_native_size`，继续保留别名会延长语义歧义。
  日期/作者：2026-02-22 / Codex。

## 结果与复盘

本轮已完成两阶段重构：先引入 `native_size` 并迁移调用点，再删除 `auto_size` 兼容层。当前表现层纹理接口仅保留 `keep_size` 与 `native_size` 两个语义名。回归结果全绿，未引入行为回退。

关键结果：

- 表现层纹理语义统一为两类：`keep_size` 与 `native_size`。
- `PopupRenderer` 的破产头像路径改为显式 `native_size`。
- `MarketView` 删除本地纹理 helper，统一复用 `UIRuntimePort` 回退策略。
- 补齐 runtime texture 行为测试与 popup native 路径测试，并修正 suite 切片范围。

## 背景与导读

关键模块如下：

- `src/presentation/api/UIRuntimePort.lua`：表现层统一运行时端口，负责纹理设置的回退策略。
- `src/presentation/ui/PopupRenderer.lua`：弹窗图片渲染，破产头像路径依赖“重置尺寸”语义。
- `src/presentation/render/MarketView.lua`：黑市卡片与稀有度框渲染，目前有本地纹理 helper。
- `.github/tests/suites/presentation_ui.lua`：表现层回归主套件。
- `.github/tests/suites/presentation_ui_registry.lua` 与 `.github/tests/suites/presentation_ui_action_status.lua`：测试名映射与切片范围。

## 工作计划

先收敛接口层，再迁移调用点，最后补测试和回归。整个过程坚持“命名重构不改行为”：每个调用点保持原先缩放语义，仅替换到更准确的函数名或统一入口。测试上新增接口优先级与兼容告警覆盖，避免未来误改回退顺序。

## 具体步骤

1. 修改 `src/presentation/api/UIRuntimePort.lua`：
   - 新增 `set_node_texture_native_size(node, image_key)`；
   - 第二阶段删除 `set_node_texture_auto_size` 兼容别名与相关告警逻辑。

2. 修改调用点：
   - `src/presentation/ui/PopupRenderer.lua`：`set_node_texture_auto_size` -> `set_node_texture_native_size`；
   - `src/presentation/render/MarketView.lua`：删除本地 `_set_node_texture_keep_size`，改用 runtime 端口。

3. 更新测试：
   - 在 `.github/tests/suites/presentation_ui.lua` 新增 runtime texture 语义测试与 popup native 路径测试；
   - 第二阶段删除 auto_size 兼容告警测试；
   - 若新增/删除测试导致序号变化，更新 registry 与 action_status 切片范围。

4. 执行验证命令（仓库根目录）：

    rg -n "set_node_texture_auto_size" src .github/tests
    lua .github/tests/regression.lua

## 验证与验收

验收标准：

- `rg -n "set_node_texture_auto_size" src .github/tests` 结果零命中。
- `lua .github/tests/regression.lua` 全绿。
- `PopupRenderer`、`MarketView`、`UIPanelPresenter` 语义分别保持：popup 破产头像 native-size、市场与基础屏头像 keep-size。

## 可重复性与恢复

本次为语义重构，不涉及存档与配置迁移。若回归失败，可按模块回退：优先回退调用点迁移（`PopupRenderer`/`MarketView`），保留 `UIRuntimePort` 的 `native_size` 主接口，缩小排查面。

## 产物与备注

变更文件：

- `.github/PLAN_CURRENT.md`
- `src/presentation/api/UIRuntimePort.lua`
- `src/presentation/ui/PopupRenderer.lua`
- `src/presentation/render/MarketView.lua`
- `.github/tests/suites/presentation_ui.lua`
- `.github/tests/suites/presentation_ui_registry.lua`
- `.github/tests/suites/presentation_ui_action_status.lua`

关键输出摘要：

    rg -n "set_node_texture_auto_size" src .github/tests
    (无输出)

    lua .github/tests/regression.lua
    ......................................................................................................................................................
    All regression checks passed (150)
    dep_rules ok
    tick ok

## 接口与依赖

不新增外部依赖。内部纹理接口统一为：
- `runtime_port.set_node_texture_keep_size(node, image_key)`
- `runtime_port.set_node_texture_native_size(node, image_key)`

本次更新说明：已将计划从“待执行”状态更新为“已执行完成”，补充了实际变更文件、验证输出与一条新增发现（测试注册名缺失），目的是保证该计划作为活文档可独立复现与审计。
