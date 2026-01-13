# 代码库层级结构审查与迁移计划（src/）

日期：2026-01-12

> 目标：审查当前代码库的层级结构，指出不合理点，并给出一个可分阶段落地、低风险的迁移计划。
> 范围：src/、main.lua、scripts/deps_check.lua、scripts/regression.lua。
> 约束：优先以结构与可维护性为目标，不改玩法与交互语义，关注代码行数，尽最大可能降低代码量。

---

## 0. 结论摘要（TL;DR）

- **顶层分层方向是对的**：`src/gameplay` / `src/adapters` / `src/config` / `src/util` 已经基本符合“内核不依赖外设”的分层。
- **主要结构问题集中在“边界不够显式 + 命名与职责不够聚合”**：domain/app/adapter 的方向有 `deps_check` 护栏，但在“用例入口、服务边界、状态写入入口、目录命名一致性”上仍有改造空间。
- **迁移优先级**：先做“可验证、低风险”的结构收敛（P0），再做依赖显式化（P1），最后才做更深的 SOLID 拆分与删代码（P2）。

本审查输出的是“结构层级/职责边界/迁移路线”，不讨论具体玩法数值与 UI 视觉。

## 1. 代码库结构现状（以当前仓库为准）

### 1.1 入口与装配

- 入口：`main.lua`
	- 设置 `package.path`
	- 创建 `App`（`src/app.lua`）
	- 启动 `LoveLayer`（`src/adapters/love2d/love_layer.lua`）挂接 LÖVE 生命周期

### 1.2 `src/` 顶层目录（责任划分）

- `src/app.lua`
	- 负责 **组装**（board/players/store/rng/services/usecases）与部分 **状态同步写入**（`set_tile_owner`/`set_tile_level` 等）。
	- `REQUIRED_SERVICES` + `validate_services`：提供了启动期的必备服务校验（这是结构层面的加分项）。
- `src/gameplay/`
	- `app/`：流程编排、回合状态机、解析器、服务、用例（turn/flow/resolver/services/usecases）。
	- `domain/`：领域规则与效果系统（effect/landing/land/item/chance/...）。
	- `infra/`：基础设施（`rng.lua`、`store.lua`）。
	- `ports/`：端口抽象（目前重点是 `ui_port.lua`）。
- `src/adapters/`
	- `love2d/`：渲染、输入与 UI 状态（presenter/renderers/modals/panels）。
	- `eggy/`：平台适配（若未来迁移到 Eggy 环境）。
- `src/config/`
	- 纯配置/表驱动（map/tiles/items/roles/constants/chance_cards）。
- `src/util/`
	- 通用工具（logger/tables/error_handling/random/services/game_state）。

### 1.3 依赖护栏（`scripts/deps_check.lua`）

当前依赖方向通过脚本做了三条硬规则：

1) `src/gameplay/**` 不得 `require("src.adapters.*")`（禁止 gameplay 依赖 UI/适配层）

2) `src/gameplay/domain/**` 不得 `require("src.gameplay.app.*")`（禁止 domain 依赖 app）

3) `src/gameplay/app/services/**` 不得互相 `require("src.gameplay.app.services.*")`（禁止 service 之间硬引用，鼓励走 `game.services` 注入）

这三条规则对“结构正确性”非常关键，建议长期保留，并将迁移计划中的改动全部以“deps_check + regression 可通过”为验收门槛。

## 2. 结构审查：优势与问题

### 2.1 优势（值得保持）

- **分层清晰**：`gameplay` 与 `adapters` 的依赖方向明确，并且有脚本强制。
- **流程编排聚合在 app 层**：`TurnManager` / `Flow` / `LandingResolver` 形成了稳定的“上层驱动”。
- **配置表集中**：`src/config/*` 收敛了常量与表数据，有利于表驱动演进。
- **回归脚本可跑**：`scripts/regression.lua` 提供了最低成本的“结构迁移护栏”。

### 2.2 问题（结构层级维度）

#### 问题 A：顶层结构与检查脚本存在“历史残留”信号

- `scripts/deps_check.lua` 会扫描 `src/core/`，但当前 `src/` 顶层并没有 `core/` 目录（规则与实际结构不一致）。
- 影响：新同学会困惑“core 在哪”；后续迁移也容易误判。
- 建议：在结构 review 的迁移阶段里要么补齐目标目录并迁移进去，要么更新脚本扫描范围，确保一致。

#### 问题 B：`App` 仍是“结构上帝对象”（装配 + 运行态写入）

- `src/app.lua` 同时承担：组装、store 同步、玩家位置更新、胜负判定、turn/usecase 挂载。
- 结构后果：
	- 任何想替换 Store/RNG/服务装配方式的人都必须改 `App`。
	- 很难形成“稳定的用例入口”，adapter 可能倾向于直接调用 `game` 上的方法/字段。

#### 问题 C：状态写入入口分散，存在“直接引用 store 内表”的泄露

- 例：`overlays_ref = store:get({"board","overlays"})` 并直接挂到 `game.overlays`。
- 结构后果：
	- 一部分写入绕开 `store:set` 的快照/拷贝规则，未来如果 store 需要加审计/事件/回放，会变得困难。
	- adapter 或 domain 更容易“顺手改表”，削弱边界。

