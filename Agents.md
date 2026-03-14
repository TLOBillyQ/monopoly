# Agent 导读

本项目是**蛋仔派对大富翁**，Lua 5.5，清洁架构七层模型，运行在 Eggy 宿主上。

---

## 文档阅读路径

按任务类型快速定位：

| 任务 | 文档 |
|------|------|
| 理解架构边界与目录语义 | `docs/architecture/boundaries.md` + `docs/architecture/layer-model.md` |
| 理解测试车道、静态分析职责与预估耗时 | `docs/architecture/quality_map.md` |
| 使用静态架构扫描工具 | `docs/architecture/arch_view.md` |
| 查看代码质量报告 | `docs/architecture/crap_report.md`、`docs/architecture/health_signals.md` |
| 跑单文件变异测试 | `docs/architecture/mutate4lua.md` |
| 操作 UI 组件 | `docs/eggy/ui_manager_lib.md` |
| 查宿主 API | `docs/eggy/api/00_index.md`（入口，各类型分文件） |
| 判断代码放哪个子系统 | `docs/architecture/subsystems.md` |

---

## 技能目录

`.agents/skills/` 下有三个可调用技能，新 agent 应按触发时机主动使用：

- **`clean-architecture-reviewer`**：跨层重构或发现边界可疑时调用。检查依赖方向、层级归属与 Port 使用是否符合清洁架构原则。

- **`uncle-bob-reviewer`**：怀疑 SRP/DIP 违反、代码结构混乱时调用。从 Uncle Bob / SOLID 视角做代码审查，输出问题分级与可执行重构方案。

- **`extract-legacy-test`**：需要为无测试的遗留代码补充行为覆盖时调用。针对没有测试夹具的旧代码，提取可观测行为并生成最小测试集。

---

## Harness 指引

- **`PLANS.md`**（`.agents/harness/PLANS.md`）：可执行计划规范。
- **`READING.md`**（`.agents/harness/READING.md`）：按需查代码，不预读整个目录树。
- **`CODING.md`**（`.agents/harness/CODING.md`）：命名与结构规范，新增文件前先读。

---

## 常驻规则

- 命名一律 snake_case。
- `src/` 目录下数值操作遵循 `lua_env.md` 约束：禁用 `tonumber` / `type == "number"`，统一用 `NumberUtils`。
- 记忆文件参见 `lua_agent_memory.md`。
