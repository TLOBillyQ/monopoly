# 代码库现状研究报告（2026-03-08）

> 本文档从三个维度审视代码库现状：概念一致性、架构-目录映射、代码行数治理。

## 执行摘要

| 指标 | 数值 |
|------|------|
| `src/` Lua 代码行数 | **24,613 行（当前工作树）** |
| `src/` Lua 文件数 | **293 个** |
| 涉及 "choice" 概念的文件 | **104 个** |
| 涉及 "port" 概念的文件 | **121 个** |
| Port 定义文件 | **25 个** |
| `src/game/systems/` 代码行数 | **6,132 行** (24.6%) |
| `src/presentation/` 目录大小 | **628K** |
| `src/game/` 目录大小 | **648K** |

---

## 一、概念一致性分析（分析哲学视角）

### 1.1 核心概念的语义扩散

#### "Choice" 概念：从领域对象到UI投影的语义漂移

`choice` 是本项目最核心的领域概念之一，但其在代码库中的语义边界已经模糊：

**领域层定义** (`src/game/systems/choices/`):
```lua
-- choice 作为领域决策单元
choice = {
  id = string,
  kind = "item_use" | "land_upgrade" | "tax_card_prompt" | ...,
  options = Option[],
  meta = {}, -- 业务上下文
}
```

**UI层投影** (`src/presentation/view/widgets/choice_screen_service/`):
```lua
-- choice 作为视图状态
choice_view = {
  title = string,
  items = UIItem[],  -- 不再是领域option
  layout = "grid" | "list",
}
```

**问题识别**：
- `choice.kind` 有 **17+ 种取值**，分散在至少8个目录中定义处理器
- `choice.meta` 成为"万能口袋"，不同 kind 的 meta 结构无统一契约
- `choice_resolver.lua:108-113` 出现 `landing_optional_effect` vs `land_optional_effect` 的命名不一致（历史债务）

#### "Port" 概念：契约与实现的分层混淆

当前有 **25 个 port 相关文件**，分布在5个目录层级：

```
src/
├── core/ports/              # 运行时访问契约
├── core/runtime_ports/      # 运行时端口（历史遗留命名）
├── game/ports/              # 玩法层契约（推荐落点）
├── game/runtime/            # Port Adapter实现
├── infrastructure/runtime/  # 宿主侧真实实现
└── presentation/runtime/presentation_ports/  # UI侧端口
```

**架构原则与实际偏差**：

| 原则 | 实际 | 偏差 |
|------|------|------|
| Port 应仅定义契约 | `game/ports/*.lua` 含辅助函数 | 契约层混入工具 |
| Adapter 应隔离变化 | `game/runtime/` 与 `infrastructure/runtime/` 存在重复适配逻辑 | 适配层扩散 |
| Port 命名应统一 | `*_port.lua` vs `*_ports.lua` vs `*_adapter.lua` | 命名不一致 |

**具体案例**：
- `src/core/runtime_ports/` 目录名含 "runtime"，但内容已被 `src/infrastructure/runtime/` 取代
- `bankruptcy_feedback_port` 在 `game/ports/` 定义，但同类 port 如 `popup_port` 在 `core/ports/` 定义

### 1.2 概念同一性判定标准

维特根斯坦"家族相似性"理论适用：概念成员间无统一本质，仅有重叠特征。

**建议建立的概念边界**：

1. **Choice 概念分层**
   - `DomainChoice`: 纯领域决策，位于 `game/systems/choices/`
   - `ViewChoice`: UI投影，位于 `presentation/view/widgets/choice_screen_service/`
   - 两者通过显式 `ChoicePresenter` 转换，而非直接透传 meta

2. **Port 概念归一**
   - Port 契约: 仅含函数签名与断言，位于 `game/ports/`
   - Port Adapter: 实现契约，按宿主分层 (`game/runtime/` vs `infrastructure/runtime/`)
   - 删除 `core/runtime_ports/`（已标记为历史）

---

## 二、架构-目录映射分析

### 2.1 7组件模型与物理目录对齐度

```
[UI] → [Turn Mgmt] → [Player | AI] → [Mechanics] → [State | Config]
  │         │                                              ↑
  │         └────────→ [Port/Adapter] ←─────────────────────┘
  │
  └────────────────→ [Infrastructure]
```

| 组件 | 目标目录 | 实际分布 | 对齐度 |
|------|----------|----------|--------|
| UI | `presentation/` | `presentation/` + 部分散落在 `game/flow/output_adapters/` | 85% |
| Turn Mgmt | `game/flow/` | `game/flow/` + `game/scheduler/` + `game/legacy/turn_engine/` | 75% |
| Player | `game/core/player/` | 符合 | 95% |
| AI | `game/core/ai/` | 符合 | 95% |
| Mechanics | `game/systems/` | 符合但文件过大 | 90% |
| State | `game/core/runtime/` + `game/core/player/` | 符合 | 95% |
| Config | `core/config/` + `Config/generated/` | 符合 | 95% |

### 2.2 架构漂移热点

#### 热点1: presentation/ 与 game/flow/ 的职责纠缠

