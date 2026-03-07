# 目录层级优化计划（保守收敛版）

## 摘要

- 目标是在**不改变现有 7 组件分层与 5 个顶层命名空间**的前提下，收敛 `src` 与 `tests` 的目录语义，解决当前 `runtime / adapter / service / ports / shared` 多轴混排带来的认知和迁移成本。
- 外部依据采用 [Lua 5.4 手册（`require` / `package.searchers` / `package.path`）](https://www.lua.org/manual/5.4/manual.html#pdf-require) 与 [LuaRocks rockspec `build.modules` 约定](https://github.com/luarocks/luarocks/blob/main/docs/rockspec_format.md)。据此拍板：**Lua 目录应优先服务稳定模块命名空间，而不是堆叠技术标签；同一层内只按一个主轴分组**。
- 当前迁移热点已确认：`src.presentation.adapter` 约 107 处引用，`src.game.systems.market.service` 约 47 处，`src.core.runtime_facade` 约 38 处，`src.presentation.canvas_runtime` 约 14 处，`src.game.turn_engine` 约 5 处；因此顺序必须是**低爆点先、`presentation` 最后**。
- 默认保持 `main.lua` 与 `src.app.init` 入口语义不变；实施时一次性更新内部 `require`，**不保留长期兼容 shim**。
- 现有基线可用：`lua tests\\regression.lua` 已在当前树上通过，377 项回归 + `dep_rules` + `forbidden_globals` 为本次重组护栏。

## 关键变更

- 顶层保持不变：`src.app`、`src.core`、`src.game`、`src.infrastructure`、`src.presentation` 不跨层重包，不做 feature-first 穿层目录。
- `app` 层统一启动期 runtime 命名：
  - 将 `runtime_install.lua` 与 `runtime_install/` 目录收敛为单一命名空间 `src.app.bootstrap.runtime.*`。
  - 目标语义是：`install` 为装配入口，`port_defaults` / `global_aliases` 为安装细节，`payment` 继续留在 bootstrap 外围装配侧。
- `core` 层澄清“状态访问”与“宿主 runtime”：
  - `src.core.runtime_facade.*` 改为 `src.core.state_access.*`。
  - 原因是该目录实际承载 `state` / `ui_runtime` 薄访问层，不是宿主 runtime；继续叫 `runtime_facade` 会与 `src.game.core.runtime`、`src.infrastructure.runtime` 冲突。
- `game` 层收敛历史与应用子目录：
  - `src.game.turn_engine.*` 迁到 `src.game.legacy.turn_engine.*`，明确“冻结历史容器”身份，禁止新增调用方。
  - `src.game.systems.market.service.*` 改为 `src.game.systems.market.application.*`，表达它是用例编排，不是通用 service 垃圾桶。
  - `src.game.systems.land.config.*` 改为 `src.game.systems.land.specs.*`。
  - `src.game.systems.commerce.config.runtime_paid_goods.lua` 改为 `src.game.systems.commerce.specs.paid_goods.lua`；本阶段只做目录语义收敛，不跨层挪到 `infrastructure`。
- `presentation` 层按 4 个稳定职责面收敛：
  - `input`：承接现 `interaction`。
  - `model`：承接现 `state` + `read_model`。
  - `view`：承接现 `canvas` + `widgets` + `render`。
  - `runtime`：承接现 `adapter` + `canvas_runtime` + 运行时桥接类 shared。
- `presentation/shared` 逐文件拍板，不保留“shared 大杂烩”：
  - `market_layout`、`player_colors`、`ui_aliases` 进入 `view.support`。
  - `ui_events` 进入 `runtime`，因为它直接依赖 `Data.UIManagerNodes` 与 `role.send_ui_custom_event`。
- `tests` 仅做保守镜像：
  - 保留 `tests\\regression.lua`、`tests\\TestHarness.lua`、`tests\\TestSupport.lua`。
  - 现有 `tests\\suites` 从扁平文件改为 namespaced 分组：`architecture`、`domain`、`gameplay`、`presentation`、`runtime`。
  - `tests\\internal` 本阶段保持平铺，只新增旧路径扫描与 require 路径契约，不额外拆层。

## 任务图

- **T0** `[depends_on: []]` 将本计划落到 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\plan.md`，格式严格对齐 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\.agents\harness\PLANS.md`；附当前→目标模块映射表与迁移日志模板。
- **T1** `[depends_on: [T0]]` 先建护栏，不先搬代码：
  - 给 `tests\\regression.lua` 增加 suite manifest 或 namespaced suite 加载方式，支持子目录套件。
  - 新增“旧路径残留”检查，至少覆盖：`src.core.runtime_facade`、`src.game.turn_engine`、`src.presentation.adapter`、`src.presentation.canvas_runtime`、`src.game.systems.market.service`、`src.app.bootstrap.runtime_install`。
  - 验证：护栏在旧路径仍存在时能准确报错，且不会误伤 `vendor` / `Config` / `Data`。
- **T2** `[depends_on: [T1]]` 先做低爆点重命名：
  - `src.core.runtime_facade.*` → `src.core.state_access.*`
  - `src.game.turn_engine.*` → `src.game.legacy.turn_engine.*`
  - `src.game.systems.market.service.*` → `src.game.systems.market.application.*`
  - `src.game.systems.land.config.*` → `src.game.systems.land.specs.*`
  - `src.game.systems.commerce.config.runtime_paid_goods.lua` → `src.game.systems.commerce.specs.paid_goods.lua`
  - 验证：上述旧前缀在 `src` / `tests` 中清零，`architecture_guard_contract`、`cross_module_contract`、`usecase_boundary_contract` 通过。
- **T3** `[depends_on: [T1]]` 统一 `app.bootstrap.runtime` 命名空间：
  - 把 `runtime_install.lua` 与 `runtime_install/` 合并为 `src.app.bootstrap.runtime.*`。
  - 保持 `src.app.init` 的对外入口职责不变，只更新内部 require。
  - 验证：`runtime_bootstrap`、`startup_release`、`runtime_ports_contract` 相关套件通过。
- **T4** `[depends_on: [T2, T3]]` 重组 `presentation`：
  - `interaction` → `input`
  - `state` + `read_model` → `model`
  - `canvas` + `widgets` + `render` → `view`
  - `adapter` + `canvas_runtime` + `shared.ui_events` → `runtime`
  - `shared.market_layout` / `player_colors` / `ui_aliases` → `view.support`
  - 只改目录与 require，不顺手改行为逻辑；任何边界修补仅限导入方向修正。
  - 验证：`presentation_ui_*`、`read_model_contract`、`ui_gate_contract`、`ui_runtime_state_contract` 全绿，且 `dep_rules` 无新增豁免。
- **T5** `[depends_on: [T4]]` 重组测试目录：
  - 将 `tests\\suites` 按 `architecture / domain / gameplay / presentation / runtime` 分组。
  - `tests\\regression.lua` 改为从 suite manifest 加载，不再依赖扁平短名 `require("chance")` 这类隐式路径。
  - 保留 `tests\\internal` 作为脚本式护栏目录，并把旧路径扫描接入回归尾部。
  - 验证：回归覆盖范围与迁移前一致；suite 总量不减少；失败时能定位到新 namespaced suite。
- **T6** `[depends_on: [T5]]` 做最终清场：
  - 运行完整 `lua tests\\regression.lua`。
  - 清掉所有 stale require、遗漏的 package 路径、suite manifest 漏项。
  - 更新 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\docs\architecture\boundaries.md` 与 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly\docs\architecture\layer-model.md` 中涉及目录示例的文字，使文档与新树一致。
  - 验证：377 项回归仍通过；`dep_rules ok`；`forbidden_globals ok`；文档中不再出现退役目录名。

## 测试与验收

- 必跑总验收：`lua tests\\regression.lua`
- 必查旧路径清零：
  - `src.core.runtime_facade`
  - `src.game.turn_engine`
  - `src.presentation.adapter`
  - `src.presentation.canvas_runtime`
  - `src.game.systems.market.service`
  - `src.app.bootstrap.runtime_install`
- 必查边界不退化：
  - `architecture_guard_contract`
  - `usecase_boundary_contract`
  - `cross_module_contract`
  - `runtime_ports_contract`
  - `ui_runtime_state_contract`
- 必查关键业务场景未坏：
  - 黑市选择与分页
  - 选择弹窗 / 远端选择 / 二次确认
  - turn dispatch 与 gameplay loop 的 UI dirty 流
  - bankruptcy / land event / action anim 桥接

## 假设与默认值

- 这次只整理 `src` 与 `tests`；`Config`、`Data` 物理目录不动。
- 不做永久兼容层；所有内部 `require` 在同一批次改完。
- 不借“目录优化”顺手修改玩法规则、Port 契约形状或 UI 行为；行为变化视为越界。
- `presentation` 允许一次性大规模路径替换，但不允许新增从 `presentation` 指向 `game.systems` 的直接依赖。
- `game.legacy.turn_engine` 迁入后仅作为历史兼容容器保留，不允许新模块继续引用。
