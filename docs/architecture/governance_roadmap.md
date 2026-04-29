# 架构治理路线图

本文档记录 10 层架构模型与三个真源（物理目录名、`tools/quality/arch/config.json`、架构文档）之间的对齐债务，并为后续治理决策提供事实基线。目标读者：架构守门人、执行跨层重构的开发者、新增模块前需确认层归属的人。本文档不规划具体的代码搬迁 diff，不替读者裁决尚未达成共识的架构决策。

配套阅读顺序：`docs/architecture/layer-model.md` → `docs/architecture/boundaries.md` → 本文档 → `docs/architecture/health_signals.md`。

---

## Chapter 1 — 现状对齐缺口（Alignment Debt Snapshot）

### 1.1 逻辑层 ↔ 物理目录错位

下表仅列出声明物理路径与逻辑层名称存在偏差的三层；其余七层路径与层名一致，不重复列出。

| 逻辑层 | 已声明物理目录 | 错位类型 | 真源锚点 |
|--------|--------------|---------|---------|
| infrastructure | `src/host/` | 目录名与层名不同（host ≠ infrastructure） | `layer-model.md:11-23` |
| presentation | `src/ui/` + `src/ui/ports/` | 单层对应两个物理目录 | `layer-model.md:11-23` |
| ai | `src/computer/` | 目录名与层名不同（computer ≠ ai） | `layer-model.md:11-23` |

### 1.2 config.json 中的 6 条 Exception 总览

| # | 名称 | 路径范围 | 含义 | 真源行号 |
|---|------|---------|------|---------|
| 1 | `host_bridge_exception` | `src.host.global_aliases` | 放行 host 层对 global_aliases 的跨层引用 | `tools/quality/arch/config.json:18-22` |
| 2 | `infrastructure_runtime_bridges` | `config.content/gameplay` 的 runtime_refs/constants 与 `rules.vehicle` | 放行 infrastructure 层对 runtime 引用及 rules.vehicle 的跨层引用 | `tools/quality/arch/config.json:24-31` |
| 3 | `runtime_state_bridges` | `player.actions.state_ops.*`、`rules.endgame.game_victory` | 放行上述路径对 state 层的跨层引用 | `tools/quality/arch/config.json:33-39` |
| 4 | `systems_choice_bridges` | `player.choices.*` | 放行 player.choices 下所有模块的跨层引用 | `tools/quality/arch/config.json:41-46` |
| 5 | `state_access` | `state` 下 6 个模块（见 1.3 节） | 将这 6 个模块重新归类到 core component | `tools/quality/arch/config.json:48-58` |
| 6 | `player_state_bridge` | `state.player_state` | 将 player_state 重新归类到 runtime component | `tools/quality/arch/config.json:60-65` |

### 1.3 Component vs Layer 对齐缺口

`tools/quality/arch/config.json:102-109` 将 `player` 与 `state` 两个逻辑层合并声明为名为 `runtime` 的单一 component。`docs/architecture/layer-model.md` 中 player 与 state 是独立的两层，各有独立的职责边界与物理目录。

**这是文档与可执行模型之间最大的单点缺口**：arch 扫描工具所执行的 component 划分与 layer-model.md 所声明的 10 层模型在此处不一致，导致任何依赖 config.json component 定义的自动化检查结果均无法直接映射回层模型。

exception `state_access`（`config.json:48-58`）将 state 层下 6 个模块归入 core component；exception `player_state_bridge`（`config.json:60-65`）将 `state.player_state` 归入 runtime component——两条 exception 均在 runtime component 合并的前提下生效，与层模型的独立边界进一步偏离。

### 1.4 src/state/ 文件分组

`src/state/` 下共 11 个 `.lua` 文件，按语义分为 7 组：

- **玩家持久数据**：`player_state.lua`
- **棋盘持久数据**：`board_state.lua`
- **游戏根对象**：`game_state.lua`
- **回合运行时**：`turn_state.lua`、`runtime_state.lua`
- **UI 冻结-释放**：`landing_visual_hold.lua`、`release_scheduler.lua`、`deferred_dirty.lua`
- **工具与适配**：`event_log.lua`、`vehicle_runtime_source.lua`
- **宿主集成**：`ui_role_globals.lua`

其中，exception `state_access`（`config.json:48-58`）涉及的 6 个模块为：`deferred_dirty`、`landing_visual_hold`、`release_scheduler`、`runtime_state`、`ui_role_globals`、`vehicle_runtime_source`；exception `player_state_bridge`（`config.json:60-65`）涉及 `player_state`。两条 exception 合计覆盖 11 个文件中的 7 个。

---

## Chapter 2 — 治理目标与不动的边界（Goals & Non-Goals）

本章收紧治理范围。治理边界不清晰，执行时会产生范围蔓延（scope creep）；本章的作用是在 Chapter 3 决策点展开之前，先把"动什么"和"不动什么"钉死。

### 2.1 In-scope（治理纳入范围）

本轮治理动作覆盖以下四个维度：

- **物理目录名对齐**：`src/` 下 `host/`、`computer/`、`ui/` 三个目录与逻辑层名之间的错位，纳入命名决策（具体方案见 Chapter 3）。
- **exception 清零或显式注释**：`tools/quality/arch/config.json` 中现存 6 条 exception，每条须在本路线图执行完毕后处于以下两种状态之一：已删除（对应错位已修复），或附有机器可读注释说明保留理由。
- **`src/state/` 归属决策**：11 个文件按 7 组分类的归属方向，须在本路线图中形成决策记录（具体文件去向见 Chapter 4）。
- **架构文档交叉引用更新**：`docs/architecture/layer-model.md`、`boundaries.md`、`health_signals.md` 及 `AGENTS.md` 的"按任务找文档"表，须在治理完成后与实际目录结构保持一致。

### 2.2 Out-of-scope（明确不在本轮治理范围）

以下事项本轮**不做**：

- **新增任何层或目录**。包括 `src/board/` 这类"看起来该建"的目录——在 Chapter 3 决策点明确之前，不得将其作为既成事实落地。
- **端口 / 适配器内部协议改动**。Port 接口签名、Adapter 实现细节不在本轮触碰范围。
- **任何代码逻辑修改**。本路线图不改变任何业务行为；所有动作限于目录结构、配置文件、文档。
- **CI 流水线改造**。现有 `verify-fast` / `verify-full` 车道不做结构性变更。
- **`forbidden_dependency_rules` 规则集变更**。`arch/config.json` 中的禁止依赖规则集本轮只动 `exception`，不动 `forbidden_dependency_rules`。