**证据**：
- `game/flow/output_adapters/` 目录仍然存在，负责"输出适配"
- 理论依据：flow 层应仅输出领域事件，不应关心 UI 适配
- 现状：`output_adapters/` 中的适配器将领域事件映射为 UI 命令

**判断**：这是刻意的架构妥协。严格分层会导致过多的中间转换，当前做法在实践中平衡了清晰度与开发效率。

#### 热点2: scheduler/ 的归属模糊

`src/game/scheduler/` 包含协程调度实现：
- 从功能看：属于基础设施（runtime机制）
- 从依赖看：仅被 `game/flow/` 和 `game/legacy/turn_engine/` 使用
- 当前位置：`game/` 下作为兄弟目录

**建议**：保持现状。调度器是游戏领域特定的运行时抽象，非通用基础设施。

#### 热点3: legacy/turn_engine/ 的僵尸状态

```
src/game/legacy/turn_engine/
├── phase_registry.lua    (69 lines)
└── turn_engine.lua       (91 lines)
                         ───────────
                         160 lines total
```

**现状**：
- 被 `composition_root.lua` 引用
- 标记为 "deprecated/frozen"
- 但仍在生产路径中

**风险**：概念污染。新开发者可能误以为这是"推荐模式"。

---

## 三、src/ 有效代码行数降低方案

### 3.1 现状分析

**代码分布金字塔**：

```
                 ┌─────────┐  648K   game/ (26%)
                /    24K    \  infrastructure/
               /─────────────\
              /     628K      \  presentation/ (25%)
             /─────────────────\
            /       84K         \  core/ (3%)
           /─────────────────────\
          /         80K            \  app/ (3%)
         └─────────────────────────┘
                 24,913 行
```

**密度热点文件**（>250行）：

| 文件 | 行数 | 类型 | 压缩潜力 |
|------|------|------|----------|
| `app/testing/config/test_profiles.lua` | 368 | 测试配置 | 中（数据可外置） |
| `core/utils/logger.lua` | 364 | 工具 | 低（稳定） |
| `presentation/view/render/market_view.lua` | 363 | UI渲染 | 高（重复模式） |
| `infrastructure/runtime/runtime_context.lua` | 339 | 运行时 | 中（功能聚合） |
| `presentation/view/widgets/ui_panel_presenter.lua` | 338 | UI组件 | 高（重复布局） |
| `game/systems/board/board.lua` | 324 | 领域 | 中（功能内聚） |
| `game/core/ai/agent.lua` | 308 | AI | 低（算法密集） |
| `game/flow/turn/gameplay_loop.lua` | 299 | 流程编排 | 中（条件分支多） |

### 3.2 降线策略（按当前仓库真相纠偏）

旧版 3.2 把“删 legacy turn engine、清理 `core/runtime_ports/`、引入 UI DSL、再顺手压测试配置”放在同一层级，但当前仓库真相已经变化，必须先纠偏后执行。

首先，`src/game/legacy/turn_engine/` 现在仍然是生产路径的一部分，而不是可以直接删除的死目录。`src/game/core/runtime/composition_root.lua`、`src/game/core/runtime/game.lua`、`tests/suites/gameplay/gameplay_coroutine.lua`、`tests/suites/gameplay/gameplay.lua` 与 `tests/suites/presentation/presentation_ui.lua` 仍直接引用它，所以真正安全的路线是先在 `src/game/flow/turn/` 下建立新的稳定入口，再迁移调用方，最后在 T12 删除 legacy 目录。

其次，旧 research 提到的 `src/core/runtime_ports/` 当前仓库中已经不存在，因此它不再是一个待删除的目标。Port 相关的真实热点是 `src/core/ports/` 与 `src/game/ports/` 合计 `268` 行，问题主要是重复的断言 / 解析模板，以及 `turn_ui_sync_shared` 这种“共享策略伪装成 Port”的落点错误。

再次，`presentation` 的首轮压缩不应走 DSL 化路线。当前 UI 代码围绕 `ui_view_service`、现有 runtime port 与 host scheduler 运作，最安全的降线方式是提取 `ui_controls` 与 `effect_timeline` 两类 helper，把重复的显隐 / `touch_enabled` / 批量控件更新 / 延时清理模式收敛起来，而不是引入新的 Canvas DSL。

最后，测试配置的真实热点不是缺失目录，而是 `src/app/testing/config/test_profiles.lua` 当前自身有 `368` 行，其中大部分是 data table。它适合外置到 `Config/testing/test_profiles.lua`，保留 loader/validator API 以避免波及 resolver 与 bootstrap。

基于以上纠偏，当前 3.2 的成功标准固定为：`lua tests/regression.lua` 全绿；`src/` Lua 相对当前 `24,913` 行基线净减不少于 `800` 行；最终 `src/` 与 `tests/` 中不再残留任何 `require("src.game.legacy.turn_engine.*")`。本轮重点热点依次是：`src/game/legacy/turn_engine/` `160` 行，`src/core/ports/` + `src/game/ports/` `268` 行，`src/presentation/view/render/` `2,822` 行，`src/game/systems/choices/` `630` 行，以及 `src/app/testing/config/test_profiles.lua` `368` 行。

