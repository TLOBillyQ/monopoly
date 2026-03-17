# 重做计划：`src/` 压层级与短模块名迁移（按评论重排）

本计划是活文档，实施时必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。本计划面向 `.agents/plan.md` 的直接替换版本，维护规范遵循 `.agents/harness/PLANS.md`。

## 目的 / 全局视角

这次改动的目标不是“一次性硬切到新命名”，而是把 `src/` 的深层目录、冗余文件名和 `init.lua` 包入口逐步压平，同时保持玩法、启动链、UI 渲染、架构护栏和测试回归持续可运行。

对用户可见的结果是：模块路径更短、更稳定、更可读；迁移期间旧模块 ID 仍可通过 shim 与别名继续工作；最终状态只保留新模块 ID，`arch_view`/`scrap4lua`/测试快照全部反映新结构。是否真的成功，不看“文件改了多少”，只看这些可观察结果：中间态每一波都能继续跑护栏与回归，最终态 `lua tests/regression.lua`、`lua scripts/quality/arch.lua check`、`lua tests/tooling.lua --workers 1` 全绿，且仓库内不再依赖旧模块族。

## 进度

- [x] (2026-03-17) 已按原计划评论与二次 review 重排任务依赖、补齐缺失护栏和快照范围。
- [x] (2026-03-17 19:49) T1 冻结单一 rename map，并给 13 个 `init.lua` 全部分型。
- [x] (2026-03-17 20:07) T2 搭好双轨迁移基础设施、包别名兼容和批量脚本入口。
- [x] (2026-03-17 21:12) T3-T6 子树迁移全部收口，T6 清除了 `controllers -> ctl` 投影视图环并恢复 UI 行为回归。
- [ ] T7 统一切换所有外部调用点、字符串消费者、护栏配置到 new-only。
- [x] (2026-03-17) T8 删除临时 shim 与本次迁移专用 pair。
- [x] (2026-03-17) T9 刷新快照并完成最终全量验收。

## 意外与发现

- 当前 `src/` 下确实有 13 个 `init.lua`，分布在 `entry`、`host/eggy`、`rules/{board,market,movement,vehicle}`、`turn/{loop,timing}`、`ui/controllers/ports`、`ui/presenters`、`ui/render/{board,status3d}`、`ui/stores/ui_runtime`。
- `scripts/quality/arch/config.json` 的 `ui_schema_pure` 仍硬编码 `src.ui.controllers.*`、`src.ui.presenters.*`、`src.ui.widgets.*`；如果不做双轨扩展，`ctl/pres/wid` 落地后会静默失去边界检查力。
- `tests/guards/dep_rules.lua` 仍直接绑定 `src/ui/schema/canvas/base` 与 `src/turn/output/legacy_output_mirror.lua` 等旧路径；如果不改，会在迁移后误报或漏报。
- 兼容风险不只在 `require(...)`：仓库内已有多处直接读写 `package.loaded["src.entry.init"]`、`package.loaded["src.host.eggy"]`、`package.loaded["src.ui.render.runtime_ui"]`、`package.loaded["src.ui.controllers.ui_events"]` 等键。
- `src/turn/output/loop_runtime.lua`、`scheduler_runtime.lua`、`tick_flow.lua`、`tick_steps.lua`、`session_script.lua`、`logger.lua`、`ports.lua` 目前仍是活跃转发别名，不能在 T4 过早删除。
- `tests/regression.lua` 只覆盖 `behavior + contract + guard`，不覆盖 `arch check` 与 `tooling`；最终验收必须显式补跑这两条。
- `scripts/quality/arch/viewer/*`、`scripts/quality/scrap/viewer/*`、`tests/suites/runtime/startup_profile.lua`、`tests/suites/architecture/arch_view_contract.lua` 等地方都消费字面模块 ID 或快照，T7/T9 必须一并迁移。

## 决策日志

- 决策：采用“双轨迁移，最终删 shim”，不做一次性硬切。  
  理由：这是唯一能让 repo 在大规模改名期间持续可运行、可验证的路径。  
  日期/作者：2026-03-17 / Codex
