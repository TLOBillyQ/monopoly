# 下一步行动建议（2026-03-08）

> 本文档替换原“代码库现状研究报告”，仅保留后续行动建议。
> 当前原则：**先修边界与重复编排，再追求行数下降；先做增量拆分，再做统一命名。**

## 架构健康度摘要

- 当前代码库的主要风险不再是 legacy 路径残留，而是 **UI 编排层重复逻辑** 与 **Choice 契约边界不够强**。
- 接下来的动作应从“目录迁移 / 继续降行”切换到“热点模块内聚化 + 边界前移校验”。
- 以 Clean Architecture 视角看，近期最值得投入的改造点，是让 `presentation` 只负责投影与编排，让 `choice` 在进入运行态之前就完成契约化约束。

## 已确认的前提

- `src/presentation/view/support/` 已经具备可复用基础模块，不再把“新建 support 目录”作为近期目标。
  - 已存在：`src/presentation/view/support/ui_controls.lua`
  - 已存在：`src/presentation/view/support/effect_timeline.lua`
  - 已存在：`src/presentation/view/support/market_layout.lua`
- `active_tab`、`page_index`、`page_count` 已是显式字段，不应再重复推动“从 `meta` 中提出分页状态”。
  - 相关位置：`src/core/choice/choice_contract.lua`
  - 相关位置：`src/game/systems/market/application/choice_session.lua`
- `choice.meta` 并非零约束状态；现有系统已经支持 `required_meta` 校验。下一步应做“强化”，而不是另起一套重型 schema 体系。
  - 相关位置：`src/game/flow/intent/intent_dispatcher.lua`
  - 相关位置：`src/game/systems/choices/choice_registry.lua`

## P1：本周必须执行

### 1. 拆分 `market_view`，把 UI 编排和槽位渲染分开

**目标**

- 让 `src/presentation/view/render/market_view.lua` 保留公开入口与薄编排。
- 把“槽位渲染 / 选中态 / 分页和页签控制”拆成更小模块，减少单文件条件分支和重复 UI 状态设置。

**建议拆分方向**

- `market_view.lua`：只保留 `refresh_market_selection`、`select_market_option`、`refresh_market`、`close_market_panel` 的流程编排。
- 新增一个槽位渲染模块：负责 `_set_market_slot_visible`、`_set_market_slot`、`_refresh_market_selection_frames` 一类逻辑。
- 新增一个控制器模块：负责分页、页签、取消按钮、确认按钮等通用控件状态。

**边界要求**

- 不改变现有调用入口。
- 不把业务规则回流进 `presentation`。
- 保持对 `ui_controls`、`market_layout` 的复用，不重造 helper。

**验收标准**

- `src/presentation/view/render/market_view.lua` 明显降薄。
- 市场弹窗的选择、翻页、页签切换行为保持不变。
- 相关回归继续通过：`tests/suites/presentation/presentation_ui.lua`。

### 2. 拆分 `ui_panel_presenter`，压缩重复布局逻辑

**目标**

- 让 `src/presentation/view/widgets/ui_panel_presenter.lua` 回到“入口 presenter”角色，不再同时承担玩家槽位渲染、现金变化提示、角色视图刷新三类职责。

**建议拆分方向**

- 提取玩家槽位渲染模块：负责名称、现金、地产数、总资产、头像。
- 提取现金变化模块：负责 cash delta 状态、显示、延迟隐藏。
- 如仍偏大，再单独提取 role view 渲染模块。

**边界要求**

- `refresh()` 继续作为稳定入口。
- `role_context`、`player_colors` 等既有协作者保持不变。
- 不新增跨层依赖，不让 `presentation` 直接依赖 `game/flow` 或 `game/systems`。

**验收标准**

- `ui_panel_presenter.lua` 只剩入口编排和少量组装逻辑。
- 玩家面板视觉行为不变。
- 相关回归继续通过：`tests/suites/presentation/presentation_ui.lua`。

### 3. 强化 Choice descriptor 契约，而不是引入重量级 schema

**目标**

- 把 Choice 的错误尽量前移到“打开 choice 时”或“注册 descriptor 时”暴露，而不是在 handler 深处用 `assert(meta.xxx)` 才炸。

**建议动作**

- 在现有 `required_meta` 基础上，为 descriptor 增加轻量扩展点：
  - `meta_validator(meta, choice_spec)`
  - `normalize_meta(meta, choice_spec)`（可选）
  - `normalize_action(action, choice)`（可选）
- 第一批只覆盖高频路径：
  - `market_buy`
  - item choice 系列
  - `landing_optional_effect`