### 2.3 Definition of Done（路线图文档自身的完成标准）

下表描述本路线图文档何时算"完成"——这是文档级 DoD，不是各治理波次的执行 DoD。

| 项 | 完成标准 |
|----|---------|
| 文档落位 | `docs/architecture/governance_roadmap.md` 存在，且被 `AGENTS.md` "按任务找文档"表以独立行索引 |
| 决策点保留 | D1 / D2 主路径选择与 `src/state/` 三处歧义点，未被本文档擅自决定；Chapter 3 / Chapter 4 保留空白决策槽 |
| 可执行性 | 每个治理波次给出至少一条可直接运行的验证命令（`lua tools/quality/arch.lua check` / `busted --run contract` / `/verify-fast` / `/verify-full`） |
| 反向链接 | `layer-model.md`、`boundaries.md`、`health_signals.md` 顶部各添加指向本文档的 "See also" 条目 |
| exception 覆盖 | `config.json` 中 6 条 exception 在文档中逐条出现，每条标注"待删除"或"保留理由" |

---

## Chapter 3 — 显式决策点（Explicit Decision Points）

本章集中收纳路线图执行前必须由人拍板的事项。所有选项以并列方式呈现，不附推荐、不暗示倾向；任何一项被默认推进都会污染后续 Chapter 4-6 的执行假设。每个决策点末尾的 *Action required from user* 行标注谁需要在何时给出回复。

### 3.1 D1 vs D2 主路径选择

D1 与 D2 是整份路线图的分叉源头：D1 修改物理目录名以让代码与 `docs/architecture/layer-model.md` 字面对齐；D2 保留物理目录、在文档与 `tools/quality/arch/config.json` 中以映射表与注释承载差异。

| 维度 | D1 破坏性重命名 | D2 保留物理名 + 映射表 |
|------|----------------|----------------------|
| 爆炸半径 | `host/` `computer/` `ui/` 三处目录改名波及全仓 require | 零目录变更，改动集中在 `layer-model.md` 与 `arch/config.json` 注释 |
| git blame 影响 | 改名提交会在 blame 链中插入一层，需配合 `.git-blame-ignore-revs` 维护 | blame 历史不受影响 |
| require 路径变更数量（估） | 量级与 `src/host/` `src/computer/` `src/ui/` 下被引用的模块总数同阶（全仓批量改 `require "src.host.*"` 等） | 0 |
| 新人认知税 | 一次性：上手即看到 infrastructure / ai / presentation 与文档同名 | 持续：需先读 `layer-model.md` 的映射表才能把 host/computer/ui 与逻辑层对应 |
| 文档与代码一致性 | 目录名 = 层名，文档无需解释差异 | 文档必须长期维护映射表，且每次新增层都要更新 |
| 回滚难度 | 需反向重命名 + 再次更新所有 require | 删除映射表段落即可 |
| `arch/config.json` exception 数量影响 | `host_exposes_assets` 等基于物理名的 exception 需同步重命名；可顺势审视是否仍必要 | exception 数量不变，需要逐条加注释解释为何物理名与逻辑层不一致 |
| 工具链输出可读性（arch.lua / scrap / crap） | 报告中的层名与目录名一致，定位无歧义 | 报告需读者自行做"目录 → 层"二次翻译 |
| 与外部协作的短期成本 | 进行中的 PR、外部分支、Eggy 宿主对接文档需同步更新 | 短期零摩擦 |
| 与外部协作的长期成本 | 改名完成后无额外解释成本 | 每次跨团队沟通都需复述映射表 |
| 未来再加层时的兼容性 | 新层直接按目标命名落地，与既有命名风格一致 | 新层若按目标名落地，将与既有 host/computer/ui 风格不一致；若延续物理名风格，映射表持续膨胀 |
| 与 Chapter 3.3 / 3.4 的耦合 | 拆 component、新增 `board/` 顺势而为 | 拆 component 与新增目录需独立论证 |

混合策略示例（仅作举例，不含偏好）：仅对 `host → infrastructure` 走 D1，`computer/` `ui/` 走 D2；或反之。混合策略会同时承担两套成本中的部分项，需逐目录在上表中重新评估。

**Action required from user**：在进入 Chapter 4 执行清单前，明确选择 **D1** / **D2** / **混合策略（需指定哪些目录走 D1、哪些走 D2）** 之一。

### 3.2 src/state/ 拆解的三个歧义点

`src/state/` 在真源 3（`docs/architecture/layer-model.md`）中没有对应的逻辑层。下列三项各自独立、互不蕴含，需分别裁定。

#### 3.2.1 game_state.lua 归属

| 选项 | 处置 | 影响 |
|------|------|------|
| A | 保留在 `src/state/` 作为根状态 | `src/state/` 目录必须最小化保留；`arch/config.json` 中需为 state component 保留独立条目 |
| B | 迁入 `src/core/assembly/` 视为装配产物 | 若 3.2.2、3.2.3 也外迁，`src/state/` 目录可完全消解；core/assembly 模块体积上升 |

**Action required from user**：在选项 A / B 之间裁定 game_state.lua 的物理归属。

#### 3.2.2 runtime_state.lua 是否拆分

| 选项 | 处置 | 影响 |
|------|------|------|
| A | 整体迁入 `src/turn/` | 不需识别字段边界；`src/turn/` 承担 runtime_state 全部字段，包括与 UI 相关的部分 |
| B | 按职责拆为 turn_runtime + ui_runtime，分别落 `src/turn/` 与 `src/ui/` | 需先做字段级职责划分；拆分后两层各自只持有本层字段 |
| C | 迁入 `src/core/runtime/`（新建子目录） | 引入 `src/core/runtime/` 这一新目录名；`src/turn/` `src/ui/` 不变；按 Chapter 2 Out-of-scope，新增子目录本身需登记为待决策项 |

**Action required from user**：在选项 A / B / C 之间裁定 runtime_state.lua 的处置方式；若选 B，需追加确认字段划分由谁负责。

#### 3.2.3 UI 冻结-释放三件套（landing_visual_hold / release_scheduler / deferred_dirty）归属

| 选项 | 处置 | 影响 |
|------|------|------|
| A | 迁入 `src/ui/` 视为 presentation 内部状态 | UI 层吸收三件套全部字段与调度逻辑 |
| B | 迁入 `src/turn/` 视为回合协调机制 | turn 层在持有回合状态之外，再持有 UI 节流相关字段；SRP 评估需重新做 |

**Action required from user**：在选项 A / B 之间裁定三件套归属。

### 3.3 Component 模型对齐

