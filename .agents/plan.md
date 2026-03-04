# release 受控启用 test_profile 的可执行计划


本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `.agents/harness/PLANS.md` 维护，实施与讨论都要以该规范为准。本文已经内嵌当前仓库完成这项工作所需的背景，不依赖外部上下文。

## 目的 / 全局视角


当前 `release` 模式被设计为强制 `default`，这保证了线上安全，但会阻断验收阶段对 `scenario_* / items_*` 的快速复测。目标是在不破坏发布安全边界（载具仍剔除、release 数据仍受约束）的前提下，增加一条“受控 release 测试通道”：只有显式开启、且 profile 在白名单中时，release 才允许按指定 test_profile 启动。

改动完成后，用户可以用部署参数快速切到指定 profile 进行 release 环境验收；而正式发布路径保持不变，仍默认 `default` 且忽略 profile 注入。可见成功标准是：同一份代码在 `release-prod` 与 `release-qa` 两种启动方式下表现不同且可预测，相关自动化测试可证明该差异。

## 进度


- [x] (2026-03-04 23:08+08:00) 完成现状核查：确认 `scripts/deploy.ps1` 在 release 下禁止 `-StartupProfile`，`src/app/bootstrap/StartupPolicy.lua` 在 release 下强制 `profile_name="default"`。
- [x] (2026-03-04 23:10+08:00) 完成约束确认：保留 release 现有安全策略（载具剔除、角色为空 fail fast、debug_log 关闭）。
- [x] (2026-03-04 23:13+08:00) 新增受控开关：`StartupPolicy` 已支持 `RELEASE_ALLOW_TEST_PROFILE`，仅在其为真时读取 `STARTUP_TEST_PROFILE`。
- [x] (2026-03-04 23:13+08:00) 新增白名单：已新增 `src/app/testing/config/ReleaseProfileWhitelist.lua` 并接入校验，白名单外 profile 直接 fail fast。
- [x] (2026-03-04 23:14+08:00) 扩展部署脚本参数：已支持 `-Mode release -AllowReleaseTestProfile -StartupProfile <name>`，非法组合会立即失败。
- [x] (2026-03-04 23:14+08:00) 更新/新增测试：`tests/suites/startup_release.lua` 已覆盖 release-prod / release-qa / 白名单拦截 / 无 profile 回退。
- [x] (2026-03-04 23:15+08:00) 回归验证与部署验证：`startup_release` 定向和 `lua tests/regression.lua` 全通过，并完成 release-prod/release-qa 冒烟部署。
- [x] (2026-03-04 23:15+08:00) 完成结果回填：已补齐本文件活文档章节与操作口径。

## 意外与发现


- 观察：仓库已经存在 `tests/suites/startup_release.lua`，且当前断言是“release 必须忽略 profile 覆盖”。
  证据：`startup_policy_release_ignores_profile_override` 用例断言 `policy.profile_name == "default"`。

- 观察：release 部署已支持“把 release 导表结果写入目标目录”，所以新增 release-qa 只需改启动注入与策略，不需要改导表流程。
  证据：`scripts/deploy.ps1` 在 release 分支执行 `python scripts/export_xlsx.py --mode release --output-dir <target>/Config/Generated`。

- 观察：release-qa 部署时目标 `main.lua` 已按预期写入三行前缀（`RELEASE_BUILD`、`RELEASE_ALLOW_TEST_PROFILE`、`STARTUP_TEST_PROFILE`），release-prod 仅写 `RELEASE_BUILD`。
  证据：`C:/Users/Lzx_8/Desktop/dev/LuaSource_monopoly_smoke_prod/main.lua` 与 `..._qa/main.lua` 冒烟检查输出。

## 决策日志


- 决策：采用双通道语义，分别定义 `release-prod`（默认）与 `release-qa`（显式开启）两种启动策略，而不是放宽所有 release 行为。
  理由：这样可以保持线上安全默认值，同时给测试提供受控入口，减少误操作风险。
  日期/作者：2026-03-04 / Codex

- 决策：release-qa 必须通过“开关 + 白名单”双重约束；任何一层不满足都回退或失败，不做隐式容错。
  理由：仅靠参数开关无法防止误填 profile；白名单可把风险收敛到已验证场景。
  日期/作者：2026-03-04 / Codex

- 决策：保留现有 release 数据约束（vehicle 内容剔除）不变，release-qa 只改变“启动 profile 选择”，不改变“发布数据边界”。
  理由：用户已明确发布版不出现载具；该边界属于高优先级，不应被测试便利性冲掉。
  日期/作者：2026-03-04 / Codex

