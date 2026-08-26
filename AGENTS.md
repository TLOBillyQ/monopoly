# Agent 路由

**蛋仔派对大富翁** — Lua 5.4，清洁架构七层 + foundation，运行于 Eggy 宿主。

本文件是唯一任务入口。先定位下表命中的分支，再读取对应真源；不要为建立背景扫描整棵文档树。用中文回复。

## 任务路由

| 触发场景 | 真源 |
|---|---|
| 修改 `src/**` 或 `test/**` | [`CODING_STANDARDS.md`](CODING_STANDARDS.md)，再读目标模块与对应测试 |
| 领域词汇、对象命名或产品概念 | [`CONTEXT.md`](CONTEXT.md) |
| 模块归属、依赖方向或层边界 | [`docs/architecture.md`](docs/architecture.md)，再以 `tools/packages/arch_view/config.json` 与 `test/guards/` 为执行真源 |
| 决策理由、已批准例外或 ADR | [`docs/decisions.md`](docs/decisions.md) |
| 工单登记、台账或 triage | [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md)、[`docs/agents/triage-labels.md`](docs/agents/triage-labels.md) |
| 术语登记或领域模型维护 | [`docs/agents/domain.md`](docs/agents/domain.md) |
| 产品行为、验收场景或配置 | `features/**/*.feature`、`src/config/**`、对应 `src/**` 与 `test/behavior/**` |
| 工具行为、CLI、PATH/env/subprocess 或工具契约 | `tools/specs/*.prompt`、`lua tools/cli.lua <子命令> --help` 与对应 `tools/**/test/**` |
| 宿主接口或真机行为 | `EggyAPI.lua` / `EggyEditorAPI.lua` 仅作第三方线索；当前适配器、对应测试与 [`docs/decisions.md`](docs/decisions.md) 才是项目真源 |
| 部署 | `tools/packages/ops/deploy.lua`、`tools/packages/ops/test/` 与 `lua tools/cli.lua deploy --help` |
| 使用 swarm、`close-swarm` 或修改 `swarmforge/` | `swarm` / `close-swarm` 的行为与 `swarmforge/` 版本化资产；运行时状态只在 gitignored `.swarmforge/` |

## 验证路由

| 改动 | 先取窄反馈 | 收尾 |
|---|---|---|
| `src/**` | `lua tools/cli.lua spec-lane --profile <目录>`，或直接跑相关 spec | `lua tools/cli.lua verify` |
| `tools/**` | `lua tools/cli.lua spec-lane --profile tooling`；涉及 PATH/env/subprocess 时加 `verify --tooling --coverage` | `lua tools/cli.lua verify --tooling` |
| `test/**` | `lua tools/cli.lua spec-lane --profile <目录>` | `lua tools/cli.lua verify` |
| `features/**` | `lua tools/cli.lua acceptance` | `lua tools/cli.lua verify`；行为变更再跑 acceptance |
| 只改叙事 Markdown | 检查内部链接，并确认 docs 白名单 guard | 无额外车道 |

push 前唯一硬地板是 slim：`lua tools/cli.lua verify`。按改动风险另选 `--coverage`、`--crap`、`acceptance`、`acceptance-mutate` 或 `mutate`；完整 flag 以 `lua tools/cli.lua verify --help` 为准。

## 操作边界

- 运行 `editor-cli` 的 `run_game`、`stop_game`、`clear-logs`，或改动部署目录前，先说明并等待用户明确同意。
- 开发环境只支持 macOS 与 WSL Ubuntu；Eggy 宿主位于 Windows 端。部署入口是 `lua tools/cli.lua deploy`。
- `EggyAPI.lua` 与 `EggyEditorAPI.lua` 保持第三方边界，不把它们当作当前宿主契约。
- `swarmforge/` 上游资产保持原样；本地定制只进入既有 `project.prompt`、`local-engineering.prompt` 与 launcher 补丁面。