针对 `tools/quality/arch/config.json:102-109` 的 `runtime` component 是否拆分。

| 选项 | 处置 | 与 D1/D2 的耦合 | 对 exception 的影响 |
|------|------|----------------|--------------------|
| A | 拆为独立的 `player` 与 `state` 两个 component | D1 路径下与目录拆解同步进行 | `player_state_bridge` 与 `state_access` 中部分条目有机会消除 |
| B | 保留 `runtime` 合并 | D2 路径下与"保留物理名"策略一致 | 现有 exception 全部保留，需逐条补注释解释合并原因 |

**Action required from user**：在选项 A / B 之间裁定 component 模型；若 3.1 选 D2 而此处选 A，需额外说明为何物理目录不拆而 component 拆。

### 3.4 是否为 board 数据建立独立目录

`src/state/board_state.lua` 在真源 3 中标注为"应迁 `src/board/` 或 `src/core/`"。`src/board/` 目前不存在，属于 Chapter 2 Out-of-scope 中的"新增层 / 目录"。

| 选项 | 处置 | 影响 |
|------|------|------|
| A | 建立 `src/board/` 并升格为新层 | `docs/architecture/layer-model.md` 需新增第 11 层声明；`arch/config.json` 需新增对应 component 与依赖规则；与 3.1 的 D1/D2 选择独立 |
| B | 并入 `src/core/` | 不增加新层；board 概念在文档层级模型中不再独立呈现 |
| C | 维持现状（board_state.lua 留在 `src/state/`） | 与 3.2.1 选项 A 兼容；与 3.2.1 选项 B 冲突（state/ 消解后 board_state.lua 无处可去） |

**Action required from user**：在选项 A / B / C 之间裁定 board 数据归属；若选 A，需追加确认新层在 `layer-model.md` 中的位置与依赖方向。

---

## Chapter 4 — src/state/ 文件去向矩阵（File Disposition Matrix）

本表以 Chapter 3 各决策点的拍板结果为输入。读者根据 Chapter 3 实际选定的选项，按对应列读出每个文件的最终目标路径；D1/D2 列之外的子决策组合差异在"D1 路径下去向"列内联展开。

### 4.1 文件去向矩阵主表

| 文件 | 当前位置 | 决策依赖 | D1 路径下去向 | D2 路径下去向 | 备注 |
|------|----------|----------|---------------|---------------|------|
| `player_state.lua` | `src/state/player_state.lua` | `3.3` | 3.3-A → `src/player/state.lua`；3.3-B → `src/state/player_state.lua` | `src/state/player_state.lua` | 3.3-A 时 exception #6 `player_state_bridge`（`config.json:60-65`）消除条件成立；3.3-B 时 bridge 保留 |
| `board_state.lua` | `src/state/board_state.lua` | `3.4` | 3.4-A → `src/board/state.lua`（需新建 `src/board/`）；3.4-B → `src/core/state/board.lua`；3.4-C → `src/state/board_state.lua` | 3.4-A → `src/board/state.lua`；3.4-B → `src/core/state/board.lua`；3.4-C → `src/state/board_state.lua` | 3.4-A 新建目录须在 Chapter 3.4 拍板后方可落地；D1/D2 对本文件无差异，去向完全由 3.4 子选项决定 |
| `game_state.lua` | `src/state/game_state.lua` | `3.2.1` | 3.2.1-A → `src/state/game_state.lua`；3.2.1-B → `src/core/assembly/game.lua` | 3.2.1-A → `src/state/game_state.lua`；3.2.1-B → `src/core/assembly/game.lua` | D1/D2 对本文件无差异；去向由 3.2.1 子选项决定 |
| `turn_state.lua` | `src/state/turn_state.lua` | `—` | `src/turn/state.lua` | `src/turn/state.lua` | 无歧义，归属 turn 子系统；D1/D2 路径相同；D2 不强制保留 `state/` 物理目录，仍可搬迁 |
| `runtime_state.lua` | `src/state/runtime_state.lua` | `3.2.2` | 3.2.2-A → `src/state/runtime_state.lua`；3.2.2-B → `src/turn/runtime.lua`；3.2.2-C → `src/core/runtime/state.lua` | 3.2.2-A → `src/state/runtime_state.lua`；3.2.2-B → `src/turn/runtime.lua`；3.2.2-C → `src/core/runtime/state.lua` | D1/D2 对本文件无差异；去向由 3.2.2 子选项决定；3.2.2-C 需新建 `src/core/runtime/` |
| `landing_visual_hold.lua` | `src/state/landing_visual_hold.lua` | `3.2.3` | 3.2.3-A → `src/ui/landing_visual_hold.lua`；3.2.3-B → `src/turn/landing_visual_hold.lua` | 3.2.3-A → `src/ui/landing_visual_hold.lua`；3.2.3-B → `src/turn/landing_visual_hold.lua` | UI 冻结-释放三件套决策依赖相同，见 `release_scheduler.lua` 与 `deferred_dirty.lua` 行 |
| `release_scheduler.lua` | `src/state/release_scheduler.lua` | `3.2.3` | 3.2.3-A → `src/ui/release_scheduler.lua`；3.2.3-B → `src/turn/release_scheduler.lua` | 3.2.3-A → `src/ui/release_scheduler.lua`；3.2.3-B → `src/turn/release_scheduler.lua` | 与 `landing_visual_hold.lua` 同组，三件套须同选项整体迁移，不可拆分 |
| `deferred_dirty.lua` | `src/state/deferred_dirty.lua` | `3.2.3` | 3.2.3-A → `src/ui/deferred_dirty.lua`；3.2.3-B → `src/turn/deferred_dirty.lua` | 3.2.3-A → `src/ui/deferred_dirty.lua`；3.2.3-B → `src/turn/deferred_dirty.lua` | 与 `landing_visual_hold.lua` 同组，三件套须同选项整体迁移，不可拆分 |
| `event_log.lua` | `src/state/event_log.lua` | `—` | `src/core/utils/event_log.lua` | `src/core/utils/event_log.lua` | 无歧义，属工具层；D1/D2 路径相同；无 exception 关联 |
| `vehicle_runtime_source.lua` | `src/state/vehicle_runtime_source.lua` | `3.3` | 3.3-A → `src/player/vehicle_runtime_source.lua`；3.3-B → `src/state/vehicle_runtime_source.lua` | `src/state/vehicle_runtime_source.lua` | exception #5 `state_access`（`config.json:48-58`）涉及；3.3-A 时随 component 拆分迁移，#5 消除条件部分成立；3.3-B 时 #5 保留 |
| `ui_role_globals.lua` | `src/state/ui_role_globals.lua` | `—` | `src/infrastructure/ui_role_globals.lua` | `src/host/ui_role_globals.lua` | 属宿主集成层；D1 归 `src/infrastructure/`，D2 归 `src/host/`；exception #5 `state_access`（`config.json:48-58`）涉及；两路径均需确认目录是否已存在 |

