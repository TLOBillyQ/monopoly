---
kind: guide
status: draft
owner: quality
last_verified: 2026-05-16
---

# 中文 Gherkin 规格约定

本仓库的业务验收规格以中文为人工编辑源。业务人员不需要理解英文 Gherkin 关键字，也不需要维护工具生成的英文或 ASCII 中间产物。规格工具负责把中文源文件归一化为 APS 兼容格式，再生成可执行验收测试。

## 人工编辑源

人工编辑源放在 `features/` 下，文件扩展名为 `.feature`，文件首行写 `# language: zh-CN`。业务人员只写中文关键字、中文步骤、中文场景名和中文例子表头。

本仓库只接受这一组中文关键字：

| 用途 | 关键字 |
|------|--------|
| 功能 | `功能:` |
| 背景 | `背景:` |
| 场景 | `场景:` |
| 场景大纲 | `场景大纲:` |
| 例子 | `例子:` |
| 前置条件 | `假如` |
| 触发动作 | `当` |
| 结果断言 | `那么` |
| 继续描述 | `并且` |
| 反向描述 | `但是` |

官方 Gherkin 还提供其他中文同义词，例如 `假设`、`假定`、`剧本`。本仓库暂不接受这些同义词，因为协作文本需要统一表达。若以后确实需要新增同义词，应先扩展本指南和对应验收规格。

## 归一化规则

工具读取中文源文件后，生成 APS 兼容中间格式。中间格式只能使用 `Feature`、`Background`、`Scenario`、`Scenario Outline`、`Examples`、`Given`、`When`、`Then` 和 `And`。中间格式是生成产物，不能作为人工编辑源提交。

中文关键字按下列规则归一化：

| 中文关键字 | APS 关键字 |
|------------|------------|
| `功能:` | `Feature:` |
| `背景:` | `Background:` |
| `场景:` | `Scenario:` |
| `场景大纲:` | `Scenario Outline:` |
| `例子:` | `Examples:` |
| `假如` | `Given` |
| `当` | `When` |
| `那么` | `Then` |
| `并且` | `And` |
| `但是` | `And` |

本仓库按 `swarmforge/tools.lock` 钉定的 `acceptance4lua` 参考实现把中文参数名保留为规范名。中文源文件里的 `<玩家>`、`<已有道具数>` 会在 IR 中继续表示为 `玩家`、`已有道具数`，并在 source metadata 中保留字段名与行号。这样 step handler、诊断信息和变异报告都直接使用业务可读字段，不再生成 `p1`、`p2` 这类中间名。

例子表头也按同一套字段名处理。若步骤里出现 `<已有道具数>`，例子表中必须存在 `已有道具数` 列，且再次解析应得到相同字段名。

## 诊断与报告

工具错误必须回指中文源文件，至少包含文件路径、源文件行号和中文字段名。错误信息不能只显示历史兼容用的 `p1`、`p2` 这类中间名。

变异测试报告面向规格审查时，也应显示中文字段名。例如报告应写成“`已有道具数: 5 -> 8`”，而不是只写“`p2: 5 -> 8`”。工具内部可以保留 JSONPath，但用户可见输出必须能映射回中文。

## 工具边界

通用框架由 `swarmforge/tools.lock` 钉定的 `acceptance4lua` 参考实现提供，wrapper 按需 bootstrap 到 `.swarmforge/tools/acceptance4lua@<sha>/` 后直接加载 `acceptance4lua.*` 模块。本仓库不再保留 `tools/acceptance/*` 通用 facade；`acceptance.*` 仅作为 Monopoly 业务 step 命名空间。

Monopoly 专属的 step handlers、`game_driver.lua`、runner adapter、`run_acceptance.lua` 和根部命令 wrapper 仍留在本仓库。项目对外暴露的 APS 命令入口是 `gherkin-parser`、`acceptance-entrypoint-generator` 和 `gherkin-mutator`；`acceptance-run` 与 `acceptance-mutate` 是项目便捷入口。

## SwarmForge 迁移边界

SwarmForge 的可提交资产和本地运行状态必须分开。`swarmforge/` 存放 `roles/`、`constitution/` 和 `swarmforge.conf`，属于可提交迁移资产。`swarmforge/scripts/` 由 SwarmForge 启动时按上游 `main` 下载，属于本地运行状态，不提交。

`.swarmforge/`、`.worktrees/`、`swarmforge/scripts/`、`agent_context/` 是本地运行状态，不应提交。`logs/` 默认本地（`logs/agent_messages.log` 等），但 architect 的跨周期 Gherkin survivor 基线（`logs/gherkin-survivors-*.txt`）通过 `.gitignore` 反向白名单可提交。交接消息必须按 `swarmforge/constitution/articles/handoffs.prompt` 的 daemon handoff 规则发送。
