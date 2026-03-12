# 护栏统一与 Gherkin 迁移计划

## 摘要
- 先把现有护栏统一成一个可被提交 CI 消费的单一清单，再做行为抽取与编译，不直接换测试引擎。
- 现状基线不是全绿：`behavior` 在 `release_trimmed` 下已激活 `422` 个 case，其中 `presentation_action_anim_queue_and_turn_lock._test_ui_sync_opens_choice_modal_after_wait_action_anim` 失败；`contract` 与 `guard` 还共同暴露 `src.presentation.runtime.ports.ui_sync_ports` 直接依赖 `src.game.flow.turn.choice_auto_policy` / `tick_timeout` 的 `arch_view` 违规。
- 迁移顺序按你选的“行为优先”执行：先覆盖 `behavior` 热点，再把 `contract/guard` 补成规则型 spec。Gherkin 在迁移完成后成为真源，CI 采用“失败清单收缩”策略。

## 关键改动
- 把 [tests/catalog.lua](/Users/Lzx_8/Desktop/dev/repo/monopoly/tests/catalog.lua) 升级为唯一的 guardrail manifest。每个 entry 必须带稳定 id、lane（`behavior` / `contract` / `guard` / `generated`）、运行 mode、来源模块、是否 generated。现有 [tests/regression.lua](/Users/Lzx_8/Desktop/dev/repo/monopoly/tests/regression.lua)、`behavior.lua`、`contract.lua`、`guard.lua` 只做薄包装，不再各自维护名单。
- 新增统一 CI 入口，例如 `tests/ci.lua`。它必须按 lane 独立执行，始终跑完全部 lane，再按稳定 id 对照 shrink-only baseline 判定结果，避免现在 `regression.lua` 一旦 behavior 失败就看不到后续 `contract/guard`。
- 在 [tests/](/Users/Lzx_8/Desktop/dev/repo/monopoly/tests) 下新增 Gherkin 真源目录，先建 `tests/features/behavior/{domain,gameplay,presentation,runtime}`，后续再建 `tests/features/policy/{contract,guard}`。Feature/Scenario 文案用中文领域语言；tag、feature id、生成后的 case id 统一 `snake_case`。
- 新增零依赖 Lua 编译器，例如 `scripts/gherkin/compile.lua`。v1 只支持 `Feature`、`Rule`、`Background`、`Scenario`、`Given/When/Then/And`、tag、表格或 doc string；不支持 `Scenario Outline`。编译输出到 `tests/generated/...` 和 `tests/generated/catalog.lua`，生成物提交入库，并提供 `--check` 模式做漂移校验。
- 编译器不引入 LuaRocks/Busted，直接生成现有 `TestHarness` 能执行的 suite table。step registry 放在 `tests/support/gherkin/steps/`，只包装现有 `tests/support/*` 和 `TestSupport` 能表达的动作；数值解析统一走 `NumberUtils`，不得引入 `tonumber` 或 `type(...) == "number"`。
- 行为抽取按三波落地：
  - 第一波先做稳定且高价值的手写 suite 到 feature 的一比一迁移：`gameplay_turn_flow_and_interrupts`、`gameplay_timeout_and_auto_runner`、`presentation_market_confirm_flow`。
  - 第二波覆盖更大的 presentation/gameplay 热点组，包含当前失败所在的 `presentation_action_anim_queue_and_turn_lock`，但在切换前先让生成测试复现同一失败签名。
  - 第三波补 runtime/startup/domain 行为，并开始把 `contract/guard` 写成规则型 feature，再编译成 fixture 驱动的 contract case 或 guard wrapper。
- `contract/guard` 不另起第二套执行器。规则型 feature 仍由同一个编译器产出 Lua suite，但 backend 分成两类：`behavior_backend` 生成普通回归 case，`policy_backend` 生成 fixture 驱动的 contract/guard case。
- 每个迁移里程碑都要做遗留代码退役审查，但本仓库当前没有成片 `src/**/legacy` 子树，所以“遗留”主要指兼容桥、deprecated export、旧路径别名和已退休模块引用。`legacy_path_guard` 已退役；删除旧实现前仍需确认 feature 完整覆盖、生成 suite 已并跑验证，并由现有 contract/guard 文档同步声明新的边界真相。

## 公开接口与工作流
- `lua tests/ci.lua --lane behavior --mode release_trimmed`
- `lua tests/ci.lua --lane contract`
- `lua tests/ci.lua --lane guard`
- `lua scripts/gherkin/compile.lua`
- `lua scripts/gherkin/compile.lua --check`
- `.github/workflows/regression.yml` 改为并行 job：至少包含 `behavior_observed`、`contract_observed`、`guard_observed`、`gherkin_compile_check`；等第一波 feature 并跑稳定后，再增加 `generated_behavior` job，并最终把 catalog 切到 generated suite。

## 验证与验收
- 统一 CI 入口必须能在一次运行里报告所有 lane 的结果，不再因前一 lane 失败而中断后续 lane。
- shrink-only baseline 初始冻结当前已知红线，id 采用 `<lane>:<suite_or_guard>:<signature>`；后续只能减少，不能新增未登记失败。
- 第一波迁移完成时，选定的 3 个手写 suite 与对应 generated suite 必须并跑，并且 case id、通过数、失败签名一致。
- `lua scripts/gherkin/compile.lua --check` 在生成物过期时必须失败，在生成物最新时必须通过。
- 当某个手写 suite 被切换为 generated suite 后，总 case 数不能无理由下降；如果下降，必须在 feature 或 baseline 中有显式记录。

## 假设与默认
- Gherkin 对已迁移切片是唯一行为真源；未迁移切片继续保留手写 suite，不强行双写。
- 当前基线红线先冻结，不要求在迁移开始前全部修绿，但任何新 lane、新 feature、新生成 suite 必须全绿。
- 不引入新的包管理器、测试框架或 C 模块依赖；实现语言保持 Lua。
- UI 相关 step 只通过现有 support/port/adapter seam 进入系统，不直接把 UIManagerLib 细节写进 feature。
