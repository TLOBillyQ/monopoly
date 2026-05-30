# T15 measurement — quality/* Gherkin mutator sweep

specifier handoff: `t15-quality-mutator` · architect branch `swarmforge-architect` · 2026-05-29
baseline 绿: differential_mutation 20 passed / mutate_bootstrap 23 passed (T5 handlers 已落地)

## 结果（`--level full`, runner_worker adapter）

| feature | total | killed | survived | kill% |
|---|---|---|---|---|
| quality/differential_mutation.feature | 47 | 3 | 44 | 6.4% |
| quality/mutate_bootstrap.feature | 35 | 7 | 28 | 20% |
| **合计** | **82** | **10** | **72** | — |

## triage：72 survivor 全部 structural residue，无 closable 子集

根因：`tools/acceptance/steps/quality.lua` 是**契约模拟 harness**，`_run_mutate` 不调真实 mutate4lua，按 scenario 的 opts 直接设 `state.run.*` 字段；`_set_source` 只 `tostring(path)` 存字符串、从不读真实文件。两类 residue：

1. **正交不变量列**（`源文件`/`survived 数`/`timeout 数`/`编辑类型`/`异常情况`/`行号集`/`旧版本`/`运行结果`）：断言测的是工具契约不变量（manifest 字节级不变、`mutation_points==0`、"manifest 不记 survived/timeout"），与 cell 值正交。例：`survived 数: 1→4` 存活，因为该 scenario 本意就是断言"无论 count 多少 manifest 都不变"——杀它等于加重言式 echo 断言，零真实覆盖。garbled 路径存活因为路径根本没被用于读文件。

2. **自我实现 dual-role 列**（`被改 scope id`/`chunk id`）：setup 与断言读同一 cell（L332→L115→L339），突变同时改两侧 → 恒等 → 存活。属 [[project_gherkin_validation_column]] self-fulfill 模式，但此处值是纯 label、无独立 observable 可锚，加验证列也是重言式。

## 结论

- **无需 coder 闭合**：与 game/items 不同（那里 cell 值落 world state、可 byte-equal 验证），契约/模拟 feature 没有独立于 example cell 的 observable，Gherkin example-value 突变在此类 feature 上天然近 100% 存活且全 benign。
- **指标提示**：Gherkin example-value mutation 不是契约/模拟 feature 的测试锋利度指标。高 survivor 数 ≠ 覆盖债。见 [[project_contract_features_gherkin_mutation_resistant]]。
- T15 quality/* 测量部分可关闭。game/items 4 closable 仍走既有 `items-survivors` coder handoff（specifier 已派）。
