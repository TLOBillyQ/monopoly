# src / Config / vendor 全量重写路线图（降复杂度版）

本可执行计划是活文档。实施过程中必须持续更新“进度”“意外与发现”“决策日志”“结果与复盘”。

本文件遵循 `/.github/PLANS.md` 的维护要求。

## 目的 / 全局视角

当前项目在 `src/` 里存在较多抽象层叠加（ports、adapter、policy、dispatcher、service 并存），导致修改一个行为需要跨多层跳转。你希望“彻底重写”，核心目标不是改功能，而是把结构压扁到可维护形态，同时保留现有玩法行为。

这份路线图覆盖 `src/`、`Config/`、`vendor/` 三块。完成后，用户可见结果是：项目仍可正常启动和运行，`lua .github/tests/regression.lua` 通过，部署脚本仍可一键发布，但代码层数明显减少、依赖方向清晰、删除冗余 vendor 包不影响运行。

## 进度

- [x] (2026-02-24) 完成现状盘点：`src` 183 个文件、`Config` 19 个文件、`vendor` 29 个文件。
- [x] (2026-02-24) 完成回归基线：`lua .github/tests/regression.lua` 通过（154）。
- [x] (2026-02-24) 完成 vendor 依赖核查：运行时直接依赖主要是 `ClassUtils`、`Utils`、`UIManager.Utils`。
- [ ] 里程碑 0：冻结行为基线与重写边界文档。
- [ ] 里程碑 1：建立 `src_next/` 最小骨架与双轨启动开关。
- [ ] 里程碑 2：迁移核心回合内核（turn flow + dispatch + dirty）。
- [ ] 里程碑 3：重写 `Config/` 结构（静态配置、生成配置、校验脚本）。
- [ ] 里程碑 4：vendor 收缩（替代 `ClassUtils/Utils`，隔离 UIManager，移除未用包）。
- [ ] 里程碑 5：迁移 UI 交互主链并完成主回归。
- [ ] 里程碑 6：切换入口、删除旧实现、更新部署。

## 意外与发现

观察：`vendor/third_party/Behavior` 与 `vendor/third_party/NavMesh` 在业务代码中没有直接引用，当前更像历史遗留。
证据：全仓 `rg "vendor\.third_party" -n` 命中主要集中在 `ClassUtils`、`Utils`、`UIManager`。

观察：现有测试体系已经足够作为“行为保护网”，能支撑渐进式重写，不必 Big Bang 一次性替换。
证据：

    lua .github/tests/regression.lua
    All regression checks passed (154)
    dep_rules ok
    tick ok

观察：部署脚本硬编码了 `Config/`、`src/`、`vendor/` 三目录，重写必须同步考虑发布路径。
证据：`.github/scripts/deploy.ps1` 的 `$Directories = @("Config", "src", "vendor")`。

## 决策日志

决策：采用“双轨重写 + 最后切换”，而不是直接在 `src/` 原地大改。
理由：当前测试覆盖可用，双轨可以随时回滚，降低一次性重写风险。
日期/作者：2026-02-24 / Codex。

决策：先重写 `src` 核心流程，再重写 `Config` 结构，最后处理 vendor 收缩与清理。
理由：玩法行为由流程层决定，先锁行为再换配置和依赖，排错成本最低。
日期/作者：2026-02-24 / Codex。

决策：`UIManager` 暂时保留，不在第一阶段自研替代。
理由：这是平台绑定层，替换收益低且风险高；先把业务层从平台 API 解耦。
日期/作者：2026-02-24 / Codex。

## 结果与复盘

本节在里程碑 6 完成后填写。完成标准：
1. 新入口默认走重写实现。
2. 回归测试通过。
3. 旧目录或旧模块已删除或只保留兼容壳。
4. 部署脚本与文档同步更新。

## 背景与导读

当前入口是 `main.lua -> src/app/init.lua`。启动分为运行时安装、状态构建、`GAME_INIT` 后 UI 装配与 tick 启动。业务主循环集中在 `src/game/flow/turn/GameplayLoop.lua`，再通过 `ports` 系列转接到表现层。这个结构可扩展，但层级较深，修改链路长。

`Config/` 目前包含地图、规则、测试档位和 `Generated/*`。数据本身不大，但读取分散在多模块中。重写目标是“数据结构稳定 + 单点校验 + 明确加载顺序”。

`vendor/` 目前既有运行时必需组件（`UIManager`、部分 `Utils/ClassUtils`），也有疑似未使用组件（`Behavior`、`NavMesh`）。重写目标是“保留必要、替换可替换、删除未使用”。

## 工作计划

### 里程碑 0：冻结现状与验收红线

先把“什么算不退化”写清楚：启动链路、回合推进、托管、选择、市场、动画等待、结算。以现有回归套件为主，不先增大范围。产出一份行为清单和一组必须常绿的命令。

完成标志：项目在旧实现下回归全绿，且行为清单与关键命令写入计划。

### 里程碑 1：建立 `src_next/` 最小骨架

新增 `src_next/`，只放四层：`app`（装配）、`domain`（规则与状态）、`ui`（表现协调）、`runtime`（平台桥接）。入口先不切换，通过开关并行运行最小 smoke 流程。