### 4.2 矩阵填写约束

1. **路径必须具体**：D1/D2 列不允许写"待定"。决策点组合若产生本表未列举的情况，须在备注列显式标注 `decision combo gap` 并说明缺失的组合条件。
2. **去向相同时允许重复**：若某文件在 D1 与 D2 下目标路径一致（如 `event_log.lua`、`turn_state.lua`），两列写相同路径，不做合并。
3. **新建目录的前置条件**：备注列凡出现新目录（如 `src/board/`、`src/core/runtime/`），该目录只能在对应 Chapter 3 子节拍板后落地，不得提前创建。
4. **exception 引用格式**：备注列提及 exception 消除时，须同时写出编号（`#1`–`#6`）与 `config.json` 行号区间。
5. **三件套原子性**：`landing_visual_hold.lua`、`release_scheduler.lua`、`deferred_dirty.lua` 三行的 3.2.3 选项必须保持一致，不允许三件套拆分到不同目标目录。
6. **跨决策耦合标注**：若某文件的去向同时受两个及以上决策点影响，备注列须列出所有相关决策点编号，并说明组合逻辑（AND/OR 关系）；本表当前无此情况，若后续决策点新增交叉，须在此处补充说明。

---

## Chapter 5 — Exception 治理表（Exception Governance Table）

本章对 `tools/quality/arch/config.json` 中现存 6 条 exception 逐条标注治理动作。每条 exception 在路线图执行后，要么被删除（从 config.json 移除），要么以机器可读注释保留（注释格式见 5.2）。

### 5.1 Exception 治理表主表

| # | 名称 | 真源行号 | 治理动作 | 触发条件 | 保留时所需注释字段 | 与 Chapter 3 决策点的耦合 |
|---|------|----------|----------|----------|-------------------|--------------------------|
| 1 | `host_bridge_exception` | `config.json:18-22` | **按子决策分支**：D1 执行后 `host/` 改名为 `infrastructure/` 且 global_aliases 不再需要跨层引用 → **删除**；D1 未执行或改名后仍存在跨层引用 → **保留并加注释** | D1 路径下 `host/` 目录完成改名，且 `src.host.global_aliases` 的所有消费方已迁移至同层或通过 Port 访问 | `governance_anchor`（指向本节 §5.1）；`retain_reason`（global_aliases 尚有跨层消费方，改名未完成）；`review_cadence`（每里程碑复审一次） | 3.1 |
| 2 | `infrastructure_runtime_bridges` | `config.json:24-31` | **按子决策分支**：W3 + W4 完成后 infrastructure 不再引用 runtime 且 `rules.vehicle` 跨层引用消除 → **删除**；W3/W4 任一未完成或跨层引用仍存在 → **保留并加注释** | 3.2.2 选项决定 runtime_state 拆分方向；拆分完成后 infrastructure 层对 runtime 的引用路径是否已全部消除；`rules.vehicle` 是否已归入合规层 | `governance_anchor`（指向本节 §5.1）；`retain_reason`（D1/D2 尚未完成，infrastructure 仍需引用 runtime_refs/constants 或 rules.vehicle）；`review_cadence`（每里程碑复审一次） | 3.1 + 3.2.2 |
| 3 | `runtime_state_bridges` | `config.json:33-39` | **保留并加注释**（主路径）；仅当 3.3 拆 component 后 `player.actions.state_ops` 边界调整导致跨层引用消失 → **删除** | `player.actions.state_ops.*` 对 state 层的引用是否属于设计意图（跨层访问为 use-case 驱动）；3.3 拆分后 state_ops 是否被纳入同层 component | `governance_anchor`（指向本节 §5.1）；`retain_reason`（player.actions.state_ops 对 state 层的访问为 use-case 设计意图，非架构违规）；`review_cadence`（每季度复审一次） | 3.3 |
| 4 | `systems_choice_bridges` | `config.json:41-46` | **按子决策分支**：`player.choices.*` 被纳入 player layer 且跨层引用消除 → **删除**；`player.choices.*` 仍处于 systems 层或跨层引用仍必要 → **保留并加注释** | `player.choices` 下所有模块是否已完成层归属调整；调整后是否仍存在跨层引用 | `governance_anchor`（指向本节 §5.1）；`retain_reason`（player.choices 层归属未完成，跨层引用仍为必要路径）；`review_cadence`（每里程碑复审一次） | 3.1 + 3.3 |
| 5 | `state_access` | `config.json:48-58` | **按子决策分支逐条处置**：6 个模块中，按 3.2.2/3.2.3/3.4 各自迁移目标完成后，对应模块的 exception 条目 → **删除**；迁移未完成的模块条目 → **保留并加注释**（逐模块独立标注） | 各模块迁移状态独立判断：`deferred_dirty`、`landing_visual_hold`、`release_scheduler`、`runtime_state`、`ui_role_globals`、`vehicle_runtime_source` 是否已各自完成归类至 core component | `governance_anchor`（指向本节 §5.1，精确到模块名）；`retain_reason`（具体模块迁移阻塞原因，一句话）；`review_cadence`（每里程碑复审一次，逐模块独立记录） | 3.2.2 + 3.2.3 + 3.4 |
| 6 | `player_state_bridge` | `config.json:60-65` | **按子决策分支**：3.3 选 A（`state.player_state` 迁入 runtime component）→ **删除**；3.3 选 B（`state.player_state` 原地保留）→ **保留并加注释** | 3.3 决策结果：选 A 时 `state.player_state` 已迁移至 runtime，跨层引用消除；选 B 时迁移未执行 | `governance_anchor`（指向本节 §5.1）；`retain_reason`（3.3 选 B，state.player_state 原地保留，跨层引用为已知设计妥协）；`review_cadence`（每里程碑复审一次） | 3.3 |

### 5.2 注释格式约定

保留 exception 时，必须在 `config.json` 对应条目内附带以下三个注释字段，字段名固定，值为单行字符串：

- `governance_anchor`：指向本路线图的精确锚点（格式：`docs/architecture/governance_roadmap.md#5-1`）
- `retain_reason`：一句话说明该 exception 当前不可删除的原因，禁止使用"暂时""后续"等模糊词
- `review_cadence`：复审节奏，取值为 `per-milestone`（每里程碑）或 `quarterly`（每季度）

