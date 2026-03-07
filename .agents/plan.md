# Plan: `Config/` 与 `src/` 的 snake_case 路径收敛

## Summary

本计划只处理**路径与模块名**，不处理局部变量、函数名、表字段、配置 key。目标是把 `Config/` 与 `src/` 下所有文件名、目录名、Lua 模块路径字符串统一到 `snake_case`，并同步修正 `tests/`、`main.lua`、`EggyAPI.lua`、`docs/`、`scripts/` 中的引用。

这次改动的唯一白名单例外是顶层 `Config/` 根目录：它保持大写不动；其内部子目录与文件全部改为 `snake_case`。实现完成后，`require("Config.generated.tiles")`、`require("src.presentation.adapter.ui_view_service")` 这类路径应成为唯一规范写法。

## Naming Contract

- 只改三类东西：文件/目录 basename、模块路径字符串、与模块路径直接绑定的 `package.loaded[...]` / 守卫 / 文档路径文本。
- 不改局部变量、函数名、导出表字段、配置 key、业务常量。
- 统一转换规则在 `T1` 固化成完整 manifest，后续任务只能按 manifest 执行，不能临场发明新名字。
- 转换规则固定为：
  - 已经是 `snake_case` 的名称保持不动。
  - 顶层 `Config` 保持不动，其余 basename 一律转为小写 `snake_case`。
  - 小写/数字后接大写时断开：`roleId` → `role_id`。
  - 缩写整体下沉，再与后续单词断开：`UIViewService` → `ui_view_service`，`UIGateSync` → `ui_gate_sync`，`SfxRuntime` → `sfx_runtime`。
  - 数字作为独立段：`Status3DService` → `status_3d_service`，`UI3DPanel` → `ui_3d_panel`。
  - 目录与文件使用同一套规则：`Generated` → `generated`，`DefaultMap.lua` → `default_map.lua`。
- 对外接口变化仅限模块路径：
  - `Config.Generated.Tiles` → `Config.generated.tiles`
  - `src.presentation.adapter.UIViewService` → `src.presentation.adapter.ui_view_service`
  - `src.game.flow.turn.GameplayLoop` → `src.game.flow.turn.gameplay_loop`

## Tasks

### T0: 建立基线与残留快照
- **depends_on**: `[]`
- **location**: 仓库根目录，`Config/`，`src/`，`tests/`，`main.lua`，`EggyAPI.lua`
- **description**: 记录当前回归基线、非 snake_case basename 清单、`require(...)` / `package.loaded[...]` / 普通字符串中的旧模块路径命中清单，作为后续归零对照。
- **validation**: 基线回归可运行；输出三份快照：basename 清单、自动可改路径清单、人工处理清单。
- **status**: Completed
- **log**: 2026-03-07 已运行 `lua tests/regression.lua`，退出码为 0。并生成 `.agents/snake_case_basename_snapshot.txt`、`.agents/snake_case_auto_candidates.txt`、`.agents/snake_case_manual_candidates.txt` 三份快照，作为后续归零对照。
- **files edited/created**: `.agents/snake_case_basename_snapshot.txt`、`.agents/snake_case_auto_candidates.txt`、`.agents/snake_case_manual_candidates.txt`。

### T1: 固化命名规则与完整 rename manifest
- **depends_on**: `[T0]`
- **location**: `Config/`，`src/`
- **description**: 生成完整 `old_path -> new_path` manifest，并附带 owner 矩阵。manifest 必须覆盖 `Config/` 与 `src/` 下所有非 snake_case basename；`Config` 根目录是唯一白名单例外。后续所有任务只允许按 manifest 执行。
- **validation**: `find Config src` 扫描出的全部非 snake_case basename 都能在 manifest 中找到唯一映射；不存在一对多或多对一冲突。
- **status**: Completed
- **log**: 2026-03-07 已生成 `.agents/snake_case_manifest.json` 与 `.agents/snake_case_owner_matrix.json`。manifest 当前覆盖 258 个 rename 条目，按 `T3` 到 `T8` 分配 owner，且冲突数为 0。
- **files edited/created**: `.agents/snake_case_manifest.json`、`.agents/snake_case_owner_matrix.json`。