## 结果与复盘


本计划已落地，结果符合目标：release-prod 继续固定 `default`，release-qa 在显式开关下可使用白名单 profile。关键行为均有自动化保护，且全量回归通过（279 项）。部署脚本也已验证三种关键场景：release-prod 成功、release-qa 成功、release 误传 profile 被拒绝。

本次没有改变 release 数据边界；vehicle 相关 release 约束仍由原有导表与 `ConfigSanity` 兜底。剩余工作只是在后续需求变化时维护白名单集合，不涉及架构性风险。

## 背景与导读


本任务涉及四个关键区域。第一是启动策略层，它读取全局变量并决定实际使用哪个 profile；对应文件是 `src/app/bootstrap/StartupPolicy.lua`。第二是部署注入层，它把部署参数转为 `main.lua` 顶部全局变量；对应文件是 `scripts/deploy.ps1`。第三是启动执行层，它根据策略结果创建 `game` 并在 release 下保持 fail fast；对应文件是 `src/app/init.lua` 和 `src/app/bootstrap/GameStartup.lua`。第四是测试层，它验证策略行为是否符合预期；对应文件是 `tests/suites/startup_release.lua` 与 `tests/regression.lua`。

术语说明：

“release-prod”是正式发布路径，表示 `RELEASE_BUILD=true` 且未开启测试覆盖能力。该路径必须固定 `default` profile。

“release-qa”是受控测试路径，表示仍是 release 数据与规则，但允许通过显式开关选择白名单内 profile。

“白名单”是允许在 release-qa 使用的 profile 名称集合，集合外 profile 在启动前就被拒绝。

## 里程碑


第一里程碑聚焦启动策略本身。完成后仓库应能表达“release-prod 固定 default，release-qa 可选白名单 profile”的规则，并在非法 profile 时给出明确错误。这个里程碑的成功证明是：纯 Lua 单测即可覆盖策略分支，不依赖真实部署。

第二里程碑聚焦部署入口。完成后使用者能通过脚本参数显式进入 release-qa，且错误参数组合会被脚本直接拒绝，不会把错误配置带到运行时。这个里程碑的成功证明是：部署脚本在三种组合下输出符合预期（prod、qa、非法）。

第三里程碑聚焦回归与操作手册。完成后要给出可复制的命令序列，能够让任何新手在本机完成一次 release-prod 和一次 release-qa 启动验证，并确认 release 约束（例如 vehicle 剔除）没有回归。

## 工作计划


实施顺序按“策略 -> 脚本 -> 测试 -> 验证”推进。先修改 `StartupPolicy`，因为它定义系统真正规则；随后修改 `deploy.ps1`，把规则转成可操作参数；然后更新 `startup_release` 套件，确保策略与脚本约束都有自动化保护；最后跑回归并执行发布部署冒烟。整个过程保持小步提交，每步都要给出可观察证据。

白名单建议放在 `src/app/testing/config/ReleaseProfileWhitelist.lua`，由 `StartupPolicy` 读取。这样白名单与 test profile 配置目录同层，后续维护者更容易发现和更新。

## 具体步骤


以下命令在仓库根目录 `C:/Users/Lzx_8/Desktop/dev/repo/monopoly` 执行。每完成一步就更新“进度”并记录关键输出。

1. 新增白名单并接入策略。

    编辑 `src/app/testing/config/ReleaseProfileWhitelist.lua`，定义允许的 profile 名称集合（建议至少包含 `default`、`scenario_bankruptcy`、`items_move_control`、`items_economy_tax`、`items_target_disrupt`、`items_deity_status`）。

    编辑 `src/app/bootstrap/StartupPolicy.lua`，新增 `RELEASE_ALLOW_TEST_PROFILE` 读取逻辑：
    - release 且未开启开关 -> `profile_name` 固定 `default`
    - release 且开启开关 -> 校验 `STARTUP_TEST_PROFILE` 在白名单内
    - 不在白名单 -> `error("[Eggy] release startup profile not allowed: <name>")`

