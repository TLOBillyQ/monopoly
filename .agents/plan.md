# Monopoly 架构可视化文档交付 可执行计划

本可执行计划是活文档。实施过程中必须持续更新"进度"、"意外与发现"、"决策日志"、"结果与复盘"。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。执行者只依赖当前工作树与本文件即可复现实施与验收过程。


## 目的 / 全局视角

本轮目标是为 Monopoly 项目创建一套完整的架构可视化文档，交付到 `docs/arch/` 目录。完成后开发者可以在 `docs/arch/overview.md` 找到全局导航索引，快速定位到各专题文档中的 Mermaid 图表，理解分层架构、启动流程、回合引擎状态机、游戏子系统协作、展示层 Canvas 架构、端到端数据流、模块依赖关系以及配置数据模型。

验收方法：查看 `docs/arch/` 目录，确认 8 个 `.md` 文件存在且包含 Mermaid 图表。在 GitHub 上渲染后可直接浏览图表。回归测试不受影响（纯文档变更）。


## 进度

- [x] (2026-03-02T12:26Z) 完成仓库全面探索：src/app、src/core、src/game、src/presentation、Config/、tests/ 各层结构与职责。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/overview.md — 全局架构总览（分层图 + 组件关系图 + 索引）。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/bootstrap.md — 五阶段启动时序图 + 对象生命周期图。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/turn-engine.md — 协程调度模型 + 回合阶段状态机 + 类图。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/game-systems.md — 10 个子系统组件图 + 阶段协作全景。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/presentation.md — Canvas-First 架构 + 交互分发 + 渲染管线。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/data-flow.md — 端到端数据流 + 帧 tick 流 + 事件流。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/dependencies.md — 层间依赖规则 + 端口适配器模式 + 核心模块依赖图。
- [x] (2026-03-02T12:30Z) 创建 docs/arch/config-data.md — 配置结构 + ER 图 + 数据驱动设计。
- [x] (2026-03-02T12:31Z) 更新 .agents/plan.md 为当前任务计划。
- [ ] 确认回归测试不受影响。
- [ ] 完成 code review 与最终验收。


## 意外与发现

探索过程中确认 TurnEngine 已移除 legacy mode，始终走协程路径。TurnFlow/Flow/TurnChoiceHandler/TurnWaits 等旧模块已删除，只保留协程运行时。这一发现确保了 turn-engine.md 只描述协程模型，不需要描述已退役的传统状态机。

Canvas 画布数量实际为 11 个（含 debug），注册到 CanvasRegistry 的路由规格为 10 个（debug 画布不注册路由）。

docs/architecture/ 已存在一份 presentation_canvas_first.md，本轮在新目录 docs/arch/ 下工作，不修改已有文档。


## 决策日志

决策一：图表格式采用 Mermaid 而非 PlantUML。理由是 GitHub 原生支持 Mermaid 渲染，无需额外工具链。日期/作者：2026-03-02 / Copilot。

决策二：文档交付到 `docs/arch/` 而非覆盖 `docs/architecture/`。理由是 issue 明确要求 `docs/arch/*.md`，且 `docs/architecture/` 已有其他文档，避免冲突。日期/作者：2026-03-02 / Copilot。

决策三：以中文书写文档正文。理由是仓库现有文档（plan.md、backlog.md、注释）均使用中文，保持一致性。日期/作者：2026-03-02 / Copilot。


## 结果与复盘

8 个架构文档已全部交付至 `docs/arch/`，覆盖全局总览、启动序列、回合引擎、游戏子系统、展示层、数据流、模块依赖、配置数据模型。包含 30+ 个 Mermaid 图表，涵盖 graph/flowchart/sequenceDiagram/stateDiagram/classDiagram/erDiagram/mindmap 等多种图表类型。纯文档变更，不影响代码行为与回归测试。


## 背景与导读

Monopoly 是一个用 Lua 编写的大富翁游戏项目，运行在 Eggy 引擎上。项目采用分层架构：基础设施层（`src/core/`）提供运行时上下文与端口注入；游戏逻辑层（`src/game/`）包含核心状态、回合引擎、流程编排与子系统；展示层（`src/presentation/`）基于 Canvas-First 模式组织 UI；应用层（`src/app/`）负责启动与组装；配置层（`Config/`）提供数据驱动的游戏参数。

各文档位于 `docs/arch/` 目录，以 `overview.md` 为索引入口。


## 工作计划

在仓库根目录创建 `docs/arch/` 目录，依次编写 8 个 Markdown 文件。每个文件包含 Mermaid 图表与简要说明文字。完成后运行回归测试确认无副作用，最后提交所有文件。


## 具体步骤

所有命令在仓库根目录 `/home/runner/work/monopoly/monopoly` 执行。

创建目录：

    mkdir -p docs/arch

创建 8 个文档文件（overview / bootstrap / turn-engine / game-systems / presentation / data-flow / dependencies / config-data）。

确认回归测试不受影响：

    lua tests/regression.lua

预期输出包含"All regression checks passed"。


## 验证与验收

验收标准共三条。第一，`docs/arch/` 目录下存在 8 个 `.md` 文件。第二，每个文件包含至少一个 Mermaid 代码块。第三，`lua tests/regression.lua` 全绿。


## 可重复性与恢复

本计划可重复执行。所有操作均为纯文件创建，不修改已有源代码或测试。若需回退，删除 `docs/arch/` 目录即可。


## 产物与备注

交付文件清单：

    docs/arch/overview.md        — 全局架构总览
    docs/arch/bootstrap.md       — 启动序列
    docs/arch/turn-engine.md     — 回合引擎
    docs/arch/game-systems.md    — 游戏子系统
    docs/arch/presentation.md    — 展示层架构
    docs/arch/data-flow.md       — 数据流
    docs/arch/dependencies.md    — 模块依赖关系
    docs/arch/config-data.md     — 配置与数据模型


## 接口与依赖

本轮不改动任何源代码或测试，仅新增文档文件。无新增库依赖。

本次修订说明（2026-03-02T12:31Z）：初始版本，完整创建架构可视化文档交付计划。
