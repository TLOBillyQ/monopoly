---
name: arch-view
description: 用 arch_view 校验模块边界 / 循环依赖，或打开依赖图 viewer。触发：架构扫描、循环依赖、边界校验、依赖图。不用于：pipeline 跑场（走 /verify）、文本护栏（走 spec/guards/）。
---

# Arch-View

静态架构扫描。校验模块依赖边界、循环、视图聚合。

## 何时用 / 何时不用

- 用：改了跨层接口、端口、装配；新增模块前看归属；调试循环依赖；导出 viewer 给评审
- 不用：管道批量跑（用 `/verify` 或 `/verify --smoke`，二者均内含 `arch.lua check`）；替代文本护栏（那是 `spec/guards/lib/dep_rules.lua` 等的工作）

## 决策树

1. **边界 gate** → `lua tools/quality/arch.lua check`
   扫 `src/`，违规非零退出。无白名单。
2. **看图理解** → `lua tools/quality/arch.lua`（无参数 = 打开默认 viewer）
3. **导出 viewer 到自定义目录** → `lua tools/quality/arch.lua viewer --out-dir <dir> [--open]`（默认目录 `./.arch_view/viewer`）
4. **重用已导出 JSON 跳重扫** → `viewer --in-json <file> --out-dir <dir>`
5. **机器可读全量** → `lua tools/quality/arch.lua scan --out <path>`
6. **改边界规则** → 改 `tools/quality/arch/config.json`（唯一真源），跑 `check` 验证

## 红线

- **零循环依赖，无白名单**：任意新循环让 `check` 失败；既包括模块级 `require` 环，也包括视图聚合反馈环。
- **规则真源唯一**：`tools/quality/arch/config.json`；不在别处复制规则。
- **不替代 `spec/guards/`**：宿主全局 API、`state.ui_*` 直写、`ui_port` 旁路这类文本级硬边界仍由 `dep_rules.lua` / `forbidden_globals.lua` 负责。
- **viewer 里红色节点 = 有循环依赖，必修**；绿色 = 含抽象契约（端口）。
- **导出物不入库**：写到 `tmp/`、`.arch_view/` 或仓库外，不要提交 viewer bundle。

## 真源

- 工具机制、子命令、viewer 读法、节点语义：`docs/reports/arch-view.md`
- 规则文件：`tools/quality/arch/config.json`
- 上游：`swarmforge/tools.lock` 钉定的 `arch_view`，按需缓存到 `.swarmforge/tools/arch_view@<sha>/`

## 输出汇报

- 命令 + 模式（check / viewer / scan）
- 违规数 + 循环数（若 check）
- viewer 路径（若导出）
- 失败时：违规模块 + 违规边类型 + 建议（搬迁 / 引入端口 / 改规则）

## 工具链改动

动到 `tools/quality/*` 任何文件 → handoff 跑 `lua tools/quality/verify_full.lua` + `busted --run tooling` 兜底（前者跑 shell-out 端到端，后者跑工具模块单测）。