**边界要求**

- 不引入独立 JSON Schema 框架。
- 不为“形式完整”牺牲当前测试可维护性。
- Descriptor 仍然围绕用例组织，不把 UI 细节带入 `game/systems/choices/`。

**验收标准**

- 非法 `meta` 的失败位置前移，错误信息更具体。
- 关键 choice kind 具备针对性测试。
- `choice_resolver` 继续保持薄协调者角色。

## P2：两周内推进

### 4. 做一次 `choice.meta` 审计，只提升真正跨层稳定的字段

**目标**

- 控制 `meta` 继续口袋化，但避免把所有 kind-specific 数据都错误提升为显式字段。

**筛选标准**

- 满足以下条件之一，才考虑提升为显式字段：
  - 跨多个 choice kind 复用
  - 被 `presentation` / `flow` / timeout policy 等外层通用消费
  - 属于路由、确认、拥有者、分页这类通用 UI/runtime 语义

**不提升的内容**

- 单个玩法专用 payload
- 单个 handler 内部消费的数据
- 只为减少 `meta.xxx` 书写而提出的字段

**落点建议**

- 统一收敛到 `src/core/choice/choice_contract.lua`
- 由 `intent_dispatcher` 负责复制显式字段，避免多处分散拷贝

### 5. 固化 Port 命名规则，但不做一次性大迁移

**目标**

- 解决“`*_port.lua` / `*_ports.lua` / `*_adapter.lua` 混用”带来的认知成本。

**规则**

- 单一契约：`*_port.lua`
- 成组 bundle：`*_ports.lua`
- 适配器实现：`*_port_adapter.lua`

**执行方式**

- 先写清规则，再在“触碰到相关文件时”顺手收敛。
- 不做大规模 rename，不为了命名统一而制造额外 churn。

**说明**

- `src/game/flow/turn/gameplay_loop_ports.lua` 和 `src/presentation/runtime/presentation_ports.lua` 这类文件，本质上是 port group / bundle，不应按单 port 规则硬改。

## P3：本月内观察项

### 6. 重新定义健康指标，弱化纯 LOC 导向

后续跟踪不再以“继续净减多少行”为主，而以以下指标为主：

- `dep_rules` 持续为零违例
- Choice 关键路径测试完整度
- UI 热点文件是否回到薄入口 + 小模块组合
- 新增代码是否遵守 `docs/architecture/boundaries.md`

可保留的辅助指标：

- 热点文件数量
- `src/` 月度净增长
- 回归测试通过率

### 7. `output_adapters/` 先文档化，不急于迁目录

**判断**

- 当前 `src/game/flow/output_adapters/` 只有少量文件，体量不大。
- 它更像 turn use case 本地输出桥，而不是必须立刻迁走的架构污染源。

**建议**

- 先补说明文档或命名注释，明确它服务于 turn 编排。
- 等 Choice 和 UI 热点收敛后，再决定是否迁出或重命名。

## 当前明确不做

- 不把 `src/presentation/view/render/board_feedback_service.lua` 作为近期优先拆分对象。
  - 原因：职责单一、API 面稳定、已有较多调用与测试覆盖。
- 不再把“提取 `presentation/view/support/` 公共模块”列为新目标。
  - 原因：关键 support 模块已经存在。
- 不做全仓 Port 批量重命名。
  - 原因：收益低于 churn 成本。
- 不围绕 `choice.meta` 新增独立重型 schema 运行时。
  - 原因：现阶段更适合渐进式 descriptor 契约强化。

## 推荐执行顺序

### 第 1 周

1. 拆 `market_view`
2. 拆 `ui_panel_presenter`
3. 为 `market_buy` 加 descriptor 契约强化和测试

### 第 2 周

1. 扩展 item choice / `landing_optional_effect` 的 descriptor 契约
2. 做 `choice.meta` 审计，更新 `choice_contract`
3. 补 Port 命名规则说明

### 第 3 周及以后

1. 观察 UI 热点是否继续收敛
2. 评估 `output_adapters/` 是否需要改名或迁位
3. 建立以边界和测试为核心的健康指标面板

## 最终目标

- `presentation` 只保留投影与薄编排，不继续积累“半业务半 UI”的混合模块。
- `choice` 在进入运行态前就具备明确契约，减少 handler 深处的防御式断言。
- Port / Adapter / Port Bundle 的语义和命名逐步稳定，降低目录认知成本。
- 代码库后续演进优先围绕边界清晰度与可测试性，而不是单纯追求更小的行数。