完成标志：`src_next` 能独立跑通最小一局（至少 2 玩家，能推进回合）。

### 里程碑 2：迁移回合内核

优先迁 `Game + TurnFlow + Dispatch + Dirty`，保持接口简单：一个 `tick(game_state, input)` 返回状态变更和 UI 事件。把当前 `ports/adapter/policy` 链压成更少层次，先保留行为兼容。

完成标志：核心玩法（掷骰、移动、落地、next、choice）在 `src_next` 通过对应测试。

### 里程碑 3：重写 Config

拆成三类：
1. 稳定手写配置（规则、运行常量、测试 profile）。
2. 生成产物（items/tiles/market/chance）。
3. 加载与校验层（schema 校验、默认值、错误提示）。

所有业务代码只依赖一个配置入口，不再各处直接 `require Config.*`。

完成标志：配置读取路径收敛，错误配置在启动期能报清楚。

### 里程碑 4：收缩 vendor

先在 `src_next/runtime/lib/` 落地内部替代函数：深拷贝、随机选择、计时器封装。逐步移除对 `vendor.third_party.Utils` 和 `ClassUtils` 的依赖。`UIManager` 维持在单一桥接层，不让业务直接接触。

对 `Behavior/NavMesh` 做“禁引用 + 清点”后再删除，避免误删隐式依赖。

完成标志：业务路径不再直接 require `ClassUtils/Utils`，vendor 体积明显缩小。

### 里程碑 5：迁移 UI 主链

把 `UIEventRouter -> IntentBuilder/Dispatcher -> TurnDispatch` 的多层跳转收敛为“输入映射 + 领域命令 + 渲染刷新”三段。保留现有节点命名和 `Data/UIManagerNodes.lua`，避免美术资源联调风险。

完成标志：`presentation_ui_*` 相关回归在新实现下通过。

### 里程碑 6：切换与清理

切换 `main.lua` 到新入口。稳定后删除旧 `src/` 冗余模块，按新结构回填文档，最后更新部署脚本路径（若仍需叫 `src`，则在切换前完成目录改名）。

完成标志：默认运行新实现，全回归通过，发布脚本可用，旧实现可归档。

## 具体步骤

工作目录：`C:\Users\Lzx_8\Desktop\dev\monopoly`

先执行并记录基线：

    lua .github/tests/regression.lua

建立重写分支并创建新目录：

    git checkout -b rewrite/core-next
    mkdir src_next
    mkdir src_next\app src_next\domain src_next\ui src_next\runtime

先做最小启动链（不迁所有功能），验证新骨架能加载：

    lua -e "package.path=package.path..';./?.lua;./src_next/?.lua;./src_next/?/init.lua'; print('src_next bootstrap smoke')"

分阶段迁移后，每阶段至少跑一次回归：

    lua .github/tests/regression.lua

迁移后期补跑依赖规则与无 UI tick：

    lua .github/tests/internal/dep_rules.lua
    lua .github/tests/internal/gameplay_loop_no_ui.lua

切换入口前，先在计划里写明回滚点，再改 `main.lua` 和部署脚本。

## 验证与验收

验收以行为为准，不以“目录变了”为准。必须同时满足：
1. 启动无报错，可进入游戏并推进回合。
2. `lua .github/tests/regression.lua` 通过。
3. `dep_rules` 与 `gameplay_loop_no_ui` 通过。
4. 发布脚本能把正确目录拷贝到目标路径。
5. `vendor` 清理后，运行时没有缺模块错误。

## 可重复性与恢复

本路线默认可重复执行。双轨结构下，任何里程碑出问题都可回退到旧入口：
1. 保持 `main.lua` 默认仍指向旧 `src`，直到里程碑 5 结束。
2. 每个里程碑独立提交，失败时按提交回退，不跨里程碑混改。
3. 若切换后出现问题，立即把入口切回旧实现并重跑回归。

## 产物与备注

本计划执行后应产出：
1. `src_next/` 新架构代码。
2. 配置新入口与校验脚本。
3. vendor 依赖清单与删减记录。
4. 新版架构文档与迁移说明。

关键证据保持短小，优先保存“命令 + 通过行”。

## 接口与依赖

重写后建议稳定以下接口：
1. `src_next/app/init.lua`：应用启动入口。
2. `src_next/domain/game.lua`：游戏状态与回合推进。
3. `src_next/domain/turn.lua`：动作分发与阶段流转。
4. `src_next/ui/runtime_bridge.lua`：唯一 UIManager 交互层。
5. `src_next/runtime/config_loader.lua`：统一配置读取与校验。

依赖约束：
1. `ui` 不直接依赖 `domain` 内部结构，只用明确接口。
2. `domain` 不直接依赖 UIManager。
3. 业务代码不直接 require `vendor.third_party.*`。

## 本次更新说明

本次更新清空了旧的 `PLAN_CURRENT.md`（托管按钮专项），改写为面向“`src/ + Config/ + vendor/` 全量重写”的可执行路线图。改写原因是任务目标已从单点修复变为系统性重构，需要新的里程碑、验收和回滚策略。
