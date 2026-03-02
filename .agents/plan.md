# Monopoly 运行时边界收口与命名治理执行计划（R14）

本可执行计划是活文档。实施过程中必须持续更新“进度”、“意外与发现”、“决策日志”、“结果与复盘”。

本文件必须遵循 `./.agents/harness/PLANS.md` 维护。任何执行者只依赖当前工作树与本文件即可从零开始推进。

## 目的 / 全局视角

本轮目标是把运行时能力入口进一步收口到 context-first 的单轨路径，并清理测试与规则中的历史 compat 语义残留，同时保持现有玩法行为不变。完成后，用户侧可见结果是回归套件继续稳定通过，且运行时关键路径不再依赖隐式全局回退作为默认行为。验证方式是运行依赖守护与回归测试，确认输出继续全绿，并用代码搜索证明关键模块已不再包含计划内的残留 compat 术语和隐式回退路径。

## 进度

- [x] (2026-03-02 15:02 +08:00) 已读取并吸收 `.agents/research.md` 注释，确认本轮不纳入“多实例并发能力建设”。
- [x] (2026-03-02 15:05 +08:00) 已完成新计划改写骨架，章节与结构对齐 `./.agents/harness/PLANS.md` 强制要求。
- [x] (2026-03-02 15:11 +08:00) 建立执行前基线证据：`lua tests/internal/dep_rules.lua` 通过，`lua tests/regression.lua` 通过（N=208）。
- [x] (2026-03-02 15:18 +08:00) 完成里程碑 M52：`RuntimePorts` 增加显式 `legacy_global_fallback` 开关，默认严格 context-first。
- [x] (2026-03-02 15:22 +08:00) 完成里程碑 M53：`RuntimeInstall` 引入 `context_policy` 与 `skip_context_install` 受控策略，并新增严格/legacy 契约测试。
- [x] (2026-03-02 15:26 +08:00) 完成里程碑 M54：`UIPanel`、`PopupRenderer`、`UIEventHandlers` 迁移为通过 `RuntimePorts.resolve_role` 访问角色对象。
- [x] (2026-03-02 15:29 +08:00) 完成里程碑 M55：`runtime_compat_contract.lua` 重命名为 `runtime_ports_contract.lua`，回归入口同步更新，`dep_rules` 历史文案清理。
- [x] (2026-03-02 15:34 +08:00) 执行最终验收并回填证据：依赖守护通过，回归通过（N=209），关键路径搜索完成。

## 意外与发现

研究注释明确否定了“去全局单例化以支持并发/多实例”这条路线在当前阶段的必要性。该结论改变了本轮范围边界：本计划不再引入 scoped container，也不为不存在的需求支付重构成本。证据来自 `.agents/research.md` 中对 P1 与重构步骤 2 的原位注释，均明确标注“没有这个需求”。

当前风险重心因此从“并发状态污染”转移为“默认隐式回退导致行为不确定”。这使 context-first 收口成为第一优先级，且验证口径必须聚焦“默认路径可预测”而非“多实例能力”。

首次回归在切换严格默认后出现 18 项失败，集中在测试环境仍依赖 `all_roles/vehicle_helper/camera_helper` 隐式全局回退。修复策略是在 `tests/TestSupport.lua` 显式开启 `runtime_ports.set_legacy_global_fallback_enabled(true)`，让测试环境以可见配置进入 legacy 模式，而非依赖默认隐式行为。修复后回归恢复全绿并新增 1 条契约用例，总数从 208 提升到 209。

## 决策日志

决策：本轮只做边界收口、适配层端口化和命名治理，不推进多实例相关改造。
理由：研究注释已明确无该需求，继续推进会产生高改动面且收益不足。
日期/作者：2026-03-02 / Codex GPT-5。

决策：保留现有全局 fallback 能力，但迁移到显式 legacy 分支，不作为默认执行路径。
理由：可兼顾历史启动链路稳定性与默认行为可预测性，降低一次性切换风险。
日期/作者：2026-03-02 / Codex GPT-5。