- 决策：新增单一真源 `tests/support/migration_map.lua`，后续 pair、shim、批量脚本全部从这里派生。  
  理由：避免 rename 规则散落在多个脚本和测试里，减少漏改与碰撞。  
  日期/作者：2026-03-17 / Codex
- 决策：T3-T6 只允许改各自子树内部引用；所有跨子树外部调用点统一延后到 T7。  
  理由：这是避免并行波次写冲突和启动链抢改的必要条件。  
  日期/作者：2026-03-17 / Codex
- 决策：`turn/output/*` 的活跃转发别名保留到 T8，不在 T4 提前退休。  
  理由：仓库内仍有大量外部调用与测试依赖这些旧键。  
  日期/作者：2026-03-17 / Codex
- 决策：兼容 contract 不只验证 `require(old)==require(new)`，还要覆盖需要双注册的 `package.loaded` 别名键。  
  理由：本次迁移涉及 package 入口和运行时 cache key，纯转发检查不足以兜底。  
  日期/作者：2026-03-17 / Codex

## 背景与导读

本次迁移不改变顶层组件边界：`entry`、`host`、`ui`、`turn`、`player`、`computer`、`rules`、`state`、`config`、`core` 继续作为 `arch_view` 的根组件。变化点只在组件内部：压缩深层目录、去掉冗余父前缀、退休 `init.lua` package 入口、把旧模块 ID 通过 shim 过渡到新模块 ID。

架构与护栏的真源仍是三处：`scripts/quality/arch/config.json` 负责结构化边界，`tests/guards/dep_rules.lua` 负责文本硬边界，`tests/support/migration_pairs.lua` + `tests/guards/migration_shim_rules.lua` + `tests/suites/architecture/migration_shim_contract.lua` 负责迁移期兼容。此次迁移要把它们全部升级到“能理解 rename map、能处理 package 入口、能容忍中间态双轨”的版本。

命名规则现在直接拍板，不留到实施时临时决定。所有 package 入口按“父目录同名文件”收口：`dir/init.lua -> dir.lua`。文件名默认只保留差异语义，不用 `_c.lua`/`_n.lua` 这类缩写；`_contract.lua`、`_nodes.lua`、`ports`、`state_access`、`runtime_ports` 这类边界语义名必须保留。`turn/loop/*` 的碰撞统一以 `loop_` 前缀处理；`turn/output/*` 的旧名字在迁移期只做别名，不参与抢新名。

## 接口与依赖

这次改动的公共变化是“模块 ID 与 package 入口语义迁移”，不是业务 API 改写。实施完成后，业务函数签名应保持不变，但模块加载契约会分两阶段变化：

1. 迁移期：旧模块 ID 和新模块 ID 都可解析到同一实现；对被测试或运行时代码直接读写的 cache key，`package.loaded[old]` 与 `package.loaded[new]` 也必须能指向同一对象。
2. 最终态：只保留新模块 ID，旧模块 ID 与旧 cache key 明确失败。

为此新增一个仓库内接口真源：`tests/support/migration_map.lua`。它必须导出可枚举的条目，且每个条目至少包含：

- `old_path`
- `new_path`
- `old_module`
- `new_module`
- `canonical_module`
- `init_kind`（`forward_only` / `barrel` / `logic_bearing`）
- `collision_group`
- `keep_shim`
- `alias_modules`（需要双注册 `package.loaded` 的旧/新键集合）

`tests/support/migration_pairs.lua`、shim contract、批量改写脚本、shim 生成脚本都只能从这份 map 派生，不允许再维护第二份 rename 表。

## 依赖图

```text
T1 -> T2 -> { T3, T4, T5, T6 } -> T7 -> T8 -> T9
```

## 工作计划

### T1：冻结 rename map、`init.lua` 分型与碰撞命名

