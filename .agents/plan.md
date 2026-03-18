# 计划：按用途将 `scripts/` 迁移到 `tools/`

## 摘要

本次迁移的目标是把仓库内工具脚本的**物理目录**从 `scripts/` 切到 `tools/`，同时保留一段过渡期兼容壳，避免 CI、测试、文档和外部调用一次性断掉。  
本轮已经锁定的默认决策：

- `tools/` 采用现有桶：`quality`、`ops`、`data`、`shared`
- 额外按用途明确两类目录：`tools/bridge/crap4lua/_internal`、`tools/web/ui_manager_web`
- 旧 `scripts/*` 只保留**可执行入口/兼容 bootstrap**，原始配置与静态资源改为 `tools/*` canonical
- Lua 模块名先不改：继续保留 `quality.*`、`ops.*`、`data.*`、`shared.*`、`crap4lua._internal.*`

## 接口与兼容变更

- Canonical CLI 路径改为 `lua tools/...`
- 旧 CLI 路径 `lua scripts/...` 继续可用，但只作为转发壳
- `package.path` 改为优先解析 `tools/*`，`scripts/*` 只保留兼容命中
- `require("scripts.shared.*")`、`require("scripts.quality.arch.filter")` 这类旧前缀在仓库内逐步清掉；兼容层仅兜底
- 原始文件路径如 `arch config`、`viewer snapshot`、`scrap config`、`mutate driver path`、`help text/example path` 全部切到 `tools/*`

## T1 产出：目录映射与兼容矩阵

### Canonical 目录映射

| 当前路径 | Canonical 目标 | 处理方式 |
|------|------|------|
| `scripts/quality/**` | `tools/quality/**` | 真实实现迁移；`scripts/quality/*.lua` 与 `scripts/quality/mutate/driver.lua` 保留可执行 wrapper |
| `scripts/ops/**` | `tools/ops/**` | 真实实现迁移；`scripts/ops/*.lua` 与 `scripts/ops/deploy.ps1` 保留 wrapper |
| `scripts/data/**` | `tools/data/**` | 真实实现迁移；`scripts/data/*.lua` 保留 wrapper |
| `scripts/shared/**` | `tools/shared/**` | 真实实现迁移；`scripts/shared/bootstrap.lua`、`scripts/shared/package_path_helper.lua` 保留兼容壳 |
| `scripts/crap4lua/_internal/**` | `tools/bridge/crap4lua/_internal/**` | bridge 实现迁移；旧物理路径不保留镜像，仅通过加载兼容兜底 |
| `scripts/tools/ui_manager_web/**` | `tools/web/ui_manager_web/**` | 静态资源硬切到 canonical；不保留提交态镜像目录 |
| `tools/loc_engine/**` | `tools/loc_engine/**` | 保持不动，不参与迁移 |

### 命名空间与路径兼容矩阵

| 命名空间/路径 | Canonical 来源 | 过渡期策略 |
|------|------|------|
| `quality.*` | `tools/quality/**` | 保持模块名不变，通过 `package.path` 优先命中 canonical |
| `ops.*` | `tools/ops/**` | 保持模块名不变，通过 `package.path` 优先命中 canonical |
| `data.*` | `tools/data/**` | 保持模块名不变，通过 `package.path` 优先命中 canonical |
| `shared.*` | `tools/shared/**` | 保持模块名不变，通过 `package.path` 优先命中 canonical |
| `crap4lua._internal.*` | `tools/bridge/crap4lua/_internal/**` | 保持模块名不变，`package.path` 追加 `tools/bridge/?.lua` / `tools/bridge/?/?.lua` 族 |
| `scripts.shared.*` | `scripts/shared/*.lua` wrapper | 仅保留兼容入口，内部立即转发到 `tools/shared/**` |
| `scripts.quality.arch.filter` | 仓库内调用点改为 canonical 加载 | 兼容层不承诺长期保留，迁移期尽快改掉仓库内旧前缀 |

### Wrapper 与硬切边界

#### 保留 wrapper 的旧路径

- `scripts/shared/bootstrap.lua`
- `scripts/shared/package_path_helper.lua`
- `scripts/quality/arch.lua`
- `scripts/quality/crap.lua`
- `scripts/quality/loc.lua`
- `scripts/quality/mutate.lua`
- `scripts/quality/mutate/driver.lua`
- `scripts/quality/scrap.lua`
- `scripts/ops/deploy.lua`
- `scripts/ops/deploy.ps1`
- `scripts/ops/update_api.lua`
- `scripts/data/export_xlsx.lua`

#### 直接硬切到 canonical `tools/*` 的原始路径

