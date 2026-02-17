# Tests

## 目标

当前测试入口已切到新 runner：`tests/regression.lua -> tests/runner/init.lua`。
统一执行新架构 specs（`tests/specs/*`）。

## 目录

- `tests/runner/`：收集、执行、报告。
- `tests/support/`：通用构建器、断言、时间桩、端口桩。
- `tests/specs/unit/`：纯逻辑。
- `tests/specs/contract/`：边界契约。
- `tests/specs/integration/`：跨模块 tick 行为。
- `tests/specs/regression/`：高价值回归链路。
- `tests/specs/regression/legacy_src/`：迁移期 suite 源文件；由 `tests/specs/regression/suites_migrated_spec.lua` 统一桥接为 spec 执行。

已删除：`tests/suites/` 目录、`*_registry.lua` 与切片 suite（`gameplay_core/runtime/loop`、`presentation_ui_*` 切片文件）。

## 运行

- 默认回归（新架构 + internal 脚本）：
  - `lua tests/regression.lua`

- 仅跑某些 layer：
  - `TEST_LAYERS=contract,unit lua tests/regression.lua`

- 仅跑某些 domain：
  - `TEST_DOMAINS=ports,runtime lua tests/regression.lua`

`TEST_LAYERS` 与 `TEST_DOMAINS` 支持逗号分隔，可叠加使用。

## 新增用例规范

每个 spec 文件返回：
- `layer`
- `domain`
- `cases`

每个 case 建议包含：
- `id`（`given_when_then`）
- `desc`
- `arrange`（可选）
- `act`（可选）
- `assert`（可选）

也支持兼容的 `run` 单函数形式。

## 迁移约束

- 不在新测试中直接构造散乱端口表，统一走 `support/context_builder.lua`。
- 不直接依赖真实时间，统一走 `support/time_stub.lua`。
- 端口注入必须符合 `turn/types.lua` 的 grouped 契约。
