---
kind: adr
status: stable
owner: architecture
last_verified: 2026-05-24
---
# ADR 0013 — e2e 测试边界：宿主集成 smoke

## 背景

`spec/e2e/` 有 3 个 spec（`smoke/connection_spec.lua`、`smoke/scene_crud_spec.lua`、`gameplay/run_game_spec.lua`），通过 `tools/bridge/editor_cli/` 走 `editor-cli.exe` 真实进程外 RPC，连接在线运行的 Eggy 编辑器。

ADR 0012 锁定了 acceptance vs behavior 边界，但 e2e 与这两层、与 `behavior/scenarios/`、与 `contract` 的差异从未被 ADR 明确。`docs/architecture/quality-map.md` 已写清"必须 Windows + 编辑器在线"、"不进 verify_full"，但缺乏边界条文，新写 spec 容易越界。

本 ADR 把现有 3 个 spec 的实际形态固化为契约，并定义增长触发条件。

## 决策

### D1 — e2e 的三条必要条件（缺一不可）

1. 走 `tools/bridge/editor_cli/client.lua` 真实进程外 RPC，调 `editor-cli.exe`
2. 断言对象是 `EditorAPI` / `GameAPI` 真值（在真编辑器进程里加载），不是 stub 或 in-process fake
3. 验证内容是"真编辑器还跑得动吗"——bridge 通路 / 编辑模式 / 试玩生命周期 / host 胶水在真宿主里的 wiring

### D2 — e2e 的禁止条件

下列内容**不进** `spec/e2e/`：

- 业务规则回归（去 `spec/behavior/rules/` 或 `features/`）
- 跨层契约 / port 注入 / 装配（去 `spec/contract/`）
- `GameAPI absent` / `EditorAPI absent` 分支断言（去 `spec/behavior/host/`，那一层显式 stub）
- in-process 模拟整局回放（去 `spec/behavior/scenarios/` 或 `features/turn_flow.feature`）
- 多 spec 共享外部状态（每个 spec 必须自己清场，参见 `scene_crud_spec.lua:14-19` 的 `_delete_if_present`）

### D3 — 增长触发条件

新增 e2e spec 仅当下列之一：

- 改 `src/host/*` 暴露给 `EditorAPI` 的胶水
- 改 `run_game` / `stop_game` 启动路径
- 改 `tools/bridge/editor_cli/*` bridge 协议

否则维持当前 ~3-5 spec 规模——e2e 是"心跳"不是"网"，slow / 串行 / 依赖外部状态。

### D4 — 不改名

`e2e` 这个标签已在 `.busted` lane、`quality-map.md`、`docs/reports/health-signals.md` 等多处沉淀。把它改名为 `host-integration` 概念上更准，但跨文档同步成本远大于命名清晰度收益。本 ADR 仅锁义不改名：在 `quality-map.md` e2e 章节加术语脚注"e2e 在本仓库特指宿主集成 smoke，不是端到端业务流"。

## 验证

新增 e2e spec 必须：

```sh
# 1. Windows + 编辑器在线
busted --run e2e

# 2. 验证三必要条件命中
grep -E "(editor-cli|EditorAPI|GameAPI)" spec/e2e/<path>_spec.lua

# 3. 验证不违反禁止条件（应为空）
grep -E "(package\.loaded\[|stub\.new\(|mock\.new\()" spec/e2e/<path>_spec.lua
```

非 Windows 平台 fixture 会 `pending(...)` 整组跳过；CI 验证由 Windows pipeline 承担。

## 后果

**正向**：

- e2e 边界明确，未来新 spec 可自审
- 与 ADR 0012（acceptance vs behavior）+ 本 ADR 形成 3 层契约：acceptance（外显行为）/ behavior（实现回归）/ e2e（宿主集成）
- `docs/architecture/quality-map.md` 第 139-158 行 e2e 章节获得规范上游

**代价**：

- 新增一份契约文档，要在 `quality-map.md` 加 cross-ref
- 改 `src/host/*` 等 D3 触发路径的 PR 需要显式判断是否补 e2e

**不变量**：

- 现有 3 个 spec 完全符合本契约（不需要任何 spec 改动）
- `verify_full` 仍不含 e2e（外部依赖）
- ADR 0012 提升边界不变

## 相关任务

- 主 agent：合并本 ADR 后在 `docs/architecture/quality-map.md:139` 附近加 cross-ref `参见 ADR 0013`
- 后续：若 Eggy 提供 in-process 测试钩子让 `EditorAPI`/`GameAPI` 可在 Lua 进程内真实加载，本 ADR D1 第 1 条需重新评估，但目前无此预兆