- `scripts/quality/arch/config.json` -> `tools/quality/arch/config.json`
- `scripts/quality/arch/filter.lua` -> `tools/quality/arch/filter.lua`
- `scripts/quality/arch/viewer/*` -> `tools/quality/arch/viewer/*`
- `scripts/quality/crap/config.lua` -> `tools/quality/crap/config.lua`
- `scripts/quality/crap/adapter.lua` -> `tools/quality/crap/adapter.lua`
- `scripts/quality/mutate/driver.lua` 的默认被引用路径 -> `tools/quality/mutate/driver.lua`
- `scripts/quality/scrap/config.lua` -> `tools/quality/scrap/config.lua`
- `scripts/quality/scrap/viewer/*` -> `tools/quality/scrap/viewer/*`
- `scripts/crap4lua/_internal/*` -> `tools/bridge/crap4lua/_internal/*`
- `scripts/tools/ui_manager_web/*` -> `tools/web/ui_manager_web/*`

#### T2+ 的硬性实施约束

- `package.path` 的 canonical 顺序必须是 `tools/*` 在前，`scripts/*` 在后，避免旧实现抢先命中。
- 所有新 bootstrap / 自定位逻辑都必须支持从非仓库根目录启动，不能继续依赖 `dofile("scripts/...")` 和写死的 `/scripts/` 正则。
- 仓库内测试、CI、文档和 helper 对 config / viewer / driver 的直接路径引用，后续统一改到 `tools/*`；`scripts/*` 不为这些原始资产保留镜像。
- wrapper 只做转发，不承载业务实现；一旦 canonical 路径稳定，后续可单独删除 wrapper。

## 任务与依赖

### T1
- **depends_on**: `[]`
- **description**: 定义最终目录映射与兼容矩阵，明确哪些旧路径保留壳、哪些直接硬切
- **location**: `scripts/**`, `tools/**`
- **validation**: 输出一张固定映射表并覆盖这些名称：`quality.*`、`ops.*`、`data.*`、`shared.*`、`crap4lua._internal.*`、`scripts.shared.*`
- **status**: 已完成
- **log**: 补充了 canonical 目录映射、命名空间兼容矩阵，以及 wrapper/硬切边界，明确 `scripts/shared` 只保留 bootstrap 兼容壳、config/viewer/static asset 一律切到 `tools/*`。
- **files edited/created**: `.agents/plan.md`

### T2
- **depends_on**: `[T1]`
- **description**: 先抽出统一的“自定位 + repo_root 解析 + bootstrap 入口”，禁止继续依赖写死的 `/scripts/` 正则和 cwd 假设
- **location**: `tools/shared/*`（新 canonical loader/helper）
- **validation**: 所有工具入口都可通过同一 helper 解析 repo_root，且从非仓库根目录启动时也能找到依赖
- **status**: 已完成
- **log**: 补齐了 `tools/shared/runtime_paths.lua` + `tools/shared/bootstrap.lua` 的 cwd/repo_root 解析；把 `arch.lua`、`loc.lua`、`deploy.lua`、`update_api.lua`、`export_xlsx.lua` 改成按自身文件定位 bootstrap，不再依赖 `require("scripts.shared.bootstrap")` 的 cwd 命中；同时修复了 `mutate.lua` 使用未定义 `REPO_ROOT` 的接线错误。
- **files edited/created**: `tools/shared/runtime_paths.lua`, `tools/shared/bootstrap.lua`, `scripts/quality/arch.lua`, `scripts/quality/loc.lua`, `scripts/quality/mutate.lua`, `scripts/ops/deploy.lua`, `scripts/ops/update_api.lua`, `scripts/data/export_xlsx.lua`, `.agents/plan.md`

### T3
- **depends_on**: `[T2]`
- **description**: 重写 `package_path_helper` 的安装顺序与 pattern，确保 `tools/*` 优先于 `scripts/*`，并补上 `tools/bridge` 解析能力
- **location**: `tools/shared/package_path_helper.lua`, `tests/bootstrap.lua`
- **validation**: `require("quality.arch")`、`require("shared.lib.common")`、`require("crap4lua._internal.common")` 命中 canonical `tools/*`
- **status**: 已完成
- **log**: 新增 canonical `tools/shared/package_path_helper.lua`，把 `tools/*` 搜索路径前置、`scripts/*` 降为兼容命中，并补了 `tools/bridge` 解析；`scripts/shared/package_path_helper.lua` 退化为 wrapper；`tests/bootstrap.lua` 改为直接从 canonical helper 装配 package path。
- **files edited/created**: `tools/shared/package_path_helper.lua`, `tools/shared/bootstrap.lua`, `scripts/shared/package_path_helper.lua`, `tests/bootstrap.lua`, `.agents/plan.md`