### T2: 构建“两阶段”路径重写/报表工具
- **depends_on**: `[T1]`
- **location**: 一次性迁移脚本，输入覆盖 `src/`、`tests/`、`main.lua`、`EggyAPI.lua`、`docs/`、`scripts/`
- **description**: 提供 `--check` 与 `--apply` 两种模式。自动改阶段只处理 literal `require(...)` 与 `package.loaded[...]`；报表阶段只扫描不改写普通字符串模块路径、guard regex、白名单数组、文档路径文本、脚本里的路径文本。
- **validation**: `--check` 必须稳定输出两段：自动改预览、人工处理清单；并能用 manifest 校验所有自动改候选都可映射。
- **status**: Completed
- **log**: 2026-03-07 已新增 `scripts/tmp_rewrite_module_paths.py`。`python3 scripts/tmp_rewrite_module_paths.py --check` 能输出自动改预览与人工处理清单，当前自动改覆盖 literal `require(...)` / `package.loaded[...]`，人工清单保留普通字符串、文档与守卫路径文本。
- **files edited/created**: `scripts/tmp_rewrite_module_paths.py`。

### T3: 重命名 `Config/` 子树
- **depends_on**: `[T1]`
- **location**: `Config/generated/`，`Config/maps/`，`Config/runtime_refs.lua`
- **description**: 仅按 manifest 重命名 `Config/` 内部目录与文件；保留顶层 `Config/`。本任务不做仓库级引用改写，只允许处理 rename 本身和 `Config/` 子树内极少量必须同步的自引用。
- **validation**: `Config/` 子树 basename 非 snake_case 归零；`Config/` 内不再出现旧 basename；不允许出现旧新路径并存。
- **status**: Completed
- **log**: 2026-03-07 已按 manifest 完成 `Config/` 子树 rename，保留顶层 `Config/` 不动。目录大小写变更通过临时目录两步 rename 完成，并同步修正 `Config/maps/default_map.lua` 内对 `Config.generated.tiles` 的自引用。`find Config ... | rg '[A-Z]|-'` 已归零。
- **files edited/created**: `Config/generated/*`、`Config/maps/*`、`Config/runtime_refs.lua`。

### T4: 重命名 `src/core/` 子树
- **depends_on**: `[T1]`
- **location**: `src/core/`
- **description**: 按 manifest 重命名 `src/core/` 下剩余非 snake_case 文件与目录。只拥有 `src/core/` 子树，不做跨子树引用改写。
- **validation**: `src/core/` 子树 basename 非 snake_case 归零；`src/core/` 内旧 basename 不再存在。
- **status**: Completed
- **log**: 2026-03-07 已完成 `src/core/` 子树 21 个条目的 rename，覆盖 `choice/`、`config/`、`events/`、`ports/`、`runtime_facade/`、`runtime_ports/`、`utils/`。`find src/core ... | rg '[A-Z]|-'` 已归零；大小写敏感 rename 通过临时名规避文件系统假阳性。
- **files edited/created**: `src/core/choice/*`、`src/core/config/*`、`src/core/events/*`、`src/core/ports/*`、`src/core/runtime_facade/*`、`src/core/runtime_ports/*`、`src/core/utils/*`。

### T5: 重命名 `src/game/` 的核心与流程子树
- **depends_on**: `[T1]`
- **location**: `src/game/core/`，`src/game/flow/`，`src/game/ports/`，`src/game/runtime/`，`src/game/scheduler/`，`src/game/turn_engine/`
- **description**: 按 manifest 重命名 gameplay 内核、用例编排、端口与历史执行器相关子树。只做路径改名，不做跨子树引用改写。
- **validation**: 本任务拥有子树 basename 非 snake_case 归零；旧 basename 不再存在。
- **status**: Completed
- **log**: 2026-03-07 已完成 `src/game/` 核心与流程相关 62 个条目的 rename，覆盖 `core/`、`flow/`、`ports/`、`runtime/`、`scheduler/`、`turn_engine/`。各拥有子树的 basename 非 snake_case 检查均已归零；跨子树 `require(...)` 改写按计划留给后续 `T10` 统一处理。
- **files edited/created**: `src/game/core/*`、`src/game/flow/*`、`src/game/ports/*`、`src/game/runtime/*`、`src/game/scheduler/*`、`src/game/turn_engine/*`。

### T6: 重命名 `src/game/systems/` 子树
- **depends_on**: `[T1]`
- **location**: `src/game/systems/`
- **description**: 按 manifest 重命名玩法规则子树。只做路径改名，不改跨子树引用。
- **validation**: `src/game/systems/` basename 非 snake_case 归零；旧 basename 不再存在。
- **status**: Completed
- **log**: 2026-03-07 已完成 `src/game/systems/` 子树 67 个条目的 rename。虽然 worker 未及时回报，但本地复核显示 `find src/game/systems ... | rg '[A-Z]|-'` 已归零，且 `git status --short src/game/systems` 显示旧路径删除与新路径新增成对出现，说明 rename 已落地。
- **files edited/created**: `src/game/systems/board/*`、`src/game/systems/chance/*`、`src/game/systems/choices/*`、`src/game/systems/commerce/*`、`src/game/systems/effects/*`、`src/game/systems/items/*`、`src/game/systems/land/*`、`src/game/systems/market/*`、`src/game/systems/movement/*`、`src/game/systems/vehicle/*`。