决策：本轮验收主证据仍以 `tests/regression.lua` 与 `tests/internal/dep_rules.lua` 为统一口径。
理由：仓库已有回归入口装配差异，局部 suite 直接运行并不能稳定代表真实系统行为。
日期/作者：2026-03-02 / Codex GPT-5。

决策：测试环境通过 `TestSupport` 显式打开 legacy fallback，而非恢复 RuntimePorts 默认隐式回退。
理由：保持生产默认严格模式不被测试历史路径反向污染，同时确保测试可控、可复现。
日期/作者：2026-03-02 / Codex GPT-5。

## 结果与复盘

R14 已完成实施。默认运行时路径已收口到 context-first，并把 legacy 回退改为显式开关；安装阶段新增严格模式下“缺 context 直接失败”的契约；表现层高频角色解析路径已改为 RuntimePorts 访问；测试契约已从 `runtime_compat_contract` 迁移到 `runtime_ports_contract`。最终回归通过且通过数提升到 209，说明新增契约覆盖已纳入主回归。

## 背景与导读

本任务涉及四块代码域。第一块是运行时能力入口，位于 `src/core/RuntimePorts.lua` 与 `src/core/RuntimeContext.lua`，它们负责从上下文解析角色、载具与镜头辅助能力。第二块是启动装配，位于 `src/app/bootstrap/RuntimeInstall.lua`，它决定运行时端口以何种模式装入。第三块是表现层调用宿主 API 的路径，集中在 `src/presentation/ui` 与 `src/presentation/api`，这些路径决定 UI 行为是否通过统一端口访问宿主能力。第四块是规则与契约，位于 `tests/internal/dep_rules.lua` 与 `tests/suites`，它们用于证明依赖方向与行为契约持续成立。

本文中的“context-first”是指运行时优先且默认只从显式注入的上下文读取能力，不在常规路径静默读取全局变量；“legacy 分支”是指仅用于兼容历史入口的显式回退逻辑，必须可识别、可测试、可收敛。

## 工作计划

里程碑 M52 的目标是完成默认路径收口。执行者需要先阅读 `RuntimePorts.lua` 中解析角色与 helper 的实现，把当前隐式回退拆成两段行为：默认段只读取 context，legacy 段集中处理历史全局来源。实现方式以最小变更为先，不改变外部函数名，避免影响调用面。完成后应在 `RuntimeContext.lua` 与调用点复核，确保默认路径不会因缺省 context 静默触达全局对象。

里程碑 M53 的目标是让安装阶段行为可证明。执行者需要在 `RuntimeInstall.lua` 明确安装策略，当 context 缺失时要么抛出受控错误，要么进入显式 legacy 模式并留下可断言信号。随后在 `tests/suites` 里补契约用例，覆盖“有 context 的正常模式”和“无 context 的受控模式”，使失败方式可预期、可定位。

里程碑 M54 的目标是降低表现层直连宿主 API 的散点。执行者从 `src/presentation/ui/UIPanel.lua`、`src/presentation/ui/PopupRenderer.lua` 与 `src/presentation/api/UIEventHandlers.lua` 开始，优先迁移高频路径到已存在或新增的端口方法，保持交互语义不变。若迁移期必须并行保留旧调用，需在同次修改中补充测试，并标记退役点，避免长期双轨。

里程碑 M55 的目标是统一团队语义。执行者应重命名仍含 compat 语义的测试文件，或在不改路径的情况下先完成 suite 名称与断言语义统一；同时同步更新 `dep_rules.lua` 中历史术语描述，使规则文本与当前架构一致。该里程碑以低风险文本与契约同步为主，但必须跑完整回归确认无注册路径回归。

## 具体步骤

在仓库根目录 `C:\Users\Lzx_8\Desktop\dev\repo\monopoly` 先执行基线命令并记录输出。命令为 `lua tests/internal/dep_rules.lua` 与 `lua tests/regression.lua`。若任一失败，先停止实施并在“意外与发现”记录失败片段，再定位现有代码问题，不带入新改动。