示例（以 `host_bridge_exception` 保留场景为例）：

```jsonc
{
  "name": "host_bridge_exception",
  // governance_anchor: docs/architecture/governance_roadmap.md#5-1
  // retain_reason: host/ 改名未完成，global_aliases 仍有跨层消费方尚未迁移至 Port
  // review_cadence: per-milestone
  "component": "host",
  "match": ["^src%.host%.global_aliases$"]
}
```

> **执行前确认项**：`tools/quality/arch/config.json` 当前使用标准 JSON 解析器还是支持注释的 JSONC / 自定义解析器，需在写入注释前确认。若解析器不支持 `//` 注释，改用同名 `_governance` 对象字段承载上述三个字段，键名不变：
>
> ```jsonc
> {
>   "name": "host_bridge_exception",
>   "_governance": {
>     "governance_anchor": "docs/architecture/governance_roadmap.md#5-1",
>     "retain_reason": "host/ 改名未完成，global_aliases 仍有跨层消费方尚未迁移至 Port",
>     "review_cadence": "per-milestone"
>   },
>   "component": "host",
>   "match": ["^src%.host%.global_aliases$"]
> }
> ```

---

## Chapter 6 — 治理波次（Governance Waves）

### 6.1 波次总览

本章将 Chapter 3 的决策点与 Chapter 4-5 的执行项序列化为 7 个线性波次（W1→W7）。每个波次有明确的前置条件、主要动作与可运行验证命令，满足 Chapter 2 声明的 DoD。波次之间严格线性依赖，不允许并行推进。每个波次完成后须在本文档附录更新状态，再进入下一波次。

| Wave | 名称 | 前置条件 | 主要动作 | 主要风险 | 验证命令 |
|------|------|----------|----------|----------|----------|
| W1 | 决策落槽 | 本路线图已落位 | 拍板 D1/D2、3.2.1-3.2.3、3.3、3.4；写入 ADR | 决策点之间耦合矛盾 | 人工 review |
| W2 | 文档与映射表先行 | W1 完成 | 更新 `layer-model.md`；D2 路径下建立逻辑层→物理目录映射表 | 文档与代码改动不一致 | `lua tools/quality/lint.lua` |
| W3 | Component 拆分 | W1 + W2 完成；3.3 已拍板 | 若 3.3-A：拆分 `arch/config.json` 中 `runtime` component | 拆分后 exception 触发新违规 | `lua tools/quality/arch.lua check` + `busted --run contract` |
| W4 | state/ 文件迁移 | W1-W3 完成 | 按 Chapter 4 矩阵迁移 11 个文件；批量更新 require 路径 | require 路径漏改、循环依赖 | `/verify-fast` |
| W5 | 物理目录改名 | W1-W4 完成；D1 或混合策略已选 | 对涉及目录执行改名；同步 `arch/config.json`、require、文档 | 批量改名遗漏；blame 链污染 | `/verify-full` |
| W6 | Exception 清零或注释化 | W1-W5 完成 | 按 Chapter 5 表格逐条处理 6 条 exception | 误删触发回归；注释格式不兼容 | `lua tools/quality/arch.lua check` |
| W7 | 文档反向链接 + 关闭 | W1-W6 完成 | 在相关文档顶部添加 "See also" 锚点；标注路线图状态为 Closed | 反向链接断裂 | `grep` 验证锚点 + 人工 review |

### 6.2 每波次详情卡片

#### W1 — 决策落槽

**前置条件**：
- 本路线图（`docs/architecture/governance_roadmap.md`）已合并至主干
- Chapter 3 全部决策点已被相关责任人阅读

**主要动作**：
- 在 3.1（D1/D2）上拍板：选择"破坏性重命名"或"保留物理名 + 映射表"或混合策略
- 在 3.2.1 上拍板：`game_state.lua` 归属（A 保留 `src/state/` / B 迁入 `src/core/assembly/`）
- 在 3.2.2 上拍板：`runtime_state.lua` 处置（A 整体迁 `src/turn/` / B 拆分 turn_runtime + ui_runtime / C 迁 `src/core/runtime/`）
- 在 3.2.3 上拍板：UI 冻结-释放三件套归属（A 迁 `src/ui/` / B 迁 `src/turn/`）
- 在 3.3 上拍板：`runtime` component 是否拆分为 `player` + `state`（A 拆 / B 保留合并）
- 在 3.4 上拍板：`board_state.lua` 归属（A 新建 `src/board/` / B 并入 `src/core/` / C 维持现状）
- 将以上决策结果以"决策记录"形式追加至本文档附录或独立 ADR（`docs/architecture/adr/`）
- 检查耦合：D2 + 3.3-A（物理不拆但 component 拆）需在 ADR 显式说明理由；3.2.1-B + 3.4-C（state/ 消解但 board_state.lua 留 state/）属冲突组合，必须重新选

**主要风险**：
- 决策组合产生隐性矛盾（如 3.2.1-B 与 3.4-C）
- 决策未落文字，后续波次执行人理解不一致

**验证命令**：

```bash
# W1 无机器验证命令，执行人工 review
# 检查项：ADR 或附录中是否包含 3.1 / 3.2.1 / 3.2.2 / 3.2.3 / 3.3 / 3.4 六个决策点的明确结论
```

**完成判据**：
- Chapter 3 全部决策点有书面结论，已追加至附录或 ADR
- 跨决策耦合矛盾（如存在）已在 ADR 中显式说明处置方式
- 责任人签字或 git commit 记录可追溯

#### W2 — 文档与映射表先行

**前置条件**：
- W1 完成，决策记录已落文字

**主要动作**：
- 打开 `docs/architecture/layer-model.md`，将 W1 决策结果写入对应章节（D1/D2 选择、component 拆分结论、各文件归属）
- 若 W1 选 D2：在 `docs/architecture/layer-model.md` 中新增"逻辑层 → 物理目录"映射表，格式为：

  | 逻辑层 | 物理目录（当前） | 物理目录（目标） |
  |--------|-----------------|-----------------|
  | infrastructure | `src/host/` | `src/host/`（不改名） |
  | presentation | `src/ui/` + `src/ui/ports/` | 同左 |
  | ai | `src/computer/` | 同左 |

- 若 W1 选 D1 或混合策略：在映射表中标注哪些目录将在 W5 改名
- 确认 `docs/architecture/boundaries.md` 中的层边界描述与 W1 决策一致，如有出入则同步修改