### T7: 重命名 `src/presentation/` 子树
- **depends_on**: `[T1]`
- **location**: `src/presentation/`
- **description**: 按 manifest 重命名 presentation 范围内所有剩余非 snake_case basename。只做路径改名，不改跨子树引用。
- **validation**: `src/presentation/` basename 非 snake_case 归零；旧 basename 不再存在。
- **status**: Completed
- **log**: 2026-03-07 已完成 `src/presentation/` 子树 80 个条目的 rename，仅处理路径、不做跨子树引用改写。`find src/presentation ... | rg '[A-Z]|-'` 输出为空，basename 已归零；旧路径残留通过 `find` 精确路径校验清零。
- **files edited/created**: `src/presentation/adapter/*`、`src/presentation/canvas_runtime/*`、`src/presentation/interaction/*`、`src/presentation/read_model/*`、`src/presentation/render/*`、`src/presentation/shared/*`、`src/presentation/state/*`、`src/presentation/widgets/*`。

### T8: 重命名 `src/app/` 与 `src/infrastructure/` 子树
- **depends_on**: `[T1]`
- **location**: `src/app/`，`src/infrastructure/`
- **description**: 按 manifest 重命名装配层与基础设施层中剩余非 snake_case basename。只做路径改名，不改跨子树引用。
- **validation**: `src/app/` 与 `src/infrastructure/` basename 非 snake_case 归零；旧 basename 不再存在。
- **status**: Completed
- **log**: 2026-03-07 已完成 `src/app/` 与 `src/infrastructure/` 共 15 个条目的 rename，覆盖 bootstrap、payment、runtime_install、testing 与 infrastructure runtime。`find src/app ... | rg '[A-Z]|-'` 与 `find src/infrastructure ... | rg '[A-Z]|-'` 均无输出。
- **files edited/created**: `src/app/bootstrap/*`、`src/app/testing/*`、`src/infrastructure/runtime/*`。

### T9: 冻结点校验
- **depends_on**: `[T2, T3, T4, T5, T6, T7, T8]`
- **location**: 仓库根目录
- **description**: 在进入全仓字符串改写前，重新核对 manifest 与工作树一致性：所有 old path 必须已消失、new path 必须已存在，再重新运行 `T2 --check`，确认自动改覆盖集与人工清单稳定。
- **validation**: manifest 校验通过；`--check` 输出无悬空 old path、无缺失 new path；人工清单可枚举且稳定。
- **status**: Completed
- **log**: 2026-03-07 已完成冻结点校验：manifest 中 old path 的精确路径命中数为 0，new path 缺失数为 0。重新运行 `python3 scripts/tmp_rewrite_module_paths.py --check` 后，自动改预览为空，人工清单稳定，说明工作树与 manifest 已对齐。
- **files edited/created**: 无。

### T10: 全仓自动改写模块路径字符串
- **depends_on**: `[T9]`
- **location**: `src/`，`tests/`，`main.lua`，`EggyAPI.lua`
- **description**: 使用 `T2 --apply` 统一改写 literal `require(...)` 与 `package.loaded[...]`。本任务是唯一允许做跨子树路径字符串改写的任务，禁止再混入文件 rename。
- **validation**: `require(...)` 与 `package.loaded[...]` 中不再出现带大写段的 `Config.*` / `src.*` 模块路径；自动改写后工作树可加载关键入口模块。
- **status**: Completed
- **log**: 2026-03-07 已执行 `python3 scripts/tmp_rewrite_module_paths.py --apply`。由于前序 rename 与局部自引用同步已使自动改区清空，本次 apply 为 no-op；再次检查 `require(...)` / `package.loaded[...]` 中带大写段的 `Config.*` / `src.*` 模块路径已归零。
- **files edited/created**: 无。

