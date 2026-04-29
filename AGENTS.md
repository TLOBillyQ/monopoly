# 导读

**蛋仔派对大富翁** — Lua 5.5，清洁架构十层，Eggy 宿主。按任务查文档，不预读目录树。

---

## 按任务找文档

| 任务 | 文档 |
|------|------|
| 架构边界与目录 | `docs/architecture/boundaries.md` + `layer-model.md` |
| 架构治理路线图 | `docs/architecture/governance_roadmap.md` |
| 测试车道与质量职责 | `docs/architecture/quality_map.md` |
| 静态架构扫描 | `docs/architecture/arch_view.md` |
| 风险热点（CRAP） | `docs/architecture/crap_report.md`、`health_signals.md` |
| 语义导航（SCRAP） | `docs/architecture/scrap4lua.md` |
| 代码量趋势（LOC） | `lua tools/quality/loc.lua` |
| 编码与花式标点检查 | `lua tools/quality/encoding.lua check` |
| 行为测试 warn 判读 | `docs/architecture/behavior_warns.md` |
| 变异测试 | `docs/architecture/mutate4lua.md` |
| UI 组件 | `docs/eggy/guide/ui_manager.md` |
| 宿主 API | `docs/eggy/api/00_index.md` |
| 子系统归属 | `docs/architecture/subsystems.md` |
| 记忆文件 | `docs/eggy/agent/memory.md` |
| 可执行计划规范 | `.agents/harness/PLANS.md` |
| 按需读代码（不预读目录树） | `.agents/harness/READING.md` |
| 命名与新增文件规范 | `.agents/harness/CODING.md` |

---

## 技能目录

`.agents/skills/` 下按需调用：

- **`clean-architecture-reviewer`**：跨层重构或边界可疑时
- **`uncle-bob-reviewer`**：SRP/DIP 违反或结构混乱时
- **`quality/`**：质量检查流水线
- **`debug/`**：bug 或测试失败时
- **`explain-code/`**：解释代码逻辑

---

## 常驻规则

- 命名 `snake_case`，类名 `CamelCase`。
- `src/` 禁用 `tonumber` / `type == "number"`，用 `NumberUtils`（`src.core.utils.number`）。
- `tools/` `tests/` 文件与进程操作统一用 `tools/shared/lib/common.lua`：
  - `common.run_command` / `common.ensure_dir`（禁 `os.execute` / `io.popen`）
  - `common.is_windows()` / `common.is_macos()`（禁解析 `package.config`）
  - `common.normalize_path()`（路径正斜杠，禁硬编码反斜杠）
  - `common.shell_quote()` + `common.build_command()`（禁手动拼接命令）
- Eggy `Fixed` 参数用浮点（`30.0`），禁整数；API 参数写全，禁依赖默认值。
- 合约/烟测写在 `spec/contract/*_spec.lua`（busted runner，见 `.busted` 与 `spec/helper.lua`）；`tests/` 保留 behavior/guard/regression/catalog/tooling 老 harness。**不要再写 `tests/contract.lua` 风格**。

---

## 变更验证

> busted 2.x 用 `--run <profile>` 选 profile，`-c` 是 coverage 开关。

| 变更类型 | 命令 |
|---------|------|
| 任意 Lua | `lua tools/quality/lint.lua` |
| 游戏逻辑 / 运行时 / UI | `busted --run behavior` |
| Port / 边界 / assembly | `busted --run contract` + `lua tools/quality/arch.lua check` |
| Guardrail | `busted --run guards` |
| 工具链 | 追加 `busted --run tooling` |

快速车道用 `/verify-fast`，完整车道用 `/verify-full`。跳过慢车道时说明：已跑什么、跳过什么、下一步命令。