**主要风险**：
- 映射表写入后，W4/W5 实际改动与表中描述不一致，导致文档成为误导性参考

**验证命令**：

```bash
lua tools/quality/lint.lua
```

**完成判据**：
- `docs/architecture/layer-model.md` 包含 W1 决策结论
- 若选 D2，映射表已建立且覆盖全部涉及目录
- `lua tools/quality/lint.lua` 无新增错误

#### W3 — Component 拆分

**前置条件**：
- W1 + W2 完成
- W1 中 3.3 决策已拍板（选 A 或 B）

**主要动作**：
- **若 3.3 选 B（不拆分）**：本波次跳过，在本文档附录记录跳过理由，直接进入 W4
- **若 3.3 选 A（拆分）**：
  - 打开 `tools/quality/arch/config.json`，找到 `runtime` component 定义（`config.json:102-109`）
  - 将 `runtime` 拆为两个独立 component：`player` 与 `state`
  - 在 `config.json` 中为 `player` 和 `state` 分别声明允许的依赖关系
  - 检查原 `runtime` 关联的 exception 条目（特别是 `state_access` `config.json:48-58` 与 `player_state_bridge` `config.json:60-65`）：拆分或重新归属
  - 运行 arch check，确认拆分后无新增违规
  - 运行 contract spec，确认边界合约未破坏

**主要风险**：
- 拆分后原 exception 的 component 名称失效，arch check 报告新违规
- `player` 与 `state` 之间存在隐式双向依赖，拆分后暴露循环

**验证命令**：

```bash
lua tools/quality/arch.lua check
busted --run contract
```

**完成判据**：
- `config.json` 中 `runtime` component 已按选择处置（拆分或保留）
- `lua tools/quality/arch.lua check` 无新增违规
- `busted --run contract` 全绿

#### W4 — state/ 文件迁移

**前置条件**：
- W1-W3 全部完成（或 W3 已按跳过流程记录）

**主要动作**：
- 按 Chapter 4 矩阵，逐文件执行迁移（11 个文件，逐行核对决策依赖列）
- 对每个迁移文件，全局搜索其旧路径的 `require` 调用，批量替换为新路径
- 搜索范围：`src/`、`spec/`、`tests/`、`tools/` 下所有 `.lua` 文件
- 三件套（`landing_visual_hold` / `release_scheduler` / `deferred_dirty`）必须按 3.2.3 同选项整体迁移，不允许拆分
- 迁移完成后，检查是否有空目录残留（`src/state/` 若已清空则删除或保留，视 Chapter 4 矩阵说明）
- 运行快速车道验证

**主要风险**：
- require 路径替换遗漏（尤其是动态拼接路径）
- 迁移引入新的跨层循环依赖
- `spec/` 或 `tests/` 中的 mock 路径未同步更新

**验证命令**：

```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run guards
lua tools/quality/arch.lua check
```

> 等价于 `/verify-fast`，此处展开以便逐步排查失败点。

**完成判据**：
- Chapter 4 矩阵中全部 11 个文件已按归属处置
- 全局无旧路径的 `require` 残留
- `/verify-fast` 全绿（lint + behavior + arch + guards 均通过）

#### W5 — 物理目录改名

**前置条件**：
- W1-W4 全部完成
- W1 中 D1 或混合策略已选（若 W1 选纯 D2，本波次跳过并记录）

**主要动作**：
- 按 W2 映射表，对需要改名的物理目录执行 `git mv`：
  - `src/host/` → `src/infrastructure/`（若适用）
  - `src/computer/` → `src/ai/`（若适用）
  - `src/ui/` → `src/presentation/`（若适用）
- 更新 `tools/quality/arch/config.json` 中所有涉及旧目录名的 `path` 字段
- 全局替换所有 `.lua` 文件中旧目录名的 `require` 路径
- 更新 `docs/architecture/layer-model.md`、`docs/architecture/boundaries.md` 中的目录引用
- 更新 `AGENTS.md` 中的目录说明（如有）
- 配合 `.git-blame-ignore-revs` 维护改名提交，避免污染 blame 链
- 运行完整车道验证

**主要风险**：
- `git mv` 后 IDE / CI 缓存仍引用旧路径
- 批量 require 替换遗漏嵌套目录（如 `src/host/sub/`）
- blame 链在改名后断裂，历史追溯困难

**验证命令**：

```bash
lua tools/quality/lint.lua
busted --run behavior
busted --run contract
busted --run guards
busted --run tooling
lua tools/quality/arch.lua check
```

> 等价于 `/verify-full`，此处展开以便逐步排查失败点。

**完成判据**：
- 旧目录名在 `src/` 下不再存在（`ls src/` 输出与 W2 映射表目标列一致）
- `config.json` 中无旧目录名引用
- `/verify-full` 全绿
- W2 映射表"物理目录（目标）"列全部标注为"已完成"

#### W6 — Exception 清零或注释化

**前置条件**：
- W1-W5 全部完成（或 W5 已按跳过流程记录）

**主要动作**：
- 打开 `tools/quality/arch/config.json`，对照 Chapter 5 表格，逐条处理 6 条 exception：
  - **可删除的 exception**（Chapter 5 触发条件已满足）：直接从 `config.json` 中移除该条目
  - **需保留的 exception**：按 Chapter 5 §5.2 格式添加 `governance_anchor` / `retain_reason` / `review_cadence` 三字段
  - **待处理的 exception**：在本文档附录更新状态，说明阻塞原因与预计处理时间
- 处理完成后，运行 arch check，对照 Chapter 5 表格人工核查每条 exception 的处置结果

**主要风险**：
- 误删仍被代码依赖的 exception，导致 arch check 报告新违规或运行时错误
- 注释格式与 `arch.lua` 解析器不兼容，导致注释被忽略或解析失败（执行前确认项）

**验证命令**：

```bash
lua tools/quality/arch.lua check
busted --run behavior
busted --run guards
```

**完成判据**：
- Chapter 5 表格中全部 6 条 exception 的"治理动作"列已更新状态（已删除 / 已加注释 / 待处理+阻塞说明）
- `lua tools/quality/arch.lua check` 输出的 exception 数量符合 Chapter 5 预期
- `busted --run behavior` 与 `busted --run guards` 全绿

#### W7 — 文档反向链接 + 关闭

**前置条件**：
- W1-W6 全部完成

**主要动作**：
- 在以下文档顶部（导引段或第一个 `##` 标题之前）添加 "See also" 锚点，格式为：

  ```
  > **See also**: 治理路线图 → `docs/architecture/governance_roadmap.md`
  ```

  涉及文件：
  - `docs/architecture/layer-model.md`
  - `docs/architecture/boundaries.md`
  - `docs/architecture/health_signals.md`
  - `AGENTS.md`（在"按任务找文档"表中追加一行索引）