### T4
- **depends_on**: `[T3]`
- **description**: 先创建 `scripts/shared/bootstrap.lua` 和 `scripts/shared/package_path_helper.lua` 的前置兼容壳，避免后续物理搬迁时中途断裂
- **location**: `scripts/shared/*`
- **validation**: 旧入口仍能通过 `require("scripts.shared.bootstrap")` 和 `dofile("scripts/shared/package_path_helper.lua")` 正常转发
- **status**: 已完成
- **log**: `scripts/shared/bootstrap.lua` 与 `scripts/shared/package_path_helper.lua` 都已退化为纯 wrapper，真实实现分别转发到 `tools/shared/bootstrap.lua` 和 `tools/shared/package_path_helper.lua`，后续搬迁不再依赖旧目录承载实现。
- **files edited/created**: `.agents/plan.md`

### T5
- **depends_on**: `[T3, T4]`
- **description**: 迁移共享实现与 `crap4lua` bridge 到 canonical 位置，并把所有调用点改为走统一 bootstrap/self-location
- **location**: `tools/shared/**`, `tools/bridge/crap4lua/_internal/**`
- **validation**: 不再有实现代码依赖写死的 `scripts/shared/...` 物理路径；旧路径只剩兼容壳
- **status**: 已完成
- **log**: 物理迁移了 `scripts/shared/lib/*` 到 `tools/shared/lib/*`，以及 `scripts/crap4lua/_internal/*` 到 `tools/bridge/crap4lua/_internal/*`；同步修正了搬迁后模块内的 fallback 路径与 bootstrap 相对路径，确保 `shared.lib.*` 和 `crap4lua._internal.*` 都由 canonical `tools/*` 提供实现。
- **files edited/created**: `tools/shared/lib/*`, `tools/bridge/crap4lua/_internal/*`, `.agents/plan.md`

### T6
- **depends_on**: `[T3, T5]`
- **description**: 迁移 `quality` 桶：`arch/crap/mutate/loc/scrap` 入口、config、adapter、driver、viewer snapshot 全部切到 `tools/quality`
- **location**: `tools/quality/**`
- **validation**: `tools/quality/*` 下的 `--help`、默认 config 路径、viewer 导出路径、driver 路径、配置内容都不再引用 `scripts/*`
- **status**: 已完成
- **log**: 整个 `scripts/quality` 已迁到 `tools/quality`；同步修正了入口 fallback、`arch_filter` 的 canonical require、`crap/scrap` 默认 config 路径、`mutate` 默认 driver 路径、canonical command_name，以及 `scrap` 配置中的扫描根与排除规则。
- **files edited/created**: `tools/quality/**`, `.agents/plan.md`

### T7
- **depends_on**: `[T3, T5]`
- **description**: 迁移 `ops` 与 `data` 桶到 `tools/ops`、`tools/data`，同步清理嵌入式示例路径与帮助文本
- **location**: `tools/ops/**`, `tools/data/**`
- **validation**: `deploy.lua`、`deploy.ps1`、`update_api.lua`、`export_xlsx.lua` 全部可从 canonical 路径运行
- **status**: 已完成
- **log**: `ops` 与 `data` 已迁到 `tools/ops`、`tools/data`，canonical Lua/PowerShell help 文本都已切到 `tools/*`，当前旧 `scripts/ops` / `scripts/data` 不再是实现真源。
- **files edited/created**: `tools/ops/**`, `tools/data/**`, `.agents/plan.md`

### T8
- **depends_on**: `[T3]`
- **description**: 提前更新测试、guard、contract 与辅助代码，使其接受 `tools/*` canonical 或双路径，避免迁移期间长期红灯
- **location**: `tests/**`
- **validation**: `guard_support` 能识别 `tools/.+`；guard scan roots/contract 断言不再只写死 `scripts/*`
- **status**: 已完成
- **log**: guard 与 contract 已接受 `tools/*` repo 相对路径；扫描根扩到 `tools`；arch/crap/scrap 的 config 与 snapshot 断言改成优先 canonical、回退 legacy；wrapper 自身的 `scripts/*` 调用测试保留不变。
- **files edited/created**: `tests/support/guards/guard_support.lua`, `tests/guards/forbidden_globals.lua`, `tests/guards/dep_rules.lua`, `tests/guards/arch_view_guard.lua`, `tests/suites/architecture/arch_view_contract.lua`, `tests/suites/architecture/crap_contract.lua`, `tests/suites/architecture/scrap4lua_contract.lua`, `tests/suites/architecture/script_tools_contract.lua`, `.agents/plan.md`