2. 扩展部署脚本参数。

    编辑 `scripts/deploy.ps1`，增加布尔参数 `-AllowReleaseTestProfile`。约束如下：
    - `-Mode release` 且未给 `-AllowReleaseTestProfile`：禁止 `-StartupProfile`（保持现状）
    - `-Mode release` 且给了 `-AllowReleaseTestProfile`：允许 `-StartupProfile`，并在写 `main.lua` 时注入 `RELEASE_ALLOW_TEST_PROFILE=true`
    - `-Mode dev`：忽略 `-AllowReleaseTestProfile`，维持现有 dev 行为

3. 更新测试。

    编辑 `tests/suites/startup_release.lua`：
    - 保留并重命名现有用例为 `release_prod_forces_default_profile`
    - 新增 `release_qa_accepts_whitelisted_profile`
    - 新增 `release_qa_rejects_non_whitelisted_profile`
    - 保留 `fail_fast_when_roles_empty` 的 release 断言

    如需要，给部署脚本增加最小参数校验测试（若仓库无现成 powershell harness，则在计划实现阶段至少记录一次手工命令证据）。

4. 执行验证。

    运行：

        lua tests/regression.lua

    运行 release-prod 部署：

        ./scripts/deploy.ps1 -Mode release

    运行 release-qa 部署（示例）：

        ./scripts/deploy.ps1 -Mode release -AllowReleaseTestProfile -StartupProfile items_target_disrupt

    在目标目录检查 `main.lua` 顶部注入是否符合预期，且程序启动时日志能打印最终 `resolved_profile`。

## 验证与验收


验收按行为定义而非按代码定义。

第一，release-prod 启动时，即便外部误注入 `STARTUP_TEST_PROFILE`，最终仍必须是 `default`。这可以通过 `startup_release` 单测与启动日志双重验证。

第二，release-qa 启动时，白名单内 profile 能生效，且白名单外 profile 会在启动前失败并给出明确错误文本。

第三，release 数据边界不变：`ConfigSanity` 对 vehicle 的 release 约束仍可通过，`lua tests/regression.lua` 全绿。

推荐验收口径：

    运行 `lua tests/regression.lua`，预期全部通过。
    运行 `./scripts/deploy.ps1 -Mode release`，预期成功且显示“启动 Profile: default”。
    运行 `./scripts/deploy.ps1 -Mode release -AllowReleaseTestProfile -StartupProfile items_target_disrupt`，预期成功并在目标 `main.lua` 看见 `RELEASE_ALLOW_TEST_PROFILE = true` 与 `STARTUP_TEST_PROFILE = "items_target_disrupt"`。

## 可重复性与恢复


本计划可重复执行。白名单和策略修改是幂等文本改动，重复运行测试与部署不会产生不可逆状态。

如果某一步失败，优先按文件粒度回退并重试，不使用破坏性命令。建议流程是：修复当前里程碑问题后重跑该里程碑验证，再跑一次全量回归。部署失败时只重试部署脚本，不需要清理仓库状态。

## 产物与备注


交付产物应包含：策略代码、白名单配置、部署脚本参数扩展、启动策略测试更新、以及一次 release-prod 与 release-qa 的命令输出证据。

输出证据建议保留短片段，例如：

    启动 Profile: default (release 模式固定)
    启动 Profile: items_target_disrupt (release-qa 白名单允许)
    [error] [Eggy] release startup profile not allowed: <name>

## 接口与依赖


本计划依赖以下稳定接口：

`src.app.bootstrap.StartupPolicy.resolve(globals)` 继续返回结构体，至少包含 `release_mode`、`profile_name`、`force_non_p1_ai`、`fail_fast_when_roles_empty`。如新增字段（例如 `release_allow_test_profile`），必须保持对现有调用方向后兼容。

部署脚本继续通过改写目标 `main.lua` 注入全局变量，不改动 `main.lua` 业务入口结构。

`tests/suites/startup_release.lua` 继续作为策略真值测试入口，并由 `tests/regression.lua` 收录，保证每次回归自动覆盖。

文末变更说明（2026-03-04 23:12+08:00）：本次将 `.agents/plan.md` 从“UIManagerNodes 节点接入”主题切换为“release 受控启用 test_profile”主题。原因是当前用户任务已经转为发布链路与启动策略治理，旧计划目标与当前交付目标不一致，会误导后续实施。
文末变更说明（2026-03-04 23:15+08:00）：本次完成计划落地并回填活文档：实现 `RELEASE_ALLOW_TEST_PROFILE` 与 release profile 白名单、扩展部署脚本参数、补齐启动策略测试并通过全量回归与发布冒烟。原因是用户要求“执行此版计划”，需将方案转为可运行行为并保留验证证据。