- 在本文档（`governance_roadmap.md`）顶部导引段下方，将状态标注为：

  ```
  **状态**：Closed — YYYY-MM-DD（以实际完成日期替换）
  ```

- 确认 W1 ADR 或附录中的决策记录已包含最终状态

**主要风险**：
- 反向链接路径拼写错误，导致链接断裂
- 文档在后续迭代中被移动，锚点失效

**验证命令**：

```bash
grep -r "governance_roadmap" docs/architecture/layer-model.md docs/architecture/boundaries.md docs/architecture/health_signals.md AGENTS.md
```

**完成判据**：
- 上述 `grep` 命令在 4 个文件中均有匹配输出
- 本文档顶部状态标注为 `Closed — YYYY-MM-DD`
- W1-W6 全部波次在本文档附录中标注为"已完成"，无"待处理"遗留

### 6.3 波次顺序约束

波次 W1→W7 必须严格线性执行。W2 与 W3 虽然在代码层面看似独立，但 W2 的映射表是 W3 拆分操作的输入依据；W3 的 component 边界是 W4 迁移路径的前提。任何波次的跳过或合并都须在本文档附录显式记录跳过理由与替代验证手段，否则后续波次的完成判据无法成立。

W4（文件迁移）与 W5（目录改名）不可合并为单次提交。两者产生的 git diff 类型不同：W4 是文件内容与 require 路径的变更，W5 是目录结构的重命名。合并提交会使回滚粒度粗化，一旦 W5 引入问题，无法在不撤销 W4 的情况下单独回退。

每个波次完成后，须将 Chapter 5 表格中相关 exception 条目的"治理动作"列状态同步更新（已删除 / 已加注释 / 待处理），再提交本文档的状态变更，再进入下一波次。

---

## Chapter 7 — 风险与回滚（Risks & Rollback）

### 7.1 风险登记表

| 风险 ID | 描述 | 影响波次 | 触发条件 | 缓解措施 | 回滚动作 |
|---------|------|----------|----------|----------|----------|
| R1 | D1 改名后 Eggy 宿主对接路径失效 | W5 | `src/host/` 下任意目录重命名，宿主侧 `require` 路径未同步更新 | 改名前在 OQ-4 中确认宿主文档引用清单；改名与路径替换在同一 commit 完成 | `git revert` 至 `governance/W4-done` tag，恢复原目录名 |
| R2 | W3 component 拆分引入循环依赖 | W3 | `runtime` 拆分后新 component 之间存在双向 `require` | 拆分前用 `lua tools/quality/arch.lua check` 验证依赖图；拆分后立即重跑 | 回退至 `governance/W2-done` tag，撤销 component 拆分 commit |
| R3 | W4 `state/` 文件迁移后 require 路径遗漏 | W4 | 动态拼接路径（如 `require("src.state." .. name)`）未被静态扫描覆盖 | 迁移前用 `grep -rn 'require.*state'` 全量扫描；迁移后运行 behavior 测试套件 | 回退至 `governance/W3-done` tag |
| R4 | W6 exception 注释解析器不兼容 | W6 | `arch/config.json` 解析器不支持 `//` 注释（见 OQ-1），导致 exception 注释格式无法被工具读取 | 在 W1 阶段确认 OQ-1；若不支持则改用 `_governance` 字段方案（见 §5.2） | 回退至 `governance/W5-done` tag，恢复无注释格式 |
| R5 | W7 反向链接被后续 PR 误删 | W7 及之后 | 后续 PR 修改 `layer-model.md` / `boundaries.md` 等文件时未保留锚点 | 在 PR 模板中加入反向链接检查项（见附录 C）；W7 完成后在 CI 中加 `grep` 断言 | 从 `governance/W7-done` tag cherry-pick 反向链接 commit |
| R6 | 决策点组合矛盾（如 3.2.1-B + 3.4-C 冲突） | W1 决策落槽后 | 多个决策点独立选型，组合后产生层边界矛盾或 exception 数量超出预期 | W1 决策记录须同时填写"已识别的耦合影响"字段（见附录 B）；决策前交叉验证 §3.1–§3.4 | 重新召集决策，修订 Decision Record，不进入 W2 |
| R7 | require 路径批量替换遗漏（动态拼接、字符串拼接路径） | W4、W5 | 使用 `require(prefix .. suffix)` 或变量拼接的路径未被 sed/替换脚本覆盖 | 替换前用 AST 扫描定位动态 require；替换后全量运行 behavior + contract 测试 | 回退至对应波次前的 tag |
| R8 | blame 链断裂导致历史追溯困难 | W4–W5 | 大批量文件移动与内容修改在同一 commit 合并，`git blame` 无法追溯原始作者 | 文件移动（`git mv`）与内容修改必须分 commit；W4/W5 禁止合并；配合 `.git-blame-ignore-revs` | 无法回滚；预防为主 |

### 7.2 回滚策略

每个波次完成并通过验证后，立即打 tag `governance/W{N}-done`。回滚时从最近的失败波次回退到上一个 tag，**不进行部分回滚**（即不允许只撤销波次内某几个 commit）。回滚后须重新评估触发风险的决策组合，修订 Decision Record 后方可重新进入该波次。

| 规则 | 说明 |
|------|------|
| 每波次打 tag | 格式 `governance/W{N}-done`，在 CI 验证通过后由执行人手动推送 |
| W4 与 W5 独立 commit | `state/` 文件迁移（W4）与目录改名（W5）禁止合并为同一 commit，便于独立回滚 |
| 不进行部分回滚 | 以 tag 为粒度整体回退，避免中间状态导致 arch 工具误报 |
| 回滚后重评决策 | 特别关注触发了 R6 的决策组合（§3.1–§3.4），修订 Decision Record 后重新进入波次 |
| 文件移动与修改分 commit | 防止 R8 blame 链断裂；`git mv` 单独 commit，内容修改另起 commit |
| 回滚验证 | 回退后须重跑 `lua tools/quality/arch.lua check` + `busted --run contract`，确认回到已知良态 |

---

## Chapter 8 — 未决问题与跟进项（Open Questions & Follow-ups）

### 8.1 已识别的未决问题

- **OQ-1**：`tools/quality/arch/config.json` 是否支持 `//` 行注释？
  - 影响：Chapter 5 §5.2 exception 注释格式约定；若不支持，需改用 `_governance` 字段方案
  - 解决方式：由工具链负责人在 W1 启动前确认，结论写入 Decision Record

