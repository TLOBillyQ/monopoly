# 导读

**蛋仔派对大富翁** — Lua 5.5，清洁架构七层，运行在 Eggy 宿主上。不要预读目录树，按任务查文档。

---

## 按任务找文档

| 任务 | 文档 |
|------|------|
| 架构边界与目录语义 | `docs/architecture/boundaries.md` + `docs/architecture/layer-model.md` |
| 测试车道与质量职责 | `docs/architecture/quality_map.md` |
| 静态架构扫描工具 | `docs/architecture/arch_view.md` |
| 代码质量报告 | `docs/architecture/crap_report.md`、`docs/architecture/health_signals.md` |
| 变异测试 | `docs/architecture/mutate4lua.md` |
| UI 组件操作 | `docs/eggy/guide/ui_manager.md` |
| 宿主 API 查询 | `docs/eggy/api/00_index.md` |
| 代码放哪个子系统 | `docs/architecture/subsystems.md` |
| 记忆文件 | `docs/eggy/agent/memory.md` |

---

## 技能目录

`.agents/skills/` 下可调用技能，按触发时机主动使用：

- **`clean-architecture-reviewer`**：跨层重构或边界可疑时。检查依赖方向、层级归属与 Port 使用。
- **`uncle-bob-reviewer`**：怀疑 SRP/DIP 违反或结构混乱时。输出问题分级与可执行重构方案。
- **`quality/`**：需要运行质量检查流水线时。
- **`debug/`**：遇到 bug 或测试失败时，系统性调试流程。
- **`explain-code/`**：需要解释代码逻辑时。

---

## Harness 指引

- **`PLANS.md`** (`.agents/harness/PLANS.md`)：可执行计划规范。
- **`READING.md`** (`.agents/harness/READING.md`)：按需查代码，不预读整个目录树。
- **`CODING.md`** (`.agents/harness/CODING.md`)：命名与结构规范，新增文件前先读。

---

## 常驻规则

- 命名一律 `snake_case`，类名用 `CamelCase`。
- `src/` 内禁用 `tonumber` / `type == "number"`，统一用 `NumberUtils`（`src.core.utils.number_utils`）。
- `src/` canonical 命名硬切，不保留 alias/shim 兼容文件。
- `tools/` 和 `tests/` 的文件系统与进程操作统一用 `tools/shared/lib/common.lua`（`common.run_command`、`common.ensure_dir` 等），禁止直接调用 `os.execute` / `io.popen`。
- OS 分支检测用 `common.is_windows()` / `common.is_macos()`，禁止解析 `package.config` 或 `os.getenv`。
- 路径一律正斜杠，通过 `common.normalize_path()` 处理；禁止硬编码反斜杠。
- 拼接外部命令用 `common.shell_quote()` + `common.build_command()`，禁止手动字符串拼接。
- 新增脚本必须支持 Windows + macOS，禁止新增仅限单平台的 `.sh`-only 脚本。
- Eggy `Fixed` 类型参数必须用浮点字面量（`30.0`），禁止传整数（`30`）。
- 调用 Eggy API 参数必须按文档写全，禁止依赖默认值；`set_model_by_*` 等带 `include_*` / `inherit_*` 标志位的方法尤其注意。
- 保持小步提交；执行 `.agents/plan.md` 目标时结束前不要停下来。

---

## 变更验证

| 变更类型 | 命令 |
|---------|------|
| 任意 Lua 编辑 | `lua tools/quality/lint.lua`（需 luacheck） |
| 游戏逻辑 / 运行时 / UI | `lua tests/behavior.lua` |
| Port / 边界 / assembly / read-model | `lua tests/contract.lua` + `lua tools/quality/arch.lua check` |
| Guardrail / 禁止模式 | `lua tests/guard.lua` |
| `tools/quality/*` 或工具链集成 | 额外运行 `lua tests/tooling.lua` |

跳过慢车道时，需说明已跑什么、跳过什么、下一步推荐命令。