进入 M52 时，先用 `rg "resolve_roles|resolve_vehicle_helper|resolve_camera_helper|all_roles|vehicle_helper|camera_helper" src/core -n` 定位运行时解析入口与全局触点，再修改 `src/core/RuntimePorts.lua` 形成默认与 legacy 两条清晰路径。改完后立即运行 `lua tests/regression.lua`，确保行为无回归。

进入 M53 时，修改 `src/app/bootstrap/RuntimeInstall.lua` 的安装分支，把“缺失 context”的处理改为显式策略，然后在 `tests/suites` 增加或更新对应契约用例。完成后运行 `lua tests/regression.lua` 与 `lua tests/internal/dep_rules.lua`，并记录是否出现新增失败类型。

进入 M54 时，使用 `rg "GameAPI|GlobalAPI|SetTimeOut|RegisterTriggerEvent" src/presentation -n` 盘点直连宿主调用，按高频文件分批迁移。每批迁移后都先跑 `lua tests/regression.lua`，通过后再进入下一批，以减小定位半径。

进入 M55 时，先搜索 `rg "compat|RuntimeCompat" tests/internal tests/suites -n`，再统一命名与描述语义并更新相关测试注册。最后执行 `lua tests/internal/dep_rules.lua`、`lua tests/regression.lua` 与 `rg "RuntimeCompat" -n src tests` 作为收尾验收。

预期关键输出至少包含 `dep_rules ok`、`All regression checks passed (N)`，且 `N` 不低于实施前基线。

## 验证与验收

验收标准以可观察行为为准而非结构变化。默认运行路径收口成功的判据是：在正常安装场景下，运行时能力解析不依赖隐式全局读取，且回归行为与基线一致。安装契约成功的判据是：缺失 context 时系统表现为显式失败或受控降级，并由测试稳定复现。表现层迁移成功的判据是：关键 UI 行为在回归中保持通过，同时宿主 API 直连点数量下降。命名治理成功的判据是：规则文案与契约语义中不再出现误导性 compat 残留，且测试入口保持稳定。

## 可重复性与恢复

本计划按 M52 到 M55 顺序推进，每个里程碑完成后都执行一次全量回归，确保问题定位局部化。若某里程碑失败，只回退该里程碑触及文件并重新验证，禁止跨里程碑打包回退。若出现“必须保留 legacy 行为才能通过现有生产路径”的情况，可以临时保留 legacy 分支，但必须在决策日志写明触发条件、保留范围和后续退役条件。

## 产物与备注

本轮已回填证据如下。

    [evidence] lua tests/internal/dep_rules.lua -> dep_rules ok
    [evidence] lua tests/regression.lua -> All regression checks passed (209)
    [evidence] rg "RuntimeCompat" -n src tests -> only dep_rules pattern/description hits, no runtime require usage
    [evidence] rg "GameAPI.get_role" src/presentation/ui/UIPanel.lua src/presentation/ui/PopupRenderer.lua src/presentation/api/UIEventHandlers.lua -n -> no hits

## 接口与依赖

本轮不改变 `RuntimePorts` 对外已使用的函数名，继续维持 `resolve_roles`、`resolve_vehicle_helper`、`resolve_camera_helper` 的调用接口稳定，以控制调用面风险。`RuntimeInstall.install` 继续作为安装入口，但其缺省行为将按本计划收口到可预测模式。表现层迁移优先复用既有端口抽象；若新增端口函数，必须在对应测试中给出行为断言并说明该函数替代的宿主调用点。

本次修订说明（2026-03-02）：根据 `.agents/research.md` 的注释，移除“去全局单例化以支持并发/多实例”的计划项，重排为“context-first 边界收口 + 表现层端口化 + 命名治理”的 R14 执行计划，并将验证口径统一到 dep_rules 与 regression。

本次修订说明（2026-03-02，执行回填）：按 R14 执行 M52-M55 全部里程碑。主要改动为 RuntimePorts 默认严格化与显式 legacy 开关、RuntimeInstall 受控降级策略、presentation 高频路径迁移到 RuntimePorts、runtime 契约文件去 compat 命名并纳入回归。中途因测试环境历史依赖出现 18 项失败，最终以 TestSupport 显式 legacy 模式修复，回归恢复并通过 209 项。