- **OQ-2**：`src/host/global_aliases` 当前消费方清单是否完整？
  - 影响：W1 决策（D1 vs D2 改名范围）与 W6 exception #1 处置；消费方不明则无法安全改名
  - 解决方式：由 W1 执行人在改名前用 `grep -rn 'global_aliases'` 全量扫描并记录，结果附于 Decision Record

- **OQ-3**：`player.choices.*` 是否仍存在跨层引用（非 exception 登记范围内）？
  - 影响：exception #4 处置（Chapter 5）；若存在未登记引用，W6 注释补写范围需扩大
  - 解决方式：由 W3 执行人在 component 拆分前用 arch 工具全量扫描，结果更新至 Chapter 5 表格

- **OQ-4**：Eggy 宿主对接文档（`docs/eggy/api/00_index.md` 及相关文件）是否直接引用 `src/host/` 路径？
  - 影响：R1 风险评估；若有硬编码路径引用，D1 改名需同步更新宿主文档
  - 解决方式：由 W1 执行人在改名前检索 `docs/eggy/` 目录，结论写入 Decision Record

- **OQ-5**：本路线图的决策记录是否需要独立 ADR 序列号（如 `ADR-001`）？
  - 影响：W1 决策记录格式（附录 B 模板）；若需要，须在 `docs/architecture/` 下建立 ADR 目录
  - 解决方式：由架构负责人在 W1 前裁决，结论影响附录 B 模板的实际使用格式

- **OQ-6**：`src/state/` 11 个文件中，是否存在被 `tests/` 或 `tools/` 直接 `require` 的情况？
  - 影响：W4 迁移矩阵（Chapter 4）；测试侧路径需同步更新，否则 behavior 测试在迁移后失效
  - 解决方式：由 W4 执行人在迁移前扫描 `tests/` 与 `tools/` 的 require 引用，结果附于 W4 commit message

### 8.2 跟进项（Follow-ups Beyond This Roadmap）

本路线图执行完毕后，以下事项超出当前范围，需后续独立推进：

- **端口/适配器内部协议梳理**：Chapter 2 已声明 out-of-scope。port 层内部接口契约、adapter 与 infrastructure 之间的协议文档，需在本路线图完成后单独立项。
- **`forbidden_dependency_rules` 规则集复审**：W6 完成后，arch 工具的禁止依赖规则集可能需要根据实际 exception 处置结果调整；该项复审留作 W7 之后的独立工作。
- **新增层（如 `board`）的依赖方向与端口设计**：§3.4 决策点仅确定 `board` 目录归属，其对外端口设计与依赖方向约束需后续补充至 `docs/architecture/boundaries.md`。
- **arch 工具链对 component 拆分后的报告格式适配**：W3 拆分 `runtime` component 后，arch 工具的 HTML 报告与 component 视图可能需要配置调整，由工具链负责人跟进。
- **架构治理常态化机制**：本路线图为一次性治理行动。常态化机制（季度复审节奏、PR 模板架构合规检查项）的建立留作独立工作；`governance_roadmap.md` 纳入 `AGENTS.md` "按任务找文档"表的动作已在 W7 中安排（见附录 C）。

---

## 附录 A — 真源行号速查

| 真源 | 文件路径 | 行号 | 内容摘要 |
|------|----------|------|----------|
| 架构文档 | `docs/architecture/layer-model.md` | 7–23 | 10 层架构声明（层名、职责、物理目录） |
| arch config | `tools/quality/arch/config.json` | 18–22 | `host_bridge_exception`：放行 host 层对 global_aliases 的跨层引用 |
| arch config | `tools/quality/arch/config.json` | 24–31 | `infrastructure_runtime_bridges`：放行 infrastructure 层对 runtime 的引用与 rules.vehicle |
| arch config | `tools/quality/arch/config.json` | 33–39 | `runtime_state_bridges`：放行 player.actions.state_ops 与 rules.endgame.game_victory 对 state 层的引用 |
| arch config | `tools/quality/arch/config.json` | 41–46 | `systems_choice_bridges`：放行 player.choices.* 跨层引用 |
| arch config | `tools/quality/arch/config.json` | 48–58 | `state_access`：将 state 下 6 个模块归类到 core component |
| arch config | `tools/quality/arch/config.json` | 60–65 | `player_state_bridge`：将 state.player_state 归类到 runtime component |
| arch config | `tools/quality/arch/config.json` | 102–109 | `runtime` component 合并定义（player + state） |
| 源码 | `src/state/*.lua` | — | 11 个待迁移/原地保留文件（详见 Chapter 4 矩阵） |

---

## 附录 B — 决策记录模板（Decision Record Template）

```markdown
## Decision Record — YYYY-MM-DD

**决策点**：3.1 / 3.2.1 / 3.2.2 / 3.2.3 / 3.3 / 3.4
**选项**：A / B / C / 混合
**决策人**：
**决策依据**：
**已识别的耦合影响**：
**预期完成波次**：W{N}
```

---

## 附录 C — 反向链接锚点清单

W7 必须在以下文件中插入或更新反向链接，指向 `docs/architecture/governance_roadmap.md`：

| 文件 | 插入位置 | 锚点格式 | 验证方式 |
|------|----------|----------|----------|
| `docs/architecture/layer-model.md` | 文件顶部"See also"节或末尾"参见"节 | `> **See also**: 治理路线图 → [governance_roadmap.md](governance_roadmap.md)` | `grep -n 'governance_roadmap' docs/architecture/layer-model.md` |
| `docs/architecture/boundaries.md` | 文件顶部"See also"节或末尾"相关文档"节 | `> **See also**: 治理路线图 → [governance_roadmap.md](governance_roadmap.md)` | `grep -n 'governance_roadmap' docs/architecture/boundaries.md` |
| `docs/architecture/health_signals.md` | "参考"或"相关"节 | `> **See also**: 治理路线图 → [governance_roadmap.md](governance_roadmap.md)` | `grep -n 'governance_roadmap' docs/architecture/health_signals.md` |
| `AGENTS.md` | "按任务找文档"表末行 | 追加一行：`\| 架构治理路线图 \| docs/architecture/governance_roadmap.md \|` | `grep -n 'governance_roadmap' AGENTS.md` |

> **AGENTS.md 说明**：在"按任务找文档"表中追加 `| 架构治理路线图 | docs/architecture/governance_roadmap.md |` 一行，使后续 agent 可通过任务类型直接定位本文档，无需全局搜索。