### T9
- **depends_on**: `[T6, T7, T8]`
- **description**: 补齐所有 legacy executable wrappers：顶层 Lua CLI、`scripts/quality/mutate/driver.lua`、`scripts/ops/deploy.ps1`
- **location**: `scripts/quality/**`, `scripts/ops/**`, `scripts/data/**`
- **validation**: 旧路径调用实际转发到 `tools/*`，且 wrapper 本身不承载业务实现
- **status**: 已完成
- **log**: 重新补回了 `scripts/quality/*`、`scripts/ops/*`、`scripts/data/*` 和 `scripts/quality/mutate/driver.lua` 的 legacy wrapper；Lua 壳统一只做 `dofile` 转发，PowerShell 壳只做参数透传到 canonical `tools/ops/deploy.ps1`。
- **files edited/created**: `scripts/quality/**`, `scripts/ops/**`, `scripts/data/**`, `.agents/plan.md`

### T10
- **depends_on**: `[T6, T8, T9]`
- **description**: 迁移 `scripts/tools/ui_manager_web` 到 `tools/web/ui_manager_web`，并在此时一次性更新所有直接消费者；不保留静态资源镜像目录
- **location**: `tools/web/ui_manager_web/**`
- **validation**: 仓库内不再有有效消费者依赖 `scripts/tools/ui_manager_web/*`

### T11
- **depends_on**: `[T6, T7, T9, T10]`
- **description**: 更新文档、CI、帮助文本、示例命令、已提交 snapshot metadata，移除仓库内剩余的 canonical `scripts/*` 字面量
- **location**: `docs/**`, `.github/workflows/**`, 生成 snapshot 文件
- **validation**: 搜索结果中 `scripts/*` 只剩过渡 wrapper 路径与明确标注为 deprecated 的说明

### T12
- **depends_on**: `[T11]`
- **description**: 做完整验证，覆盖 canonical 路径、legacy wrapper、模块加载、非 repo-root cwd 启动
- **location**: 测试与命令验证
- **validation**:
  - `lua tests/guard.lua`
  - `lua tests/contract.lua`
  - `lua tests/tooling.lua --workers 1`
  - `lua tests/regression.lua`
  - `lua tools/quality/arch.lua --help`
  - `lua tools/quality/crap.lua --help`
  - `lua tools/quality/mutate.lua --help`
  - `lua tools/quality/scrap.lua --help`
  - `lua tools/ops/deploy.lua --help`
  - `lua tools/data/export_xlsx.lua --help`
  - `lua scripts/quality/arch.lua --help`
  - `lua scripts/quality/crap.lua --help`
  - `lua scripts/quality/mutate.lua --help`
  - `lua scripts/quality/scrap.lua --help`
  - `lua scripts/ops/deploy.lua --help`
  - `lua scripts/data/export_xlsx.lua --help`
  - `pwsh -File scripts/ops/deploy.ps1 --help`
  - `lua -e 'require(\"quality.arch\"); require(\"quality.crap\"); require(\"quality.mutate.driver\"); require(\"ops.deploy_defaults\"); require(\"shared.lib.common\"); require(\"crap4lua._internal.common\")'`
  - 从非仓库根目录执行一条 canonical CLI，确认 bootstrap 不依赖 cwd

## 并行波次

| Wave | Tasks | Can Start When |
|------|-------|----------------|
| 1 | `T1` | 立即 |
| 2 | `T2` | `T1` |
| 3 | `T3` | `T2` |
| 4 | `T4`, `T8` | `T3` |
| 5 | `T5` | `T3`, `T4` |
| 6 | `T6`, `T7` | `T3`, `T5` |
| 7 | `T9` | `T6`, `T7`, `T8` |
| 8 | `T10` | `T6`, `T8`, `T9` |
| 9 | `T11` | `T6`, `T7`, `T9`, `T10` |
| 10 | `T12` | `T11` |

## 测试重点场景

- canonical `tools/*` 入口全部可运行，且帮助文本/默认路径不再暴露 `scripts/*`
- legacy `scripts/*` 入口仍能跑通，不出现双实现分叉
- `quality.*` / `shared.*` / `ops.*` / `crap4lua._internal.*` 的 `require(...)` 仍稳定
- `arch_view`/`scrap` 的 viewer snapshot、`crap`/`scrap` config、`mutate` driver 都切到 canonical 路径
- guard 与 contract 能同时识别 `tools/*` canonical 和剩余过渡 `scripts/*` wrapper
- 非 repo-root cwd 启动不再因为 `dofile("scripts/...")` 失败

## 假设与默认拍板

- 只为**可执行入口**和 `scripts/shared` bootstrap/helper 保留过渡壳；非执行型 config/viewer/static asset 不保留镜像
- `scripts/tools/ui_manager_web` 的 canonical 新位置固定为 `tools/web/ui_manager_web`
- `scripts/crap4lua/_internal` 的 canonical 新位置固定为 `tools/bridge/crap4lua/_internal`
- `tools/loc_engine` 保持原样，不参与此次重组
- 当前仍在 Plan Mode，本回合输出的是最终实施蓝图；落地时可按此内容写成 `scripts-to-tools-plan.md`