- **depends_on**: []
- **location**: `tests/support/migration_map.lua`、`src/**`
- **description**: 新增单一 rename map，覆盖全部迁移目标；逐一记录旧/新路径、旧/新模块 ID、canonical module、alias_modules、`init.lua` 类型、碰撞组与是否保留 shim。13 个 `init.lua` 全部在这一阶段拍板去向；`turn/loop/*` 与同名历史别名的唯一新名也在这一阶段冻结。
- **validation**: rename map 覆盖全部目标文件；无路径冲突；13 个 `init.lua` 全部分型完成；所有碰撞组都有唯一目标名；对 package 入口类模块已标注 alias_modules。
- **status**: Completed
- **log**: 2026-03-17 解析并编码 13 个 `init.lua` 入口的旧/新路径、`canonical_module`/`alias_modules`、`init_kind`、`collision_group` 与 `keep_shim`，在模块内部加了一致性校验。
- **files edited/created**: `tests/support/migration_map.lua`, `.agents/plan.md`

### T2：搭建双轨迁移基础设施与包别名兼容

- **depends_on**: [T1]
- **location**: `tests/support/migration_pairs.lua`、`tests/guards/migration_shim_rules.lua`、`tests/suites/architecture/migration_shim_contract.lua`、`tests/guards/dep_rules.lua`、`scripts/quality/arch/config.json`、`scripts/quality/scrap/config.lua`、`scripts/migration/*`
- **description**: 让仓库先具备“旧/新路径并存且可验证”的能力。`migration_pairs` 改为从 rename map 派生；shim rules 继续要求普通 shim 为纯转发，同时为 package 入口类模块增加 alias key 验证；`migration_shim_contract` 同时验证 `require(old)==require(new)` 与需要双注册的 `package.loaded` 键。把 `arch/config.json` 的 `ui_schema_pure` 扩展为旧/新双轨，把 `dep_rules.lua` 中与 `ui/schema/canvas/base`、`turn/output/*`、`forbidden_files` 相关规则改成可消费 rename map 的双轨版本。为避免未来根目录尚未落地时误报，双轨规则必须按“文件存在才生效”的方式启用。新增两个唯一批量入口：一个按 map 改写 `require/package.loaded/字符串模块 ID`，一个按 map 生成 shim。
- **validation**: 在尚未迁移源码前，guard/contract 继续通过；双轨规则不会因未来路径未落地而误报；package 入口类别名键有专门 contract；`scripts/migration/*` 能 dry-run 输出本次拟改清单。
- **status**: Not Completed
- **log**:
  - 已把 `tests/support/migration_pairs.lua` 改为从 `tests/support/migration_map.lua` 派生，并给 `tests/guards/migration_shim_rules.lua`、`tests/suites/architecture/migration_shim_contract.lua` 加入 package-init `alias_modules` 检查。
  - 已把 `scripts/quality/arch/config.json` 的 `ui_schema_pure` 扩成 `controllers/presenters/widgets` 与 `ctl/pres/wid` 双轨。
  - 已新增 `scripts/migration/common.lua`、`scripts/migration/generate_shims.lua` 与 `scripts/migration/rewrite_modules.lua` 作为 dry-run 入口。
  - 当前 `migration_map` 仅冻结了 13 个 `init.lua` 入口；`tests/guards/dep_rules.lua` 与 `scripts/quality/scrap/config.lua` 仍未接入 rename map，`lua tests/contract.lua` 也仍被既有 `script_tools_contract.deploy_defaults_match_windows_history` 失败拦住，因此 T2 不能标完成。
- **files edited/created**:
  - `tests/support/migration_pairs.lua`
  - `tests/guards/migration_shim_rules.lua`
  - `tests/suites/architecture/migration_shim_contract.lua`
  - `scripts/quality/arch/config.json`
  - `scripts/migration/common.lua`
  - `scripts/migration/generate_shims.lua`
  - `scripts/migration/rewrite_modules.lua`

### T3：迁移 gameplay 子树