### T11: 人工清单收尾
- **depends_on**: `[T10]`
- **location**: `tests/internal/dep_rules.lua`，`docs/architecture/boundaries.md`，`docs/architecture/layer-model.md`，`main.lua`，`EggyAPI.lua`，`tests/`，`scripts/`，`docs/`
- **description**: 处理所有 `T2 --check` 报出的非自动改项，包括普通字符串模块路径常量、guard regex、白名单数组、脚本文本与文档文本。`Config/Generated` 被视为仓库命名契约的一部分；若外部生成器存在但不在本仓库中，本任务必须同步记录“生成入口需输出 snake_case 文件名”的外部依赖说明，避免后续再生覆盖回旧名。
- **validation**: `T2 --check` 的人工清单归零；`tests/internal/dep_rules.lua` 与架构文档全部切到新路径；`scripts/deploy.ps1`、测试 helper、普通字符串模块路径常量全部更新完毕。
- **status**: Completed
- **log**: 2026-03-07 已清理守卫中的历史路径文本与 regex，把 `src.core.RuntimeCompat`、`RuntimePorts`、`RuntimeContext` 等旧命名说明同步为 snake_case 表达。复跑 `python3 scripts/tmp_rewrite_module_paths.py --apply` 的人工清单后输出 `(none)`，说明收尾完成。仓库内未发现额外的 in-repo 配置生成器入口，`scripts/deploy.ps1` 已使用 `Config/generated`。
- **files edited/created**: `tests/internal/dep_rules.lua`。

### T12: 最终验收与回退封口
- **depends_on**: `[T11]`
- **location**: 仓库根目录
- **description**: 做最终 basename、路径字符串、关键模块 smoke、全量回归与工作树一致性验收；同时把回退策略落到执行说明中，确保失败时按 owner 子树回滚，而不是整仓回退。
- **validation**:
  - `find Config src` 的 basename 扫描只允许顶层 `Config` 为例外，其他 basename 全部为 snake_case。
  - `rg -n '[\"'\"'](Config|src)\\.[^\"'\"']*[A-Z][^\"'\"']*[\"'\"']' src tests main.lua EggyAPI.lua docs scripts` 归零。
  - `lua` 关键入口 smoke 通过，至少覆盖 `Config`、`src/core`、`src/game/flow`、`src/presentation`。
  - 全量回归通过。
  - `git diff --name-status` / `git status --short` 中不出现旧新路径并存导致的异常 delete/add 混乱。
- **status**: Completed
- **log**: 2026-03-07 最终验收已通过：basename 白名单检查 `bad_count=0`，`rg -n '["'"'](Config|src)\.[^"'"']*[A-Z][^"'"']*["'"']' ...` 无命中，`lua -e 'require("Config.generated.tiles"); require("src.core.config.gameplay_rules"); require("src.game.flow.turn.gameplay_loop"); require("src.presentation.adapter.ui_view_service"); print("snake smoke ok")'` 打印 `snake smoke ok`，`lua tests/regression.lua` 退出码为 0。回退策略沿用计划默认：`T3-T8` 按 owner 子树回滚，`T10-T11` 仅回滚字符串与守卫/文档收尾。
- **files edited/created**: `.agents/plan.md`。

## Parallel Execution Groups

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 0 | T0 | 立即 |
| 1 | T1 | T0 完成 |
| 2 | T2, T3, T4, T5, T6, T7, T8 | T1 完成 |
| 3 | T9 | T2-T8 完成 |
| 4 | T10 | T9 完成 |
| 5 | T11 | T10 完成 |
| 6 | T12 | T11 完成 |

并行约束固定为：`T3-T8` 只做本子树 rename，不做跨子树引用改写；跨子树 `require/package.loaded` 改写统一留给 `T10`，这样 ownership 才不会互相踩文件。

## Test Plan

- 阶段验收：
  - 每个 rename 任务完成后，先做本子树 basename 非 snake_case 归零检查。
  - 每个 rename 任务完成后，确认本子树内部不再引用旧 basename。
- 总验收：
  - 自动改前跑一次 `T2 --check`，自动改后再跑一次，确认自动改区归零、人工区稳定。
  - 跑关键 smoke：至少验证 `Config.generated.*`、`src.core.*`、`src.game.flow.*`、`src.presentation.*` 入口可 `require`。
  - 跑全量回归。
  - 跑最终 grep，确认 `Config/` 之外不存在大写 basename，模块路径字符串不再带大写段。

## Assumptions

- 顶层 `Config/` 根目录保留不动；其余 `Config` 内部路径全部 snake_case。
- 本次不重命名 Lua 局部变量、函数名、导出字段、配置 key。
- `tests/`、`docs/`、`scripts/` 不改文件名，只改引用文本。
- `Config/Generated` 虽然看起来像生成产物，但在本计划里默认视为仓库命名契约的一部分；如果存在仓库外生成器，执行时必须同步更新其产物命名，或明确冻结再生直到外部生成器跟上。
- 回退按 owner 子树执行：`T3-T8` 失败时只回滚各自拥有的 rename；`T10-T11` 失败时只回滚字符串改写与文档/守卫修改，不回滚已稳定的 rename。