#### 问题 D：`domain` 下的 item 子系统文件众多，但边界仍模糊

- `src/gameplay/domain/item*.lua` 数量较多（inventory/strategy/executor/target_effects/post_effects/...）。
- 结构后果：
	- 扩展一个道具时，经常需要跨多个文件同步改动，心智负担大。
	- “纯领域规则”与“依赖 game/services 的执行”容易混在一起（尽管 deps_check 禁止 require app，但通过 `ctx.game/services` 仍可产生执行耦合）。

#### 问题 E：服务定位器（`src/util/services.lua`）让依赖边界不够显式

- 目前 `Services.get(game,key)` 很轻，但它会鼓励在任意地方“随取随用”。
- 结构后果：
	- 依赖不透明，读代码看不出模块需要哪些能力。
	- 注入替换（stub/mock）虽然能做，但需要在运行时才发现缺失。

## 3. 目标结构（迁移后的稳定形态）

原则：不引入额外概念，只把“谁负责什么”在目录与入口上讲清楚。

- `src/gameplay/domain/`：只保留**纯规则与纯数据结构**（effect 定义、计算、条件判断、规则组合）。
- `src/gameplay/app/`：只保留**用例编排与副作用调度**（服务调用、store 写入、intent/choice 生成与分发）。
- `src/gameplay/ports/`：对 adapter 的最小接口（UI 端口、未来可扩展到音效/埋点）。
- `src/gameplay/infra/`：store/rng 等“可替换实现”。
- `src/adapters/*`：渲染与输入，不直接写 store 内部结构，只走用例/端口。

## 4. 分阶段迁移计划（低风险，可验证）

验收基线（每一步都要满足）：

- `lua scripts/deps_check.lua` 通过
- `lua scripts/regression.lua` 通过

### P0：结构一致性与边界收敛（不改玩法语义）

目标：让“目录/脚本/边界”一致，减少结构困惑。

1) **对齐 deps_check 的扫描范围与真实结构**
	 - 选择其一：
		 - A. 删除脚本中对 `src/core/` 的扫描（如果该目录不再计划出现）
		 - B. 引入/恢复 `src/core/` 作为稳定的“核心域模型目录”，并把 `src/gameplay/domain/core/*` 中的核心对象迁移/别名过去
	 - 推荐：先做 A（最小变更），后续在 P2 再决定是否需要 core 目录。

2) **收敛 overlays 写入口（禁止外部拿内部引用）**
	 - 将 `game.overlays` 从“直接引用 store 内表”改为：
		 - 只读快照（presenter 读 store），写入统一走 `OverlayService` 或 `game.services.overlay`。
	 - 目标是结构上阻断“随手改 store 内表”。

3) **明确 adapter 的调用入口**
	 - adapter 只调用 `game.turn_usecase` / `game.action_usecase`（或未来的统一 usecase 门面），不直接调 `store:set`。
	 - 现状已经有 `TurnUsecase` / `ActionUsecase`，这是天然的结构收敛点。

### P1：依赖显式化（让边界“看得见”）

目标：减少服务定位器/隐式依赖，让 domain 的需求在签名中出现。

1) **减少 `src/util/services.lua` 的扩散**
	 - 新代码禁止引入服务定位器。
	 - 旧代码逐步改为从 `ctx.services` / 显式参数传入所需能力（最小接口）。

2) **统一“intent/choice/UI”触发路径**
	 - domain 只返回 intent 数据，不直接触发 UI 行为。
	 - app（例如 `LandingResolver` + `IntentDispatcher`）成为唯一的 intent 分发点。

### P2：目录聚合与删代码（结构清晰 + 行数下降）

目标：把“多文件同一职责”的碎片化合并，减少认知负担并降低代码量。

1) **Item 子系统按职责聚合**
	 - 方向示例：
		 - `item_catalog`（道具定义与数据）
		 - `item_rules`（命中规则/可用条件/目标选择规则）
		 - `item_execute`（把规则转成对 services/store 的副作用）
	 - 保留表驱动优先，尽可能减少“每个道具一个文件”的散落。

2) **统一 core 命名与放置位置**
	 - 只保留一个“核心对象目录”（要么是 `src/gameplay/domain/core`，要么是 `src/core`）。
	 - 把 board/player/inventory 等核心对象集中，减少“同名概念分散在多层”的情况。

3) **可删代码清单（以 deps_check + regression 为准）**
	 - 以 `scripts/debloat_report.lua` 的结果为辅助，但最终以运行路径与回归为准。
	 - 每次删文件前后都跑验收基线。

## 5. 验收清单（结构层级）

- 依赖方向：保持 `deps_check` 的 3 条硬规则不被破坏。
- 入口一致：读 `main.lua` 能在 30 秒内理解“从入口到回合推进”的调用链。
- 写入收敛：store 的写入点集中在 app/services/usecase（adapter 不直写、domain 不偷写）。
- 目录可解释：每个顶层目录都有清晰职责，不出现“脚本认为存在但仓库没有”的目录。