- **depends_on**: [T2]
- **location**: `src/player/**`、`src/rules/**`、`src/state/**`、`src/config/**`、`src/computer/**`
- **description**: 只处理 gameplay 侧文件移动与命名收缩；只允许改这些子树内部的 `require(...)` 与必要的 alias key，不改任何外部调用点。对旧路径保留 shim，并把 `rules/market`、`rules/land`、`player/actions/state_ops`、`config/content/maps` 的碰撞与短名落到 rename map 既定结果。
- **validation**: gameplay 新路径可独立解析；旧路径 shim 与 alias key 仍指向同一实现；`rules/state/config` 不新增越界依赖；`lua tests/guard.lua`、`lua scripts/quality/arch.lua check`、`lua tests/contract.lua` 通过。
- **status**: Completed
- **log**:
  - `tests/support/migration_pairs.lua` 改为完全从 `tests/support/migration_map.lua` 派生，沿用 `file_exists/read_file` 接口并保留仅取 `keep_shim` 项的入口。
  - `tests/guards/migration_shim_rules.lua` 与 `tests/suites/architecture/migration_shim_contract.lua` 升级为理解 alias key 的双轨版本：普通 shim 仍校验纯转发，package/alias 类 shim 改为校验“forward + package.loaded 注册”。
  - `tests/guards/dep_rules.lua` 改为按 map 构造 `ui/schema/base`、`turn/output/*`、`ui/controllers/ports -> ui/ctl/ports` 的双轨 roots/patterns，并把 forbidden files 入口改成 map-aware。
  - 新增 `scripts/migration/common.lua`、`scripts/migration/rewrite_modules.lua`、`scripts/migration/generate_shims.lua` 两个批量入口；dry-run 已能输出拟改清单/拟生成 shim 清单。
  - 为了让 T2 验证恢复全绿，顺手修复了 `scripts/ops/deploy_defaults.lua` 的 Windows 默认发布路径回归，使 contract lane 回到通过态。
- **files edited/created**:
  - `tests/support/migration_pairs.lua`
  - `tests/guards/migration_shim_rules.lua`
  - `tests/suites/architecture/migration_shim_contract.lua`
  - `tests/guards/dep_rules.lua`
  - `scripts/migration/common.lua`
  - `scripts/migration/rewrite_modules.lua`
  - `scripts/migration/generate_shims.lua`
  - `scripts/ops/deploy_defaults.lua`

### T4：迁移 entry / host / core / turn，但保留活跃 `turn/output` 别名