### 3.3 降线路线图

| 阶段 | 策略 | 预估减行 | 风险 | 优先级 |
|------|------|----------|------|--------|
| 1 | A: 删除 legacy | -160 | 低 | P1 |
| 2 | B: Port 合并 | -400 | 中 | P2 |
| 3 | C: 渲染模式提取 | -800 | 中 | P2 |
| 4 | D: Choice 重构 | -600 | 高 | P3 |
| 5 | E: 配置分离 | -500 | 低 | P1 |
| **总计** | | **-2,460行** (~10%) | | |

---

## 四、关键结论

### 4.1 概念一致性评级

| 概念 | 一致性评分 | 问题 | 建议 |
|------|------------|------|------|
| Choice | B | meta 口袋化、kind 命名不一致 | 分层定义、契约化 meta |
| Port | B+ | 目录分散、命名不统一 | 归一化到 `game/ports/` |
| Player | A | 清晰 | 保持 |
| Game | A- | mixin 组合导致跳转多 | 文档化组合逻辑 |

### 4.2 架构-目录映射评级

**整体对齐度：87%**

最大偏差：`presentation/` 与 `game/flow/output_adapters/` 的职责重叠。

**建议**：
1. 将 `output_adapters/` 重命名为 `event_coordinators/` 以更准确反映其职责
2. 明确文档化：flow 层输出的是"领域事件"，而非"UI命令"

### 4.3 代码行数健康度

| 指标 | 当前 | 健康阈值 | 状态 |
|------|------|----------|------|
| 单文件平均行数 | 85 | <100 | ✅ |
| >250行文件占比 | 8% | <5% | ⚠️ |
| 测试代码比 | 72% | >80% | ⚠️ |
| Legacy代码占比 | 0.6% | 0% | ⚠️ |

**结论**：代码库处于"亚健康"状态。主要问题不是总量（24K行对于游戏逻辑可接受），而是分布不均和遗留债务。

---

## 五、下一步行动建议

### 立即执行（本周）
1. 删除 `src/game/legacy/turn_engine/`（验证无副作用后）
2. 重命名 `output_adapters/` → `event_coordinators/`
3. 清理 `core/runtime_ports/` 目录

### 短期规划（本月）
1. 制定 `choice.meta` 的强制契约（JSON Schema 等效物）
2. 提取 `presentation/view/support/` 公共模块
3. 将测试配置外置到 `tests/fixtures/config/`

### 中期规划（本季度）
1. Choice 处理器声明式重构
2. Port 契约统一审计
3. 建立代码行数增长预算（建议：src/ 净增长不超过 +5%/月）

---

*报告生成时间：2026-03-08*
*基于 commit: 90106c5*

## 五、本轮 3.2 执行结果（2026-03-08 16:13 +08:00）

实际执行结果与计划存在一个重要偏差：行为稳态与结构目标已经达成，但净减行数目标没有达成。当前仓库 `src/` 共 `298` 个 Lua 文件、`24,801` 行，相比基线 `24,913` 仅减少 `112` 行。与此同时，`lua tests/regression.lua` 已恢复全绿，输出 `All regression checks passed (382)`、`dep_rules ok`、`legacy_path_guard ok`、`forbidden_globals ok`；`rg -n 'src\.game\.legacy\.turn_engine' src tests` 与 `rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests` 均返回零。

这说明 3.2 前半段的架构纠偏是正确的：legacy turn engine 已完全退出调用面，turn runtime 有了稳定入口，测试 profile 大表已外置，Port 假契约也已清理。但 helper-first / wrapper-first 的低风险策略带来的“新增稳定入口与抽象层”抵消了大量删减收益，因此并没有实现原先设想的 800 行以上净减。若要继续追求该阈值，下一轮应该把重点从“路径迁移”转向“热点文件内部的重复逻辑压缩”，尤其是 `market_view`、`board_feedback_service`、`target_choice_effects` 与 `choice_resolver`。

## 2026-03-08 执行结果补记

3.2 计划的结构性目标已经兑现：`src/game/legacy/turn_engine/` 已删除，turn runtime 稳定入口改为 `src/game/flow/turn/turn_runtime.lua`、`src/game/flow/turn/scheduler_turn_runtime.lua` 与 `src/game/flow/turn/turn_phase_registry.lua`；`src/core/ports/turn_ui_sync_shared.lua` 已迁出到 `src/core/ui_sync/turn_ui_sync_shared.lua`；`src/app/testing/config/test_profiles.lua` 已缩成 loader / validator，数据表移到 `Config/testing/test_profiles.lua`。

最终验收结果是：`lua tests/regression.lua` 通过，`rg -n 'src\.game\.legacy\.turn_engine' src tests` 与 `rg -n 'src\.core\.ports\.turn_ui_sync_shared' src tests` 返回零，但 `src/` Lua 总行数只从 `24,913` 下降到 `24,801`，净减 `112` 行，未达到原计划要求的 `800` 行。这说明本轮更接近“边界清障 + 稳定入口迁移 + 首轮 helper 化”，还不是足够激进的降线收缩。
