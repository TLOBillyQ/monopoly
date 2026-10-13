# Agent 路由

**蛋仔派对大富翁** — Lua 5.4，清洁架构七层 + foundation，运行于 Eggy 宿主。

本文件是唯一任务入口。先定位下表命中的分支，再读取对应真源；不要为建立背景扫描整棵文档树。用中文回复。

## 任务路由

| 触发场景 | 真源 |
|---|---|
| 修改 `src/**` 或 `test/**` | [`CODING_STANDARDS.md`](CODING_STANDARDS.md)，再读目标模块与对应测试 |
| 领域词汇、对象命名或产品概念 | [`GLOSSARY.md`](GLOSSARY.md) |
| 模块归属、依赖方向或层边界 | [`docs/architecture.md`](docs/architecture.md)，再以 `tools/packages/arch_policy/policy.json` 与 `test/guards/` 为执行真源；旧 `arch_view/config.json` 仅为兼容投影 |
| 决策理由、已批准例外或 ADR | [`docs/decisions.md`](docs/decisions.md) |
| 工单登记、台账或 triage | [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)、[`docs/agents/triage-labels.md`](docs/agents/triage-labels.md) |
| 术语登记或领域模型维护 | [`docs/agents/domain.md`](docs/agents/domain.md) |
| 产品行为、验收场景或配置 | `features/**/*.feature`、`src/config/**`、对应 `src/**` 与 `test/behavior/**` |
| 工具行为、CLI、PATH/env/subprocess 或工具契约 | `tools/specs/*.prompt`、`lua tools/cli.lua <子命令> --help` 与对应 `tools/**/test/**` |
| 宿主接口或真机行为 | `EggyAPI.lua` / `EggyEditorAPI.lua` 仅作第三方线索；当前适配器、对应测试与 [`docs/decisions.md`](docs/decisions.md) 才是项目真源 |
| 部署 | `tools/packages/ops/deploy.lua`、`tools/packages/ops/test/` 与 `lua tools/cli.lua deploy --help` |

## 验证路由

| 改动 | 先取窄反馈 | 收尾 |
|---|---|---|
| `src/**` | `lua tools/cli.lua spec-lane --profile <目录>`，或直接跑相关 spec | `lua tools/cli.lua verify` |
| `tools/**` | `lua tools/cli.lua spec-lane --profile tooling`；涉及 PATH/env/subprocess 时加 `verify --tooling --coverage` | `lua tools/cli.lua verify --tooling` |
| `test/**` | `lua tools/cli.lua spec-lane --profile <目录>` | `lua tools/cli.lua verify` |
| `features/**` | `lua tools/cli.lua acceptance` | `lua tools/cli.lua verify`；行为变更再跑 acceptance |
| 只改叙事 Markdown | 检查内部链接，并确认 docs 白名单 guard | 无额外车道 |

push 前唯一硬地板是 slim：`lua tools/cli.lua verify`。

按改动风险另选（都是显式步骤，不是硬地板）：`--coverage`、`--crap`、`lua tools/cli.lua acceptance`、`lua tools/cli.lua acceptance-mutate`、`lua tools/cli.lua mutate`；完整 flag 以 `lua tools/cli.lua verify --help` 为准。

## 平台保证边界（#96 / ADR 0066）

原生 Windows 是唯一受支持的开发平台，但两件保留能力当前仍按 POSIX 专用能力声明，**不在 Windows 保证面内**：

| 子命令 | Windows 上的行为 | 显式跳过 |
|---|---|---|
| `lua tools/cli.lua dry`（结构重复检测） | 打印 `status=unavailable` 并退 3；不安装工具、不运行、不报通过 | `--skip-if-unavailable` → `status=skipped` 退 0 |
| `lua tools/cli.lua acceptance-mutate`（中文验收变异） | 同上 | 同上 |

- 三态可区分：不可用（退 3）/ 显式跳过（退 0，`status=skipped`）/ 真实失败（退 1 或用法错误退 2）。跳过不等于通过——它只记录「这条平台上没有结果」。
- 声明真源是 `tools/foundation/platform_boundary.lua`；契约细节见 `tools/specs/dry4lua.prompt` 与 `tools/specs/acceptance4lua.prompt`。
- 默认硬门禁（slim `verify`、`verify --tooling`、`lua tools/cli.lua acceptance`）**不依赖**这两条能力，也不允许用诊断替代本应实际执行的 lint 或架构 guard。
- 仍在保证面内：显式验收解析/IR 入口 `tools/packages/acceptance/cli/{parser,generator,ir_dry}.lua` 与 `lua tools/cli.lua acceptance`。

## 操作边界

- 运行 `editor-cli` 的 `run_game`、`stop_game`、`clear-logs`，或改动部署目录前，先说明并等待用户明确同意。
- 开发环境只支持原生 Windows（ADR 0066）：Lua 5.4、LuaRocks 5.4 tree 与 cmd.exe，不依赖 WSL、Git Bash、Node 或 PowerShell Start-Job。Eggy 宿主位于 Windows 端。部署入口是 `lua tools/cli.lua deploy`。
- `EggyAPI.lua` 与 `EggyEditorAPI.lua` 保持第三方边界，不把它们当作当前宿主契约。