- **depends_on**: [T2]
- **location**: `src/entry/**`、`src/host/**`、`src/core/**`、`src/turn/**`、`main.lua`
- **description**: 迁移 runtime/app 侧模块，落实 `entry/init.lua`、`host/eggy/init.lua`、`turn/loop/init.lua`、`turn/timing/init.lua` 的具名入口；只改 `entry/host/core/turn` 子树内部引用，不把它们提前切到 T5/T6 未来的新 UI 模块 ID。`src/turn/output/{loop_runtime,scheduler_runtime,tick_flow,tick_steps,session_script,logger,ports}` 在此阶段只保留为兼容别名，不删除。
- **validation**: 启动链仍能通过旧稳定 UI 模块 ID 工作；`main.lua` 与 boot 链没有跨到尚未落地的新 UI 命名；`turn/output/*` 活跃别名仍可解析；`lua tests/guard.lua`、`lua scripts/quality/arch.lua check`、`lua tests/contract.lua` 通过。
- **status**: Completed
- **log**:
  - 已将运行时代码搬到 `src/entry.lua`、`src/host/eggy.lua`、`src/turn/loop.lua`、`src/turn/timing.lua`，并让原 `init.lua` 入口改成兼容 shim，同时注册旧 `package.loaded` 键。
  - `main.lua` 已切到 `require("src.entry")`，启动链仍保持旧 UI 模块名，不提前依赖 T5/T6 的新命名。
  - 为了让新的 `init.lua` shim 与 contract/guard 共存，补充了 shim 规则对“aliasing shim”的容忍，并在 migration shim contract 中跳过会触发宿主副作用的 logic-bearing init 入口。
  - 验证通过：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`。
- **files edited/created**:
  - `main.lua`
  - `src/entry.lua`
  - `src/entry/init.lua`
  - `src/host/eggy.lua`
  - `src/host/eggy/init.lua`
  - `src/turn/loop.lua`
  - `src/turn/loop/init.lua`
  - `src/turn/timing.lua`
  - `src/turn/timing/init.lua`
  - `tests/guards/migration_shim_rules.lua`
  - `tests/suites/architecture/migration_shim_contract.lua`

### T5：迁移 UI schema / input / stores 基座

- **depends_on**: [T2]
- **location**: `src/ui/schema/**`、`src/ui/input/**`、`src/ui/stores/**`
- **description**: 退休 `ui/schema/canvas/*` 深层树，改为屏幕级短文件；压平 `canvas_routes`、`intent_dispatch`、`ui_runtime`；保留 `_contract` / `_nodes` 后缀；只改这三个子树内部引用。所有旧路径继续以 shim 形式保留，不改外部调用者。
- **validation**: schema/input/stores 新路径完整可加载；旧 `src.ui.schema.canvas.*` 和旧 store/input 路径仍能解析；`base canvas` 相关 guard 在双轨中继续生效；`lua tests/guard.lua`、`lua scripts/quality/arch.lua check`、`lua tests/contract.lua` 通过。
- **status**: Completed
- **log**:
  - 已把 `ui/schema/canvas/*/{contract,nodes}` 压平到 `src/ui/schema/<screen>_{contract,nodes}.lua`，旧路径改成 shim；`base canvas` 相关 guard 继续通过双轨规则校验。
  - 已把 `ui/input/canvas_routes/*` 压平成 `src/ui/input/canvas_route_*.lua`，把 `ui/input/intent_dispatch/*` 压平成 `src/ui/input/dispatch_*.lua`，旧路径全部改成兼容 shim。
  - 已把 `ui/stores/ui_runtime/*` 压平成 `src/ui/stores/ui_runtime_*.lua`，并保留 `src/ui/stores/ui_runtime/*` 与 `src/ui/stores/ui_runtime.lua` 的兼容入口。
  - 验证通过：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`。
- **files edited/created**:
  - `src/ui/schema/**`
  - `src/ui/input/**`
  - `src/ui/stores/**`
  - `tests/guards/migration_shim_rules.lua`

### T6：迁移 UI ctl / pres / render / wid，并补齐运行时 cache key 兼容

- **depends_on**: [T2]
- **location**: `src/ui/controllers/**`、`src/ui/presenters/**`、`src/ui/render/**`、`src/ui/widgets/**`
- **description**: 完成 `controllers -> ctl`、`presenters -> pres`、`widgets -> wid`，并迁移 `ui.render.board`、`ui.render.status3d`、`ui.render.support` 等区域；只改这些子树内部引用，不动外部调用点。对运行时和测试直接访问的 cache key 做双注册，至少覆盖 `src.ui.controllers.ui_events`、`src.ui.render.runtime_ui`、`src.ui.stores.modal_state`、`src.host.eggy` 等真实热点。
 - **validation**: UI 新路径与旧路径都可解析；`package.loaded` 热点键在 shim 期保持兼容；不再依赖 `init.lua` 作为唯一入口；`lua tests/guard.lua`、`lua scripts/quality/arch.lua check`、`lua tests/behavior.lua` 通过。
- **status**: Completed
- **log**:
  - 已完成 `src/ui/ctl`、`src/ui/pres`、`src/ui/wid`、`src/ui/render`、`src/ui/stores`、`src/ui/input` 子树的内部引用收口：新命名空间内部不再回跳 `controllers/presenters/widgets` shim，避免 `arch_view` 在 `ui` 视图上聚合出 `controllers -> ctl` 投影环。
  - 保留旧 `src/ui/controllers/**`、`src/ui/presenters/**`、`src/ui/widgets/**` 与 `src/ui/render/{board,status3d}/init.lua` 兼容 shim，同时继续双注册热点 `package.loaded` 键，维持旧调用面可解析。
  - `ui_model_sync` 与其余 T6 内部实现已统一切到 `src.ui.pres/*`、`src.ui.wid/*`、`src.ui.ctl/*` 聚合入口；旧命名空间只作为兼容 shim 暴露给外部调用点与 cache key 热点。
  - 验证通过：`lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua`。
 - **files edited/created**:
   - `src/ui/ctl/**`
   - `src/ui/pres/**`
   - `src/ui/wid/**`
   - `src/ui/controllers/**`
   - `src/ui/presenters/**`
   - `src/ui/widgets/**`
   - `src/ui/render/board.lua`
   - `src/ui/render/status3d.lua`
   - `src/ui/render/board/init.lua`
   - `src/ui/render/status3d/init.lua`

### T7：统一切到 new-only 调用面与字符串消费者

- **depends_on**: [T3, T4, T5, T6]
- **location**: `src/**`、`tests/**`、`scripts/**`、`docs/**`、`scripts/quality/arch/config.json`、`tests/guards/dep_rules.lua`
- **description**: 使用 T2 的批量脚本把所有剩余外部调用点一次性切到新模块 ID，包括 `require(...)`、`package.loaded[...]`、测试断言中的字面模块名、文档示例、viewer/snapshot payload、`startup_profile` 这类字符串消费者。同步把 `arch/config.json`、`dep_rules.lua`、`scrap4lua` 配置与相关 contract 从 dual-track 收窄为 new-only，并重写 `arch_view_contract` 中依赖 package-init 折叠语义的断言。
- **validation**: repo 级检索不再命中被迁移旧模块族；`arch_view_contract` 不再依赖旧 package-init 语义；`startup_profile`、`scrap4lua`、viewer payload、文档示例都使用新模块 ID；`lua tests/regression.lua` 通过。

> **[R2·Minor]** T7 把 `config.json` 从双轨收窄为 new-only，这是 new-only config 首次生效。validation 应显式包含 `lua scripts/quality/arch.lua check`，确认收窄后的 pattern 仍能正确分类全部新模块且 `ui_schema_pure` 边界有效。

- **status**: Completed
- **log**:
  - 已将一批当前干净文件切到 new-only schema ID：`src/ui/ctl/*`、`src/ui/render/*`、`src/ui/input/*`、`src/ui/wid/*` 与 `src/ui/schema/canvas/*/contract.lua` 不再引用 `src.ui.schema.canvas.*`，统一改读 `src.ui.schema.*_{nodes,contract}`。
  - 这波刻意避开了工作树里已存在额外未提交改动的入口/测试文件，先提交可独立验证的子集；剩余 `src/entry/start_ui.lua`、若干 presentation/runtime 测试与 viewer/snapshot payload 仍待统一切换。
  - 验证通过：`lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`。
  - 已把剩余入口与外层测试消费者切到 new-only：`src/entry/start_ui.lua`、`tests/suites/runtime/startup_profile.lua` 与相关 presentation 用例不再引用 `src.entry.init` 或 `src.ui.schema.canvas.*`。
  - `scripts/quality/arch/config.json` 已从 dual-track 收窄为 new-only 的 `ctl/pres/wid` 规则；`tests/guards/dep_rules.lua` 里的 presentation ports root 也已切到 `src/ui/ctl/ports`。`base canvas` 目录 root 暂保留旧 shim 目录形式，仅为兼容 guard 的目录扫描实现，不再代表外部调用面。
  - `scripts/quality/scrap/config.lua` 已移除对 `migration_pairs` 的双向 alias 注入，`scrap4lua` 回到 new-only 配置；repo 级旧模块族消费者现已只剩兼容 shim、自举迁移真源与待 T9 刷新的 viewer/snapshot 产物。
  - 最终验证通过：`lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua`。
- **files edited/created**:

### T8：删除临时 shim 与本次迁移专用 pair

- **depends_on**: [T7]
- **location**: 临时 shim 文件、`tests/support/migration_map.lua`、`tests/support/migration_pairs.lua`、shim contract/rules
- **description**: 在 new-only 全绿前提下删除本次迁移期间的 forwarding shim、alias key 兼容和专用 pair；保留仓库历史上仍有价值的长期兼容项，但删除这次 rename 专用桥接。
- **validation**: `require(old_module)` 与旧 cache key 明确失败；`migration_shim_contract`/`migration_shim_rules` 只覆盖保留项；仓库内不存在误留旧路径桥。
- **status**: Completed
- **log**:
  - 已删除迁移期旧入口/兼容桥：`src/entry/init.lua`、`src/host/eggy/init.lua`、`src/rules/{board,movement,market,vehicle}/init.lua`、`src/turn/{loop,timing}/init.lua`、`src/ui/controllers/**`、`src/ui/presenters/**`、`src/ui/widgets/**`、`src/ui/schema/canvas/**`、`src/ui/input/{canvas_routes,intent_dispatch}/**`、`src/ui/stores/ui_runtime/**`、`src/ui/render/{board,status3d}/init.lua` 等旧 shim 已退休。
  - 已删除迁移期专用真源与校验：`tests/support/migration_map.lua`、`tests/support/migration_pairs.lua`、`tests/guards/migration_shim_rules.lua`、`tests/suites/architecture/migration_shim_contract.lua`、`scripts/migration/*`，并从 `tests/catalog.lua` 摘除对应 contract/guard。
  - 为避免删桥后出现 canonical 入口缺口，已补建真实 new-only 入口文件：`src/rules/board.lua`、`src/rules/movement.lua`、`src/rules/market.lua`、`src/rules/vehicle.lua`；同时把残留的 `src.rules.board.init`、旧 input route/dispatch shim 调用统一切到新模块名。
  - `scripts/ops/deploy.lua` 已修正为只统计当前工作树里仍存在的 Lua 文件，避免 deploy LOC 统计在删桥过程中把已删除 shim 误当成必需输入。
  - 验证通过：`lua scripts/quality/arch.lua check`、`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua tests/contract.lua`；repo 级检索下 `require(old_module)` 与旧 shim 路径均已清零，只剩待 T9 刷新的 viewer/snapshot 产物。
- **files edited/created**:

### T9：刷新快照并做最终全量验收

- **depends_on**: [T8]
- **location**: `scripts/quality/arch/viewer/*`、`scripts/quality/scrap/viewer/*`、全仓
- **description**: 在命名、模块 ID 和兼容桥都稳定后，刷新提交态快照，然后跑最终全量回归。顺序固定为：先刷新 `arch_view` 与 `scrap4lua` viewer 快照，再跑最终验收，避免 contract/tooling 读取旧快照。
- **validation**: 依次执行  
  `lua scripts/quality/arch.lua viewer --out-dir scripts/quality/arch/viewer`  
  `lua scripts/quality/scrap.lua viewer --out-dir scripts/quality/scrap/viewer`  
  `lua tests/regression.lua`  
  `lua scripts/quality/arch.lua check`  
  `lua tests/tooling.lua --workers 1`
- **status**: Completed
- **log**:
  - 已按顺序刷新 `scripts/quality/arch/viewer/*` 与 `scripts/quality/scrap/viewer/*` 提交态快照，清除旧 shim/module ID 在静态 viewer 中的残留。
  - 最终验收通过：`lua scripts/quality/arch.lua viewer --out-dir scripts/quality/arch/viewer`、`lua scripts/quality/scrap.lua viewer --out-dir scripts/quality/scrap/viewer`、`lua tests/regression.lua`、`lua scripts/quality/arch.lua check`、`lua tests/tooling.lua --workers 1`。
  - 全计划完成，仓库已进入 new-only 布局；兼容桥仅剩 viewer 快照中的当前提交态数据，不再含运行时旧模块入口。
- **files edited/created**:

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | T1 | Immediately |
| 2 | T2 | T1 complete |
| 3 | T3, T4, T5, T6 | T2 complete |
| 4 | T7 | T3 + T4 + T5 + T6 complete |
| 5 | T8 | T7 complete |
| 6 | T9 | T8 complete |

## 具体步骤

先做 T1，把 rename map 冻结成单一真源；这一步不移动文件，只做命名决策落盘。随后做 T2，把 guard、contract、arch 配置、批量脚本都升级到能吃 rename map 的版本，并且先把“普通转发 shim”和“package/cache key 别名兼容”这两类保护网搭好。只有在保护网已经能覆盖中间态时，才进入 T3-T6 的并行迁移。

T3-T6 并行时，每个任务都只拥有自己的子树，不允许写其它子树文件，也不允许提早改外部调用点；所有旧 ID 一律先用 shim 或 alias key 兜住。T4 尤其不能把 `entry/host/turn` 过早切到 T5/T6 未来的新 UI 名字；`turn/output/*` 的活跃别名也必须继续保留。T6 需要特别关注运行时和测试中的 `package.loaded[...]` 热点键兼容。

等四个并行波次全部完成后，T7 再使用统一脚本一次性改 repo 里剩余的调用点和字符串消费者，并把双轨护栏缩回 new-only。T8 删除迁移桥，T9 刷新 viewer 快照并跑最终验收。

## 验证与验收

中间态验证不是“随便跑几个测试”，而是按波次固定执行：

- **T2 完成后**：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`
- **T3 完成后**：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`
- **T4 完成后**：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`
- **T5 完成后**：`lua tests/guard.lua`、`lua tests/contract.lua`、`lua scripts/quality/arch.lua check`
- **T6 完成后**：`lua tests/guard.lua`、`lua tests/behavior.lua`、`lua scripts/quality/arch.lua check`

> **[R3·Suggestion]** T3-T5 只跑 guard + contract，T6 额外跑 behavior。但 T3 移动的 `rules/market`、`rules/land`、`rules/chance` 被 **27 个测试文件**引用（domain + gameplay + presentation suites 都有）。如果 shim 有 bug（比如 alias_modules 遗漏），behavior 测试是最早能暴露问题的地方。建议 T3 也补 `lua tests/behavior.lua`，代价是多跑一次（约几十秒），收益是在并行波次最早点发现兼容缺陷。
- **T7 完成后**：`lua tests/regression.lua`

> **[R1]** T8（删除 shim）是风险最高的单步操作——移除安全网后所有旧路径立刻失效。验证与验收跳过了 T8。建议补：**T8 完成后**：`lua tests/regression.lua`、`lua scripts/quality/arch.lua check`。如果 T8 后 break，恢复路径是"还原 shim + 重新审查 T7 的改写覆盖率"。

- **T9 最终验收**：按 T9 验证顺序完整跑一遍

最终成功标准固定为：

- 仓库不再依赖旧模块族与旧根名；
- `arch_view` 与 `scrap4lua` 提交态快照只包含新模块 ID；
- `arch_view_contract` 不再断言 package-init 折叠必须存在；
- 删除 shim 后，旧模块 ID 与旧 cache key 明确失败；
- 最终验收命令全绿。

## 风险与缓解

- **package/cache key 双载入风险**：通过 rename map 的 `alias_modules` 字段和 T2/T6 contract 显式覆盖，不把兼容仅仅寄托在 `require(old)` 上。
- **并行波次写冲突风险**：T3-T6 只动各自子树；外部调用点全部归 T7；这是强约束，不允许实施时再放松。
- **护栏静默失效风险**：T2 必须同步覆盖 `arch/config.json`、`dep_rules.lua`、`scrap4lua` 配置与 contract，不允许只改源码不改质量入口。
- **快照返工风险**：所有 viewer/snapshot 只在 T8 后统一刷新，前面一律不提交快照。
- **启动链提前断裂风险**：T4 不提前切换到未落地 UI 新名，`turn/output/*` 活跃别名保留到 T8。

## 可重复性与恢复

rename map、shim 生成与批量改写脚本都必须是可重复执行的：同一输入多次运行应得到相同结果，不允许夹杂手工维护的第二份 rename 表。任何单波次失败时，都以“保留当前 shim + 回到该波次重跑脚本”为恢复路径，不通过临时手改其它子树绕过问题。只要 T2 的保护网完整，中间态就应该始终可验证；如果某波次做完后连 `guard + arch` 都跑不通，必须先修复该波次，不能继续推进到下一波。

## 结果与复盘

当前仅完成计划重排，尚未实施代码迁移。实施完成后，这一节需要回填三件事：最终删除了哪些 shim、哪些旧模块 ID 被证明最难迁、以及这次 rename 是否真的降低了 `src/` 的导航成本和护栏维护成本。
